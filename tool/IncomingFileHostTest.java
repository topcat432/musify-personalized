package com.gokadzev.musify;
import com.kasem.receive_sharing_intent.ImportFileIntentPolicy;
import java.io.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

public final class IncomingFileHostTest {
  private static int checks;
  private static void check(boolean value) { checks++; if (!value) throw new AssertionError("Incoming-file check failed " + checks); }
  private static void rejected(InputStream input, AtomicBoolean stopped, AtomicLong clock) throws Exception {
    boolean rejected = false;
    try { IncomingFileReader.read(input, stopped::get, clock::get, 0); }
    catch (IOException expected) { rejected = true; }
    check(rejected);
  }
  public static void main(String[] ignored) throws Exception {
    String send = "android.intent.action.SEND";
    for (String mime : new String[] {"text/csv", "text/tab-separated-values", "text/plain", "application/json", "application/zip", "application/x-zip-compressed", "application/octet-stream"}) {
      check(ImportFileIntentPolicy.excludeFromLegacyCopy(send, mime, true));
      check(!ImportFileIntentPolicy.excludeFromLegacyCopy(send, mime, false));
      check(ImportFileIntentPolicy.excludeFromLegacyCopy("android.intent.action.SEND_MULTIPLE", mime, true));
    }
    for (String mime : new String[] {"image/png", "image/jpeg", "video/mp4", "audio/ogg", "application/pdf", null})
      check(!ImportFileIntentPolicy.excludeFromLegacyCopy(send, mime, true));
    check(!ImportFileIntentPolicy.excludeFromLegacyCopy("android.intent.action.VIEW", "application/json", true));
    for (String name : new String[] {"list.csv", "List.TSV", "Playlist.json", "archive.ZIP", "?.json"}) check(IncomingFileReader.validName(name));
    for (String name : new String[] {null, "", "../list.csv", "a\\list.csv", "line\n.csv", "list.csv\u0000", "list.apk"}) check(!IncomingFileReader.validName(name));
    StringBuilder longName = new StringBuilder(); for (int i = 0; i < 256; i++) longName.append('x');
    check(!IncomingFileReader.validName(longName + ".csv"));
    AtomicBoolean stopped = new AtomicBoolean(); AtomicLong clock = new AtomicLong();
    check(IncomingFileReader.read(new ByteArrayInputStream(new byte[] {1,2,3}), stopped::get, clock::get, 0).length == 3);
    check(IncomingFileReader.read(new ByteArrayInputStream(new byte[IncomingFileReader.MAX_BYTES]), stopped::get, clock::get, 0).length == IncomingFileReader.MAX_BYTES);
    rejected(new ByteArrayInputStream(new byte[IncomingFileReader.MAX_BYTES + 1]), stopped, clock);
    stopped.set(true); rejected(new ByteArrayInputStream(new byte[] {1}), stopped, clock); stopped.set(false);
    clock.set(IncomingFileReader.DEADLINE_NANOS); rejected(new ByteArrayInputStream(new byte[] {1}), stopped, clock); clock.set(0);
    rejected(new InputStream() {
      public int read() { return 0; }
      public int read(byte[] b, int off, int len) { clock.set(IncomingFileReader.DEADLINE_NANOS); return 1; }
    }, stopped, clock); clock.set(0);
    rejected(new InputStream() {
      public int read() { return 0; }
      public int read(byte[] b, int off, int len) { return len + 1; }
    }, stopped, clock);
    rejected(new InputStream() { public int read() throws IOException { throw new IOException("Synthetic provider failure"); } }, stopped, clock);
    System.out.println("Incoming-file policy/reader: " + checks + " checks passed.");
  }
}
