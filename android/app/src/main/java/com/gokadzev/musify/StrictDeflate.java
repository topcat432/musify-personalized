package com.gokadzev.musify;

import java.io.ByteArrayOutputStream;
import java.util.Arrays;
import java.util.function.BooleanSupplier;
import java.util.function.LongSupplier;
import java.util.zip.DataFormatException;
import java.util.zip.Inflater;

/** Bounded adapter around the platform codec, not a DEFLATE implementation. */
public final class StrictDeflate {
  public static final int MAX_BYTES = 8 * 1024 * 1024;
  private static final long DEADLINE_NANOS = 20_000_000_000L;
  private StrictDeflate() {}

  public static byte[] decode(byte[] input, int expectedSize, BooleanSupplier cancelled)
      throws DataFormatException {
    return decode(input, expectedSize, cancelled, System::nanoTime);
  }

  static byte[] decode(byte[] input, int expectedSize, BooleanSupplier cancelled, LongSupplier clock)
      throws DataFormatException {
    if (input == null || input.length > MAX_BYTES || expectedSize < 0 || expectedSize > MAX_BYTES) {
      throw new IllegalArgumentException("ZIP size limit exceeded.");
    }
    long start = clock.getAsLong();
    // nowrap's documented dummy byte is not part of the ZIP payload. Exact
    // consumed/remaining checks below prevent it repairing a truncated stream.
    byte[] framed = Arrays.copyOf(input, input.length + 1);
    ByteArrayOutputStream output = new ByteArrayOutputStream(Math.min(expectedSize, 65536));
    byte[] chunk = new byte[16384];
    Inflater inflater = new Inflater(true);
    int fed = 0;
    try {
      while (!inflater.finished()) {
        checkCancelled(cancelled, start, clock);
        if (inflater.needsInput() && fed < framed.length) {
          int length = Math.min(16384, framed.length - fed);
          inflater.setInput(framed, fed, length);
          fed += length;
        }
        int n = inflater.inflate(chunk, 0, Math.min(chunk.length, expectedSize - output.size() + 1));
        if (n > expectedSize - output.size()) {
          throw new DataFormatException("ZIP decoded size limit exceeded.");
        }
        if (n > 0) output.write(chunk, 0, n);
        else if (!inflater.finished()) {
          if (inflater.needsDictionary()) throw new DataFormatException("ZIP dictionary is unsupported.");
          if (inflater.needsInput()) {
            if (fed < framed.length) continue;
            throw new DataFormatException("ZIP compressed stream is incomplete.");
          }
          throw new DataFormatException("ZIP compressed stream made no progress.");
        }
      }
      checkCancelled(cancelled, start, clock);
      if (inflater.getBytesRead() != input.length || inflater.getRemaining() + framed.length - fed != 1
          || output.size() != expectedSize) {
        throw new DataFormatException("ZIP compressed stream length does not match.");
      }
      return output.toByteArray();
    } finally {
      inflater.end();
    }
  }

  private static void checkCancelled(BooleanSupplier cancelled, long start, LongSupplier clock) {
    if (cancelled.getAsBoolean() || Thread.currentThread().isInterrupted()) {
      throw new IllegalStateException("File selection was cancelled.");
    }
    if (clock.getAsLong() - start >= DEADLINE_NANOS) {
      throw new IllegalStateException("ZIP decoding timed out.");
    }
  }
}
