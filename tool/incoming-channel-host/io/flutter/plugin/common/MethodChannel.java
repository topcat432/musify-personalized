package io.flutter.plugin.common;
public final class MethodChannel {
 public interface Result {void success(Object value);void error(String code,String message,Object details);void notImplemented();}
 public interface MethodCallHandler {void onMethodCall(MethodCall call,Result result);}
 public static MethodChannel latest;
 private MethodCallHandler handler;
 public MethodChannel(BinaryMessenger ignored,String name){latest=this;}
 public void setMethodCallHandler(MethodCallHandler value){handler=value;}
 public void invokeMethod(String name,Object args){}
 public void dispatch(MethodCall call,Result result){if(handler==null)throw new IllegalStateException("Channel closed");handler.onMethodCall(call,result);}
}
