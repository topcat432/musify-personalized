package com.gokadzev.musify;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.AssetFileDescriptor;
import android.database.Cursor;
import android.net.Uri;
import android.os.CancellationSignal;
import android.os.Handler;
import android.os.Looper;
import android.os.Process;
import android.provider.OpenableColumns;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import com.kasem.receive_sharing_intent.ImportFileIntentPolicy;
import java.io.InputStream;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

/** One engine-owned catalog and reader. No URI-to-path conversion or cache copy. */
public final class IncomingFileChannel {
  private final Context context;
  private final MethodChannel channel;
  private final Handler main = new Handler(Looper.getMainLooper());
  private final ExecutorService worker = Executors.newSingleThreadExecutor();
  // No queued cancellation tasks or new workers if a provider close/cancel stalls.
  private final ExecutorService canceller = new ThreadPoolExecutor(1, 1, 0L,
      TimeUnit.MILLISECONDS, new SynchronousQueue<Runnable>(), new ThreadPoolExecutor.DiscardPolicy());
  private final LinkedHashMap<String, Entry> pending = new LinkedHashMap<>();
  private final String generation = UUID.randomUUID().toString();
  private int sequence;
  private volatile boolean closed;
  private Entry active;
  private Job busy;
  private String notice;
  private static final class Entry {
    final String id;
    final Uri uri;
    String name;
    Long size;
    Entry(String id, Uri uri) { this.id = id; this.uri = uri; }
  }
  private static final class Job {
    final Entry entry;
    final String request;
    final MethodChannel.Result reply;
    final CancellationSignal signal = new CancellationSignal();
    final AtomicBoolean cancelled = new AtomicBoolean();
    final AtomicBoolean cancelSent = new AtomicBoolean();
    final AtomicBoolean replied = new AtomicBoolean();
    final long started = System.nanoTime();
    volatile InputStream stream;
    Runnable deadline;
    Job(Entry entry, String request, MethodChannel.Result reply) {
      this.entry = entry; this.request = request; this.reply = reply;
    }
  }
  public IncomingFileChannel(Context context, BinaryMessenger messenger) {
    this.context = context;
    channel = new MethodChannel(messenger, "com.topcat432.musifypersonalized/incoming_files");
    channel.setMethodCallHandler((call, reply) -> {
      if (closed) { reply.error("INCOMING_CLOSED", "File intake is unavailable.", null); return; }
      Object rawId = call.argument("id");
      String id = rawId instanceof String ? (String) rawId : null;
      switch (call.method) {
        case "list": {
          List<Map<String, Object>> files = new ArrayList<>();
          for (Entry e : pending.values()) if (e.name != null) {
            Map<String, Object> file = new HashMap<>();
            file.put("id", e.id); file.put("uri", e.uri.toString());
            file.put("name", e.name); file.put("size", e.size); file.put("readGrantVerified", true);
            files.add(file);
          }
          Map<String, Object> result = new HashMap<>();
          result.put("files", files); result.put("notice", notice); reply.success(result); break;
        }
        case "ackNotice": { notice = null; reply.success(null); changed(); break; }
        case "dismiss": {
          Entry removed = pending.remove(id);
          if (busy != null && busy.entry == removed) cancel(busy);
          reply.success(null); changed(); pump(); break;
        }
        case "finish": {
          Entry released = pending.remove(id);
          if (active != null && active.id.equals(id)) {
            released = active;
            active = null;
          }
          // begin is Dart-owned; a BUSY read can leave its descriptor pending.
          // Release only that exact ID, preserving another inspection/read owner.
          if (released != null && busy != null && busy.entry == released) cancel(busy);
          reply.success(null); changed(); pump(); break;
        }
        case "cancel": {
          Object rawRequest = call.argument("request");
          String request = rawRequest instanceof String ? (String) rawRequest : null;
          if (busy != null && busy.request != null && busy.request.equals(request)) cancel(busy);
          reply.success(null); break;
        }
        case "read": {
          Object rawRequest = call.argument("request");
          String request = rawRequest instanceof String ? (String) rawRequest : null;
          Entry e = active != null && active.id.equals(id) ? active : pending.get(id);
          if (busy != null || (active != null && active != e)) {
            reply.error("INCOMING_BUSY", "Another file operation is still stopping. Try again.", null); break;
          }
          if (e == null || e.name == null || request == null || request.isEmpty() || request.length() > 128) {
            reply.error("INCOMING_INVALID", "Choose a pending file again.", null); break;
          }
          pending.remove(e.id); active = e;
          Job job = new Job(e, request, reply); busy = job;
          deadline(job);
          worker.execute(() -> read(job)); changed(); break;
        }
        default: reply.notImplemented();
      }
    });
  }
  /** Called after super.onCreate and for each warm onNewIntent. */
  public void offer(Intent intent) {
    if (closed || intent == null) return;
    String action = intent.getAction();
    if (!Intent.ACTION_SEND.equals(action) && !Intent.ACTION_VIEW.equals(action)
        && !Intent.ACTION_SEND_MULTIPLE.equals(action)) return;
    if (Intent.ACTION_VIEW.equals(action) && (intent.getData() == null
        || !"content".equals(intent.getData().getScheme()))) return;
    String mime = intent.getType();
    if (!ImportFileIntentPolicy.excludeFromLegacyCopy(Intent.ACTION_SEND, mime, true)) return;
    try {
      if (Intent.ACTION_SEND_MULTIPLE.equals(action)) { reject("Send one song-list file at a time."); return; }
      Uri uri = Intent.ACTION_VIEW.equals(action) ? intent.getData()
          : intent.getParcelableExtra(Intent.EXTRA_STREAM);
      if (intent.getClipData() != null && intent.getClipData().getItemCount() > 0) {
        if (intent.getClipData().getItemCount() != 1) { reject("Send one song-list file at a time."); return; }
        Uri clip = intent.getClipData().getItemAt(0).getUri();
        if (uri != null && clip != null && !uri.equals(clip)) { reject("The file request is ambiguous."); return; }
        if (uri == null) uri = clip;
      }
      // Text-only SEND is left to the existing text-sharing implementation.
      if (uri == null) return;
      if (!"content".equals(uri.getScheme()) || uri.getAuthority() == null
          || uri.getAuthority().isEmpty() || uri.getAuthority().contains("@")
          || uri.getFragment() != null || uri.toString().length() > 8192 || !granted(uri)) {
        reject("Choose a supported local song list with a read grant."); return;
      }
      if (active != null && active.uri.equals(uri)) return;
      for (Entry e : pending.values()) if (e.uri.equals(uri)) return;
      if (pending.size() >= 4) { reject("The incoming-file inbox is full. Review or dismiss a pending file."); return; }
      Entry e = new Entry(generation + "-" + (++sequence), uri);
      pending.put(e.id, e); notice = null; pump();
    } catch (RuntimeException ignored) { reject("The incoming file could not be verified."); }
  }
  private boolean granted(Uri uri) {
    return context.checkUriPermission(uri, Process.myPid(), Process.myUid(),
        Intent.FLAG_GRANT_READ_URI_PERMISSION) == PackageManager.PERMISSION_GRANTED;
  }
  private void pump() {
    if (closed || busy != null) return;
    for (Entry e : pending.values()) if (e.name == null) {
      Job job = new Job(e, null, null); busy = job; deadline(job);
      worker.execute(() -> inspect(job)); return;
    }
  }
  private void deadline(Job job) {
    job.deadline = () -> {
      if (busy == job) { cancel(job); reject("The incoming file operation timed out. Try a local file again."); }
    };
    main.postDelayed(job.deadline, 20000);
  }
  private void inspect(Job job) {
    String name = null; Long size = null;
    try {
      if (!granted(job.entry.uri)) throw new SecurityException();
      try (Cursor c = context.getContentResolver().query(job.entry.uri,
          new String[] {OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE}, null, null, null, job.signal)) {
        if (c == null || !c.moveToFirst()) throw new IllegalArgumentException();
        int n = c.getColumnIndex(OpenableColumns.DISPLAY_NAME), s = c.getColumnIndex(OpenableColumns.SIZE);
        if (n < 0 || c.isNull(n) || c.getType(n) != Cursor.FIELD_TYPE_STRING) throw new IllegalArgumentException();
        name = c.getString(n);
        if (s >= 0 && !c.isNull(s)) {
          if (c.getType(s) != Cursor.FIELD_TYPE_INTEGER) throw new IllegalArgumentException();
          size = c.getLong(s);
        }
        if (!IncomingFileReader.validName(name) || (size != null && (size < 0 || size > IncomingFileReader.MAX_BYTES)))
          throw new IllegalArgumentException();
      }
    } catch (Exception ignored) { name = null; }
    if (closed || job.cancelled.get() || System.nanoTime() - job.started >= IncomingFileReader.DEADLINE_NANOS) name = null;
    final String resultName = name; final Long resultSize = size;
    main.post(() -> {
      main.removeCallbacks(job.deadline);
      if (busy == job) busy = null;
      if (pending.get(job.entry.id) == job.entry) {
        if (closed || job.cancelled.get() || resultName == null) {
          pending.remove(job.entry.id);
          if (!closed) notice = "The incoming file is unsupported or its read grant is unavailable.";
        } else { job.entry.name = resultName; job.entry.size = resultSize; }
      }
      changed(); pump();
    });
  }
  private void read(Job job) {
    byte[] bytes = null;
    try {
      if (!granted(job.entry.uri) || job.cancelled.get()) throw new SecurityException();
      try (AssetFileDescriptor descriptor = context.getContentResolver().openAssetFileDescriptor(job.entry.uri, "r", job.signal)) {
        if (descriptor == null) throw new IllegalArgumentException();
        try (InputStream input = descriptor.createInputStream()) {
          job.stream = input;
          bytes = IncomingFileReader.read(input, () -> closed || job.cancelled.get(), System::nanoTime, job.started);
          if (job.entry.size != null && job.entry.size != bytes.length) throw new IllegalArgumentException();
        } finally { job.stream = null; }
      }
    } catch (Exception ignored) { bytes = null; }
    final byte[] result = bytes;
    main.post(() -> {
      main.removeCallbacks(job.deadline);
      if (busy == job) busy = null;
      if (job.replied.compareAndSet(false, true)) {
        if (closed || job.cancelled.get() || active != job.entry || result == null)
          job.reply.error("INCOMING_REJECTED", "The file read was cancelled, changed or exceeded its limits.", null);
        else job.reply.success(result);
      }
      pump();
    });
  }
  private void cancel(Job job) {
    job.cancelled.set(true);
    main.removeCallbacks(job.deadline);
    if (!job.cancelSent.compareAndSet(false, true)) return;
    canceller.execute(() -> {
      try { if (job.stream != null) job.stream.close(); } catch (Exception ignored) {}
      try { job.signal.cancel(); } catch (Exception ignored) {}
    });
  }
  private void reject(String value) { notice = value; changed(); }
  private void changed() { if (!closed) channel.invokeMethod("changed", null); }
  public void close() {
    closed = true; channel.setMethodCallHandler(null);
    if (busy != null) {
      cancel(busy);
      if (busy.reply != null && busy.replied.compareAndSet(false, true))
        busy.reply.error("INCOMING_CLOSED", "File intake was closed.", null);
    }
    pending.clear(); active = null; worker.shutdownNow(); canceller.shutdown();
  }
}
