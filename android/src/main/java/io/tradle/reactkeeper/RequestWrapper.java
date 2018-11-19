package io.tradle.reactkeeper;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;

public class RequestWrapper {

  private enum RequestStatus {
    pending,
    rejected,
    resolved,
  }

  public final KeeperOpts opts;
  public final Promise promise;
  private RequestStatus status;
  private WritableMap response;

  public RequestWrapper(KeeperOpts opts, Promise promise) {
    this.opts = opts;
    this.promise = promise;
    this.response = Arguments.createMap();
    this.status = RequestStatus.pending;
  }

  public static RequestWrapper fromOpts(ReadableMap rawOpts, Promise promise) {
    KeeperOpts opts = null;
    try {
      opts = KeeperOpts.fromOpts(rawOpts);
    } catch (IllegalArgumentException i) {
      RequestWrapper req = new RequestWrapper(null, promise);
      req.reject(Errors.INVALID_OPTIONS, i);
      return req;
    }

    return new RequestWrapper(opts, promise);
  }

//  public RequestWrapper(Promise promise) {
//    this(null, promise);
//  }

  public boolean isDone() {
    return this.status != RequestStatus.pending;
  }

  public boolean isRejected() {
    return this.status == RequestStatus.rejected;
  }

  public boolean isResolved() {
    return this.status == RequestStatus.resolved;
  }

  public void reject(String code, Throwable e) {
    this.status = RequestStatus.rejected;
    this.promise.reject(code, e);
  }

  public void reject(String code, String message) {
    this.status = RequestStatus.rejected;
    this.promise.reject(code, message);
  }

  public void resolve() {
    this.status = RequestStatus.resolved;
    this.promise.resolve(this.response);
  }

  public void setResponseProperty(String key, String value) {
    this.response.putString(key, value);
  }

  public void setResponseProperty(String key, boolean value) {
    this.response.putBoolean(key, value);
  }
}
