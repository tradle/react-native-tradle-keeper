
package io.tradle.react;

import android.util.Base64;

import com.facebook.android.crypto.keychain.AndroidConceal;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;

import java.io.IOException;
import java.io.UnsupportedEncodingException;

public class RNTradleKeeperModule extends ReactContextBaseJavaModule {

  private final ReactApplicationContext reactContext;
  private final boolean cryptoIsAvailable;
  private static final String INVALID_OPTIONS = "RNTradleKeeperInvalidOption";
  private static final String CRYPTO_NOT_AVAILABLE = "RNTradleKeeperCryptoNotAvailable";
  private static final String ENCRYPTION_ERROR = "RNTradleKeeperEncryptionError";
  private static final String IMAGE_STORE_ERROR = "RNTradleKeeperImageStoreError";

  public RNTradleKeeperModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
    this.cryptoIsAvailable = Crypto.isCryptoAvailable();
  }

  @Override
  public String getName() {
    return "RNTradleKeeper";
  }

  @ReactMethod
  public void put(ReadableMap rawOptions, Promise promise) {
    if (!rejectIfNoCrypto(promise)) {
      return;
    }

    KeeperOpts opts;
    try {
      opts = KeeperOpts.fromOpts(rawOptions);
    } catch (IllegalArgumentException i) {
      promise.reject(INVALID_OPTIONS, i.getMessage());
      return;
    }

    setKeyIfNotExists(opts);

    byte[] imageBytes = parseValue(opts);
    try {
      encryptToFS(imageBytes, opts);
    } catch (Exception e) {
      promise.reject(ENCRYPTION_ERROR, e.getMessage());
      return;
    }

    if (opts.addToImageStore) {
      try {
        ImageStoreModule.storeImageBytes(getReactApplicationContext(), imageBytes);
      } catch (IOException i) {
        promise.reject(IMAGE_STORE_ERROR, i.getMessage());
        return;
      }
    }

    promise.resolve(null);
  }

  

  private void setKeyIfNotExists(KeeperOpts opts) {
    if (opts.key == null) {
      opts.key = Crypto.hashAndHex(data, opts.digestAlgorithm);
    }
  }

  private void encryptToFS(byte[] plaintext, KeeperOpts opts) throws Exception {
    byte[] ciphertext = Crypto.encrypt(opts.key, plaintext, opts.encryptionKey, opts.hmacKey);

  }

  private byte[] parseValue(KeeperOpts opts) {
    if (opts.encoding == KeeperOpts.Encoding.utf8) {
      try {
        return opts.value.getBytes("UTF-8");
      } catch (UnsupportedEncodingException e) {
        // will never happen
        return null;
      }
    }

    return Base64.decode(opts.value, Base64.DEFAULT);
  }

  private boolean rejectIfNoCrypto(Promise promise) {
    if (!cryptoIsAvailable) {
      promise.reject(CRYPTO_NOT_AVAILABLE, "your hardware doesn't support the crypto I need");
    }

    return cryptoIsAvailable;
  }
}