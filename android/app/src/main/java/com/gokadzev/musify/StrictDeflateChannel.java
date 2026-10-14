package com.gokadzev.musify;

import android.os.Handler;
import android.os.Looper;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/** One engine-owned worker; cancellation is delivered on the UI channel. */
public final class StrictDeflateChannel {
  private final MethodChannel channel;
  private final Handler main = new Handler(Looper.getMainLooper());
  private final ExecutorService worker = Executors.newSingleThreadExecutor();
  private volatile boolean closed;
  private Job active;

  private static final class Job {
    final String id;
    final MethodChannel.Result reply;
    final AtomicBoolean cancelled = new AtomicBoolean();
    final AtomicBoolean replied = new AtomicBoolean();
    Job(String id, MethodChannel.Result reply) { this.id = id; this.reply = reply; }
  }

  public StrictDeflateChannel(BinaryMessenger messenger) {
    channel = new MethodChannel(messenger, "com.topcat432.musifypersonalized/strict_deflate");
    channel.setMethodCallHandler((call, reply) -> {
      if (closed) { reply.error("ZIP_CLOSED", "ZIP decoder is unavailable.", null); return; }
      if (call.method.equals("cancel")) {
        String id = call.argument("id");
        if (active != null && active.id.equals(id)) active.cancelled.set(true);
        reply.success(null); return;
      }
      if (!call.method.equals("inflate")) { reply.notImplemented(); return; }
      if (active != null) { reply.error("ZIP_BUSY", "Another ZIP is still being decoded.", null); return; }
      String id = call.argument("id");
      byte[] bytes = call.argument("bytes");
      Number size = call.argument("size");
      if (id == null || id.isEmpty() || id.length() > 64 || bytes == null
          || bytes.length > StrictDeflate.MAX_BYTES || size == null
          || !(size instanceof Integer || size instanceof Long)
          || size.longValue() < 0 || size.longValue() > StrictDeflate.MAX_BYTES) {
        reply.error("ZIP_ARGUMENT", "ZIP request is invalid or too large.", null); return;
      }
      Job job = new Job(id, reply); active = job;
      worker.execute(() -> {
        byte[] value = null;
        try { value = StrictDeflate.decode(bytes, size.intValue(), () -> closed || job.cancelled.get()); }
        catch (Exception ignored) { /* No payload, paths or content enter errors/logs. */ }
        finally {
          final byte[] decoded = value;
          main.post(() -> finish(job, decoded, bytes.length));
        }
      });
    });
  }

  private void finish(Job job, byte[] decoded, int consumed) {
    if (!job.replied.compareAndSet(false, true)) return;
    if (active == job) active = null;
    if (closed || job.cancelled.get() || decoded == null) {
      job.reply.error("ZIP_REJECTED", "ZIP decoding was cancelled or could not be verified within its limits.", null);
    } else {
      Map<String, Object> proof = new HashMap<>();
      proof.put("bytes", decoded); proof.put("finished", true); proof.put("consumedBytes", consumed);
      job.reply.success(proof);
    }
  }

  public void close() {
    closed = true; channel.setMethodCallHandler(null);
    if (active != null) { active.cancelled.set(true); finish(active, null, 0); }
    worker.shutdownNow(); // Only this channel's owned worker; helper ends its inflater in finally.
  }
}
