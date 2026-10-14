package android.content;
import android.net.Uri;
import android.database.Cursor;
import android.os.CancellationSignal;
import android.content.res.AssetFileDescriptor;
public abstract class ContentResolver {
 public abstract Cursor query(Uri uri,String[] columns,String selection,String[] args,String order,CancellationSignal signal);
 public abstract AssetFileDescriptor openAssetFileDescriptor(Uri uri,String mode,CancellationSignal signal);
}
