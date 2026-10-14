package com.gokadzev.musify;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.IOException;
import java.util.function.BooleanSupplier;
import java.util.function.LongSupplier;

/** Actual stream cap/deadline helper; descriptor lifecycle belongs to the bridge. */
public final class IncomingFileReader {
  public static final int MAX_BYTES = 8 * 1024 * 1024;
  public static final long DEADLINE_NANOS = 20_000_000_000L;
  private IncomingFileReader() {}
  public static boolean validName(String name) {
    if (name == null || name.isEmpty() || name.length() > 255) return false;
    for (int i = 0; i < name.length(); i++) {
      char c = name.charAt(i);
      if (c < 32 || c == 127 || c == '/' || c == '\\') return false;
    }
    return name.toLowerCase(java.util.Locale.ROOT).matches(".*\\.(csv|tsv|json|zip)$");
  }
  public static byte[] read(InputStream input, BooleanSupplier stopped,
      LongSupplier clock, long started) throws IOException {
    ByteArrayOutputStream bytes = new ByteArrayOutputStream();
    byte[] buffer = new byte[16 * 1024];
    while (true) {
      check(stopped, clock, started);
      int requested = Math.min(buffer.length, MAX_BYTES - bytes.size() + 1);
      int count = input.read(buffer, 0, requested);
      check(stopped, clock, started);
      if (count == -1) return bytes.toByteArray();
      if (count < 0 || count > requested || bytes.size() + count > MAX_BYTES)
        throw new IOException("Incoming file rejected.");
      if (count != 0) bytes.write(buffer, 0, count);
    }
  }
  private static void check(BooleanSupplier stopped, LongSupplier clock, long started) throws IOException {
    if (stopped.getAsBoolean() || Thread.currentThread().isInterrupted()
        || clock.getAsLong() - started >= DEADLINE_NANOS)
      throw new IOException("Incoming file stopped.");
  }
}
