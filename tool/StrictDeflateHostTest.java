package com.gokadzev.musify;
import java.util.Arrays;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.zip.Deflater;

public final class StrictDeflateHostTest {
  private static int checks;
  private interface Checked { void run() throws Exception; }
  private static void rejected(Checked work) throws Exception {
    try { work.run(); } catch (Exception expected) { checks++; return; }
    throw new AssertionError("Unsafe stream accepted");
  }
  private static byte[] encoded(byte[] bytes) {
    Deflater d = new Deflater(6, true); d.setInput(bytes); d.finish();
    java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
    byte[] chunk = new byte[16384];
    while (!d.finished()) { int n = d.deflate(chunk); out.write(chunk,0,n); }
    d.end(); return out.toByteArray();
  }
  public static void main(String[] args) throws Exception {
    exercise(Base64.getDecoder().decode("C8ksyUnVcSwqySwu4XLLLCou0fEvz0st4gIA"), 25, 3043107252L);
    exercise(Base64.getDecoder().decode("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"), 17313, 2624013443L);

    byte[] empty = encoded(new byte[0]);
    if (StrictDeflate.decode(empty,0,()->false).length != 0) throw new AssertionError(); checks++;
    byte[] boundary = new byte[StrictDeflate.MAX_BYTES]; Arrays.fill(boundary,(byte)'A');
    byte[] compressed = encoded(boundary);
    if (!Arrays.equals(StrictDeflate.decode(compressed,boundary.length,()->false),boundary)) throw new AssertionError(); checks++;
    rejected(()->StrictDeflate.decode(compressed,boundary.length-1,()->false));
    rejected(()->StrictDeflate.decode(compressed,boundary.length+1,()->false));
    rejected(()->StrictDeflate.decode(new byte[StrictDeflate.MAX_BYTES+1],1,()->false));
    rejected(()->StrictDeflate.decode(compressed,boundary.length,()->true));
    AtomicInteger polls = new AtomicInteger();
    rejected(()->StrictDeflate.decode(compressed,boundary.length,()->polls.incrementAndGet()>3));
    // A complete stored DEFLATE block without BFINAL is not a completed stream.
    byte[] noFinal = new byte[]{0,1,0,(byte)254,(byte)255,65};
    rejected(()->StrictDeflate.decode(noFinal,1,()->false));
    byte[] validStored = noFinal.clone(); validStored[0]=1;
    if (StrictDeflate.decode(validStored,1,()->false)[0] != 65) throw new AssertionError(); checks++;
    byte[] random = new byte[100000]; new java.util.Random(17).nextBytes(random);
    if (!Arrays.equals(StrictDeflate.decode(encoded(random),random.length,()->false),random)) throw new AssertionError(); checks++;
    // Many empty blocks force input-budget progress without output-budget progress.
    byte[] emptyBlocks = new byte[50005];
    for(int i=0;i<emptyBlocks.length;i+=5){emptyBlocks[i+3]=(byte)255;emptyBlocks[i+4]=(byte)255;}
    emptyBlocks[50000]=1;
    if (StrictDeflate.decode(emptyBlocks,0,()->false).length!=0) throw new AssertionError(); checks++;
    AtomicInteger emptyPolls=new AtomicInteger();
    rejected(()->StrictDeflate.decode(emptyBlocks,0,()->emptyPolls.incrementAndGet()>2));
    AtomicInteger expiredClock = new AtomicInteger();
    rejected(()->StrictDeflate.decode(validStored,1,()->false,()->expiredClock.getAndIncrement()==0?0:20_000_000_000L));
    AtomicInteger allowedClock = new AtomicInteger();
    if(StrictDeflate.decode(validStored,1,()->false,()->allowedClock.getAndIncrement()==0?0:19_999_999_999L)[0]!=65)throw new AssertionError();checks++;
    System.out.println("StrictDeflate host checks PASS: "+checks);
  }
  private static void exercise(byte[] compressed,int expected,long crc) throws Exception {
    byte[] decoded=StrictDeflate.decode(compressed,expected,()->false);
    java.util.zip.CRC32 checksum=new java.util.zip.CRC32();checksum.update(decoded);
    if (decoded.length != expected || checksum.getValue()!=crc) throw new AssertionError(); checks++;
    for(int length=0;length<compressed.length;length++) {
      final byte[] cut=Arrays.copyOf(compressed,length);
      rejected(()->StrictDeflate.decode(cut,expected,()->false));
    }
    byte[] extra=Arrays.copyOf(compressed,compressed.length+1);
    rejected(()->StrictDeflate.decode(extra,expected,()->false));
    byte[] concat=new byte[compressed.length*2];System.arraycopy(compressed,0,concat,0,compressed.length);System.arraycopy(compressed,0,concat,compressed.length,compressed.length);
    rejected(()->StrictDeflate.decode(concat,expected,()->false));
    rejected(()->StrictDeflate.decode(compressed,expected-1,()->false));
    rejected(()->StrictDeflate.decode(compressed,expected+1,()->false));
  }
}
