package android.content;
import android.net.Uri;
public abstract class Context {
 public abstract int checkUriPermission(Uri uri,int pid,int uid,int mode);
 public abstract ContentResolver getContentResolver();
}
