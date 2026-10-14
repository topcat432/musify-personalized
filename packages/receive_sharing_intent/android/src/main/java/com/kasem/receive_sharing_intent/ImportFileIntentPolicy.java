package com.kasem.receive_sharing_intent;

/** Only the file MIME types registered by Musify's explicit import intake. */
public final class ImportFileIntentPolicy {
  private ImportFileIntentPolicy() {}
  public static boolean excludeFromLegacyCopy(String action, String mime, boolean hasStream) {
    if (!hasStream || !("android.intent.action.SEND".equals(action)
        || "android.intent.action.SEND_MULTIPLE".equals(action))) return false;
    return "text/csv".equals(mime) || "text/tab-separated-values".equals(mime)
        || "text/plain".equals(mime) || "application/json".equals(mime)
        || "application/zip".equals(mime) || "application/x-zip-compressed".equals(mime)
        || "application/octet-stream".equals(mime);
  }
}
