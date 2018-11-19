
package io.tradle.reactkeeper;

import android.content.ContentResolver;
import android.net.Uri;
import android.util.Base64;
import android.util.Base64OutputStream;

import com.facebook.crypto.Entity;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;

import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;

import io.tradle.reactimagestore.ImageStoreModule;
import io.tradle.reactimagestore.ImageStoreUtils;

public class RNTradleKeeperModule extends ReactContextBaseJavaModule {

  private static final String CRYPTO_NOT_AVAILABLE = "RNTradleKeeperCryptoNotAvailable";
  private static final String ENCRYPTION_ERROR = "RNTradleKeeperEncryptionError";
  private static final String DECRYPTION_ERROR = "RNTradleKeeperDecryptionError";
  private static final String IMAGE_STORE_ERROR = "RNTradleKeeperImageStoreError";

  private final ReactApplicationContext reactContext;
  private final boolean cryptoIsAvailable;
  private final Uri baseDirUri;

  public RNTradleKeeperModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
    this.cryptoIsAvailable = Crypto.isCryptoAvailable();
    this.baseDirUri = Uri.fromFile(reactContext.getFilesDir());
  }

  @Override
  public String getName() {
    return "RNTradleKeeper";
  }

  @ReactMethod
  public void put(ReadableMap rawOptions, Promise promise) {
    if (!rejectIfNoCrypto(promise)) return;

    RequestWrapper req = RequestWrapper.fromOpts(rawOptions, promise);
    if (req.isDone()) return;

    KeeperOpts opts = req.opts;
    byte[] imageBytes = parseValue(opts);

    setKeyIfNotSet(opts, imageBytes);

    try {
      encryptAndStore(imageBytes, opts);
    } catch (Exception e) {
      promise.reject(ENCRYPTION_ERROR, e.getMessage());
      return;
    }

    maybeAddToImageStore(req, imageBytes);
    if (req.isDone()) return;

    req.resolve();
  }

  @ReactMethod
  public void get(ReadableMap rawOptions, Promise promise) {
    if (!rejectIfNoCrypto(promise)) return;

    RequestWrapper req = RequestWrapper.fromOpts(rawOptions, promise);
    if (req.isDone()) return;

    KeeperOpts opts = req.opts;
    if (!(opts.returnBase64 || opts.addToImageStore)) {
      req.reject(Errors.INVALID_OPTIONS, "expected returnBase64 or addToImageStore");
      return;
    }

    FileData data;
    try {
      data = decryptToFileData(opts);
    } catch (Exception i) {
      req.reject(DECRYPTION_ERROR, i);
      return;
    }

    maybeAddToImageStore(req, data.bytes);
    if (req.isDone()) return;

    if (opts.returnBase64) {
      req.setResponseProperty("base64", data.base64);
    }

    req.resolve();
  }

  @ReactMethod
  public void importFromImageStore(ReadableMap rawOptions, Promise promise) {
    if (!rejectIfNoCrypto(promise)) return;

    RequestWrapper req = RequestWrapper.fromOpts(rawOptions, promise);
    if (req.isDone()) return;

    KeeperOpts opts = req.opts;
    byte[] imageBytes;
    try {
      imageBytes = ImageStoreModule.getImageDataForTag(this.reactContext, opts.imageTag);
    } catch (IOException i) {
      req.reject(IMAGE_STORE_ERROR, i);
      return;
    }

    setKeyIfNotSet(opts, imageBytes);

    try {
      encryptAndStore(imageBytes, opts);
    } catch (Exception i) {
      req.reject(IMAGE_STORE_ERROR, i);
      return;
    }

    req.setResponseProperty("key", opts.key);
    req.resolve();
  }

  private FileData decryptToFileData(KeeperOpts opts) throws Exception {
    Uri sourceUri = getUriForKey(opts.key);
    ContentResolver contentResolver = reactContext.getContentResolver();
    InputStream fileStream = null;
    InputStream inputStream = null;
    ByteArrayOutputStream outBytes = opts.addToImageStore ? new ByteArrayOutputStream() : null;
    ByteArrayOutputStream outBase64 = opts.returnBase64 ? new ByteArrayOutputStream() : null;
    Base64OutputStream base64Converter = outBase64 == null ? null : new Base64OutputStream(outBase64, Base64.NO_WRAP);
    try {
      fileStream = contentResolver.openInputStream(sourceUri);
      inputStream = opts.getCrypto().getCipherInputStream(fileStream, Entity.create(opts.key));
      int read;
      byte[] buffer = new byte[IO.BUFFER_SIZE];
      while (true) {
        read = inputStream.read(buffer);
        if (read == -1) break;
        if (outBytes != null) {
          outBytes.write(buffer, 0, read);
        }

        if (base64Converter != null) {
          base64Converter.write(buffer, 0, read);
        }
      }
    } finally {
      if (fileStream != null) {
        IO.closeQuietly(fileStream);
      }

      if (inputStream != null) {
        IO.closeQuietly(inputStream);
      }
    }

    return new FileData(
      outBytes == null ? null : outBytes.toByteArray(),
      outBase64 == null ? null : outBase64.toString()
    );
  }

  private void maybeAddToImageStore(RequestWrapper req, byte[] imageBytes) {
    if (!req.opts.addToImageStore) return;

    try {
      Uri imageTag = ImageStoreModule.storeImageBytes(this.reactContext, imageBytes);
      req.setResponseProperty("imageTag", imageTag.toString());
    } catch (IOException i) {
      req.reject(IMAGE_STORE_ERROR, i);
    }
  }

