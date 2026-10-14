package android.os;
import java.util.*;
import java.util.concurrent.*;
public final class Handler {
 private static final Queue<Runnable> posted=new ConcurrentLinkedQueue<>();
 private static final Set<Runnable> deadlines=Collections.synchronizedSet(new HashSet<Runnable>());
 public Handler(Looper ignored){}
 public boolean post(Runnable value){posted.add(value);return true;}
 public boolean postDelayed(Runnable value,long milliseconds){deadlines.add(value);return true;}
 public void removeCallbacks(Runnable value){deadlines.remove(value);posted.remove(value);}
 public static void drain(){Runnable next;while((next=posted.poll())!=null)next.run();}
 public static int deadlines(){return deadlines.size();}
}
