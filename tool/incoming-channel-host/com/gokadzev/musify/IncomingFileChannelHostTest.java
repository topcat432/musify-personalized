package com.gokadzev.musify;
import android.content.*;
import android.content.res.AssetFileDescriptor;
import android.database.Cursor;
import android.net.Uri;
import android.os.*;
import io.flutter.plugin.common.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.BooleanSupplier;

/** Executes the production channel, not a separate catalog implementation.
 * API doubles provide deterministic worker barriers; this is not Android grant proof. */
public final class IncomingFileChannelHostTest {
 private static int checks;
 private static void check(boolean value,String message){checks++;if(!value)throw new AssertionError(message);}
 private static void waitFor(BooleanSupplier ready) throws Exception {
  long end=System.nanoTime()+TimeUnit.SECONDS.toNanos(4);
  do {Handler.drain();if(ready.getAsBoolean())return;Thread.sleep(5);}while(System.nanoTime()<end);
  throw new AssertionError("Owned worker did not finish within four seconds");
 }
 private static final class Reply implements MethodChannel.Result {
  Object value;String error;boolean completed;int responses;
  public void success(Object value){this.value=value;completed=true;responses++;}
  public void error(String code,String message,Object details){error=code;completed=true;responses++;}
  public void notImplemented(){error="NOT_IMPLEMENTED";completed=true;}
 }
 private static Reply dispatch(String method,String id,String request){
  Map<String,Object> args=new HashMap<>();if(id!=null)args.put("id",id);if(request!=null)args.put("request",request);
  Reply reply=new Reply();MethodChannel.latest.dispatch(new MethodCall(method,args),reply);return reply;
 }
 @SuppressWarnings("unchecked") private static List<Map<String,Object>> files(){return (List<Map<String,Object>>)((Map<String,Object>)dispatch("list",null,null).value).get("files");}
 private static String id(String name){for(Map<String,Object> file:files())if(name.equals(file.get("name")))return (String)file.get("id");return null;}
 private static final class Metadata implements Cursor {
  final String name;Metadata(String name){this.name=name;}
  public boolean moveToFirst(){return true;}
  public int getColumnIndex(String name){return "_display_name".equals(name)?0:1;}
  public boolean isNull(int index){return index==1;}
  public int getType(int index){return FIELD_TYPE_STRING;}
  public String getString(int index){return name;}
  public long getLong(int index){throw new AssertionError("Unknown size must not be read");}
  public void close(){}
 }
 private static final class Provider extends ContentResolver {
  final CountDownLatch inspectingB=new CountDownLatch(1),releaseB=new CountDownLatch(1);
  volatile CancellationSignal signalB;final Set<String> threads=Collections.synchronizedSet(new HashSet<String>());
  volatile int opens;
  final CountDownLatch readingG=new CountDownLatch(1),releaseG=new CountDownLatch(1);
  public Cursor query(Uri uri,String[] columns,String selection,String[] args,String order,CancellationSignal signal){
   threads.add(Thread.currentThread().getName());
   if(uri.toString().endsWith("/b")){
    signalB=signal;inspectingB.countDown();
    try{if(!releaseB.await(4,TimeUnit.SECONDS))throw new IllegalStateException("Barrier expired");}
    catch(InterruptedException error){Thread.currentThread().interrupt();throw new IllegalStateException(error);}
   }
   return new Metadata(uri.toString().substring(uri.toString().lastIndexOf('/')+1)+".csv");
  }
  public AssetFileDescriptor openAssetFileDescriptor(Uri uri,String mode,CancellationSignal signal){
   opens++;threads.add(Thread.currentThread().getName());
   if(uri.toString().endsWith("/g"))return new AssetFileDescriptor(new InputStream(){
    volatile boolean closed;boolean delivered;
    public int read() throws IOException {return read(new byte[1],0,1);}
    public int read(byte[] bytes,int offset,int length) throws IOException {
     if(delivered)return -1;
     readingG.countDown();
     try {if(!releaseG.await(4,TimeUnit.SECONDS))throw new IOException("Owned read barrier expired");}
     catch(InterruptedException interrupted){Thread.currentThread().interrupt();throw new IOException(interrupted);}
     if(closed)throw new IOException("Owned stream closed");bytes[offset]=1;delivered=true;return 1;
    }
    public void close(){closed=true;releaseG.countDown();}
   });
   return new AssetFileDescriptor(new ByteArrayInputStream(new byte[]{1,2,3}));
  }
 }
 public static void main(String[] ignored) throws Exception {
  final java.util.concurrent.atomic.AtomicBoolean granted=new java.util.concurrent.atomic.AtomicBoolean(true);
  Provider provider=new Provider();Context context=new Context(){
   public int checkUriPermission(Uri uri,int pid,int uid,int mode){return granted.get()?0:-1;}
   public ContentResolver getContentResolver(){return provider;}
  };
  IncomingFileChannel channel=new IncomingFileChannel(context,new BinaryMessenger(){});
  try {
   channel.offer(new Intent(Uri.parse("content://owned/a")));waitFor(()->id("a.csv")!=null);String a=id("a.csv");
   channel.offer(new Intent(Uri.parse("content://owned/b")));check(provider.inspectingB.await(4,TimeUnit.SECONDS),"B metadata worker started");
   Reply busy=dispatch("read",a,"read-a");check("INCOMING_BUSY".equals(busy.error),"A read must reject while B inspection owns worker");
   check(provider.opens==0,"BUSY read must not open A");
   dispatch("finish",a,null);
   check(id("a.csv")==null,"Finished pending request A must not resurrect after BUSY");
   check(!provider.signalB.isCanceled(),"Finishing A must preserve B inspection");
   dispatch("finish",a,null);check(!provider.signalB.isCanceled(),"Repeated finish A must preserve B");
   provider.releaseB.countDown();waitFor(()->id("b.csv")!=null);String b=id("b.csv");
   check(files().size()==1,"Only B survives cancellation and inspection completion");
   Reply first=dispatch("read",b,"read-b-1");waitFor(()->first.completed);check(first.error==null&&((byte[])first.value).length==3,"B successor can read after worker exit");
   dispatch("finish",a,null);
   Reply retry=dispatch("read",b,"read-b-2");waitFor(()->retry.completed);check(retry.error==null,"Stale finish A must not release active B");
   channel.offer(new Intent(Uri.parse("content://owned/c")));waitFor(()->id("c.csv")!=null);String c=id("c.csv");
   dispatch("finish",c,null);check(files().isEmpty(),"Finish pending C removes only C while B stays active");
   Reply last=dispatch("read",b,"read-b-3");waitFor(()->last.completed);check(last.error==null,"Pending finish C must preserve active B");
   dispatch("finish",b,null);Reply stale=dispatch("read",b,"read-stale");check("INCOMING_INVALID".equals(stale.error),"Finished B cannot read again");
   check(provider.threads.size()==1,"Inspection and reads retain exactly one worker");
   check(Handler.deadlines()==0,"Completed/cancelled jobs remove owned deadlines");
   channel.offer(new Intent(Uri.parse("content://owned/d")));waitFor(()->id("d.csv")!=null);String d=id("d.csv");
   int beforeRevocation=provider.opens;granted.set(false);
   Reply revoked=dispatch("read",d,"read-revoked");waitFor(()->revoked.completed);
   check("INCOMING_REJECTED".equals(revoked.error),"Grant revoked after metadata must reject bytes");
   check(provider.opens==beforeRevocation,"Revoked grant must never open provider stream");
   granted.set(true);Reply restored=dispatch("read",d,"read-restored");waitFor(()->restored.completed);
   check(restored.error==null,"Explicit retry may use the same recording after its grant is restored");
   dispatch("finish",d,null);granted.set(false);
   channel.offer(new Intent(Uri.parse("content://owned/no-grant")));
   check(files().isEmpty(),"Unverified grant must not enter the catalog");granted.set(true);
   channel.offer(new Intent(Uri.parse("content://owned/g")));waitFor(()->id("g.csv")!=null);String oldG=id("g.csv");
   Reply interrupted=dispatch("read",oldG,"read-engine-close");check(provider.readingG.await(4,TimeUnit.SECONDS),"Owned provider read reached its barrier");
   java.lang.reflect.Field field=IncomingFileChannel.class.getDeclaredField("worker");field.setAccessible(true);
   ExecutorService ownedWorker=(ExecutorService)field.get(channel);
   channel.close();provider.releaseG.countDown();
   check("INCOMING_CLOSED".equals(interrupted.error),"Engine close settles its active request");
   check(ownedWorker.awaitTermination(4,TimeUnit.SECONDS),"Closed engine worker exits gracefully after its owned stream stops");Handler.drain();
   check(interrupted.responses==1,"Late read completion after engine close cannot reply twice");
   check(Handler.deadlines()==0,"Engine close removes its owned deadline");
   IncomingFileChannel restarted=new IncomingFileChannel(context,new BinaryMessenger(){});
   try {
    check(files().isEmpty(),"Fresh engine must not resurrect prior grants/catalog entries");
    Reply staleEngine=dispatch("read",oldG,"read-old-engine");check("INCOMING_INVALID".equals(staleEngine.error),"Old engine ID is invalid after restart");
    channel.offer(new Intent(Uri.parse("content://owned/closed")));check(files().isEmpty(),"Closed engine ignores late arrivals");
    restarted.offer(new Intent(Uri.parse("content://owned/g")));waitFor(()->id("g.csv")!=null);String currentG=id("g.csv");
    check(!oldG.equals(currentG),"Redelivered URI receives a fresh engine-scoped ID");
    dispatch("finish",oldG,null);check(currentG.equals(id("g.csv")),"Old finish cannot remove the redelivered successor");
    Reply fresh=dispatch("read",currentG,"read-new-engine");waitFor(()->fresh.completed);check(fresh.error==null&&((byte[])fresh.value).length==1,"Explicit fresh-engine read remains usable");
    dispatch("finish",currentG,null);check(files().isEmpty(),"Fresh-engine completion releases only its own descriptor");
   } finally {restarted.close();Handler.drain();}
   System.out.println("Production incoming channel contract: "+checks+" checks passed.");
  } finally {provider.releaseB.countDown();channel.close();Handler.drain();}
 }
}