//  private void verifyIntegrity(File file, byte[] plaintext, KeeperOpts opts) throws IOException {
//    FileInputStream fileStream = new FileInputStream(file);
//    Entity entity = Entity.create(opts.key);
//    OutputStream outputStream = opts.getCrypto().getMacInputStream(fileStream, entity);
//    outputStream.write(plaintext);
//    outputStream.close();
//
//    InputStream inputStream = crypto.getMacInputStream(fileStream, entity);
//
//// Will throw an exception if mac verification fails.
//// You must read the entire stream to completion.
//// The verification is done at the end of the stream.
//// Thus not reading till the end of the stream will cause
//// a security bug. For safety, you should not
//// use any of the data until it's been fully read or throw
//// away the data if an exception occurs.
//    while((read = inputStream.read(buffer)) != -1) {
//      out.write(buffer, 0, read);
//    }
//    inputStream.close();
//  }

//  private byte[] decrypt(KeeperOpts opts) throws Exception {
//    Uri sourceUri = getUriForKey(opts.key);
//    FileInputStream fileStream = null;
//    InputStream inputStream = null;
//    ByteArrayOutputStream out = new ByteArrayOutputStream();
//    try {
//      fileStream = new FileInputStream(new File(sourceUri.getPath()));
//      inputStream = opts.getCrypto().getCipherInputStream(fileStream, Entity.create(opts.key));
//      int read;
//      byte[] buffer = new byte[IO.BUFFER_SIZE];
//      while ((read = inputStream.read(buffer)) != -1) {
//        out.write(buffer, 0, read);
//      }
//
//      return out.toByteArray();
//    } finally {
//      if (fileStream != null) {
//        IO.closeQuietly(fileStream);
//      }
//
//      if (inputStream != null) {
//        IO.closeQuietly(inputStream);
//      }
//    }
//  }

  private void setKeyIfNotSet(KeeperOpts opts, byte[] plaintext) {
    if (opts.key != null) return;

    String base64 = opts.value;
    if (opts.hashInput == KeeperOpts.HashInput.dataUrlForValue) {
      if (base64 == null) {
        base64 = Base64.encodeToString(plaintext, Base64.NO_WRAP);
      }

      String dataUrl = String.format("data:%s;base64,%s", ImageStoreUtils.getMimeTypeFromImageBytes(plaintext), base64);
      plaintext = dataUrl.getBytes();
    }

    opts.key = Crypto.hashAndHex(plaintext, opts.digestAlgorithm);
  }

  private Uri encryptAndStore(byte[] plaintext, KeeperOpts opts) throws Exception {
    Uri destUri = getUriForKey(opts.key);
    OutputStream fileStream = null;
    OutputStream cipherStream = null;
    try {
      fileStream = new BufferedOutputStream(new FileOutputStream(new File(destUri.getPath())));
      cipherStream = opts.getCrypto().getCipherOutputStream(
              fileStream,
              Entity.create(opts.key));

      cipherStream.write(plaintext);
    } finally {
      if (cipherStream != null) {
        IO.closeQuietly(cipherStream);
      }

      if (fileStream != null) {
        IO.closeQuietly(fileStream);
      }
    }

    return destUri;
  }

//  private String getPathForKey(String key) {
//    return Uri.withAppendedPath(baseDirUri, key).getPath();
//  }

  private Uri getUriForKey(String key) {
    return Uri.withAppendedPath(baseDirUri, key);
  }

  private byte[] parseValue(KeeperOpts opts) {
    String value = opts.value;
    switch (opts.encoding) {
      case utf8:
        try {
          return value.getBytes("UTF-8");
        } catch (UnsupportedEncodingException e) {
          // will never happen
          return null;
        }
      case base64:
        return Base64.decode(value, Base64.DEFAULT);
    }

    throw new RuntimeException("developer error: unsupported encoding");
  }

  private boolean rejectIfNoCrypto(Promise promise) {
    if (!cryptoIsAvailable) {
      promise.reject(CRYPTO_NOT_AVAILABLE, "your hardware doesn't support the crypto I need");
    }

    return cryptoIsAvailable;
  }

  class FileData {
    public final byte[] bytes;
    public final String base64;
    public FileData(byte[] bytes, String base64) {
      this.bytes = bytes;
      this.base64 = base64;
    }
  }
}
