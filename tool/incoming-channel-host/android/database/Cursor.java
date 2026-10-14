package android.database;
public interface Cursor extends AutoCloseable {
 int FIELD_TYPE_STRING=3,FIELD_TYPE_INTEGER=1;
 boolean moveToFirst(); int getColumnIndex(String name); boolean isNull(int index);
 int getType(int index); String getString(int index); long getLong(int index); void close();
}
