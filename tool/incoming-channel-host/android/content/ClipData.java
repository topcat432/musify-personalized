package android.content;
import android.net.Uri;
public final class ClipData {
 public int getItemCount(){return 0;}
 public Item getItemAt(int index){throw new IndexOutOfBoundsException();}
 public static final class Item {public Uri getUri(){return null;}}
}
