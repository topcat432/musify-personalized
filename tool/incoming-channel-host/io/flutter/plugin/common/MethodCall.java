package io.flutter.plugin.common;
import java.util.Map;
public final class MethodCall {
 public final String method; private final Map<String,Object> args;
 public MethodCall(String method,Map<String,Object> args){this.method=method;this.args=args;}
 @SuppressWarnings("unchecked") public <T> T argument(String key){return args==null?null:(T)args.get(key);}
}
