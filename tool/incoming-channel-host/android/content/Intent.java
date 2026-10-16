package android.content;
import android.net.Uri;
public final class Intent {
 public static final String ACTION_SEND="android.intent.action.SEND",ACTION_VIEW="android.intent.action.VIEW",ACTION_SEND_MULTIPLE="android.intent.action.SEND_MULTIPLE",EXTRA_STREAM="android.intent.extra.STREAM";
 public static final int FLAG_GRANT_READ_URI_PERMISSION=1;
 private final Uri uri;
 public Intent(Uri uri){this.uri=uri;}
 public String getAction(){return ACTION_VIEW;}
 public String getType(){return "text/csv";}
 public Uri getData(){return uri;}
 public Uri getParcelableExtra(String ignored){return uri;}
 public ClipData getClipData(){return null;}
}
