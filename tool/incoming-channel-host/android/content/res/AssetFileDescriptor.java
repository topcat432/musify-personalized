package android.content.res;
import java.io.*;
public final class AssetFileDescriptor implements AutoCloseable {
 private final InputStream input;
 public AssetFileDescriptor(InputStream input){this.input=input;}
 public InputStream createInputStream(){return input;}
 public void close() throws IOException {input.close();}
}
