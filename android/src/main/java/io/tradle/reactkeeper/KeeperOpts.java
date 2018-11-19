package io.tradle.reactkeeper;

import com.facebook.android.crypto.keychain.AndroidConceal;
import com.facebook.crypto.keychain.KeyChain;
import com.facebook.react.bridge.ReadableMap;

import javax.annotation.Nullable;

public class KeeperOpts {
  public enum Encoding {
    utf8,
    base64
  }

  public enum HashInput {
    valueBytes,
    // this is really just for Tradle's use case
    dataUrlForValue,
  }

  public String key;
  public String value;
  public String imageTag;
  public byte[] encryptionKey;
  public byte[] hmacKey;
  public String digestAlgorithm;
  public Encoding encoding;
  public HashInput hashInput;
  public boolean addToImageStore;
  public boolean returnBase64;
  public KeyChain keyChain;
  private com.facebook.crypto.Crypto crypto;

  private KeeperOpts() {}
  public com.facebook.crypto.Crypto getCrypto() {
    if (crypto == null) {
      this.crypto = AndroidConceal.get().createCrypto256Bits(this.keyChain);
    }

    return this.crypto;
  }

  private static class Builder {
    private String key;
    private String value;
    private String imageTag;
    private byte[] encryptionKey;
    private byte[] hmacKey;
    private String digestAlgorithm;
    private Encoding encoding;
    private HashInput hashInput;
    private boolean addToImageStore;
    private boolean returnBase64;
    private KeyChain keyChain;

    public Builder() {}

    public Builder setKey(String value) {
      key = value;
      return this;
    }

    public Builder setValue(String value) {
      this.value = value;
      return this;
    }

    public Builder setImageTag(String value) {
      this.imageTag = value;
      return this;
    }

    public Builder setEncryptionKey(byte[] value) {
      encryptionKey = value;
      return this;
    }

    public Builder setHmacKey(byte[] value) {
      hmacKey = value;
      return this;
    }

    public Builder setDigestAlgorithm(String value) {
      digestAlgorithm = value;
      return this;
    }

    public Builder setEncoding(Encoding value) {
      encoding = value;
      return this;
    }

    public Builder setHashInput(HashInput value) {
      hashInput = value;
      return this;
    }

    public Builder setAddToImageStore(boolean value) {
      addToImageStore = value;
      return this;
    }

    public Builder setReturnBase64(boolean value) {
      returnBase64 = value;
      return this;
    }

    public KeeperOpts build() {
      KeeperOpts opts = new KeeperOpts();
      opts.key = this.key;
      opts.value = this.value;
      opts.imageTag = this.imageTag;
      opts.encryptionKey = this.encryptionKey;
      opts.hmacKey = this.hmacKey;
      opts.digestAlgorithm = this.digestAlgorithm;
      opts.encoding = this.encoding;
      opts.hashInput = this.hashInput;
      opts.addToImageStore = this.addToImageStore;
      opts.returnBase64 = this.returnBase64;
      if (this.encryptionKey != null && this.hmacKey != null) {
        opts.keyChain = new ConcealKeyChain(this.encryptionKey, this.hmacKey);
      }

      return opts;
    }
  }

  public static KeeperOpts fromOpts(ReadableMap opts) throws IllegalArgumentException {
    Builder builder = new Builder();
    builder.setKey(getString(opts, "key"));
    builder.setValue(getString(opts, "value"));
    builder.setImageTag(getString(opts, "imageTag"));
    builder.setEncryptionKey(getBytesFromHexString(opts, "encryptionKey"));
    builder.setHmacKey(getBytesFromHexString(opts, "hmacKey"));
    String digestAlgorithm = getString(opts, "digestAlgorithm");
    if (!Crypto.isValidDigestAlgorithm(digestAlgorithm)) {
      throw new IllegalArgumentException("invalid digestAlgorithm");
    }

    builder.setDigestAlgorithm(digestAlgorithm);
    String encoding = getString(opts, "encoding", Encoding.base64.name());
    try {
      builder.setEncoding(Encoding.valueOf(encoding));
    } catch (IllegalArgumentException i) {
      throw new IllegalArgumentException("invalid encoding");
    }

    String hashInput = getString(opts, "hashInput", HashInput.valueBytes.name());
    try {
      builder.setHashInput(HashInput.valueOf(hashInput));
    } catch (IllegalArgumentException i) {
      throw new IllegalArgumentException("invalid hashInput");
    }

    builder.setAddToImageStore(getBoolean(opts, "addToImageStore", false));
    builder.setReturnBase64(getBoolean(opts, "returnBase64", true));
    return builder.build();
  }

  private static byte[] getBytesFromHexString(ReadableMap opts, String name) {
    String hex = getString(opts, name);
    return Crypto.hexToBytes(hex);
  }

  private static String getString(ReadableMap opts, String name) {
    return getString(opts, name, null);
  }

  private static String getString(ReadableMap opts, String name, @Nullable String defaultValue) {
    return opts.hasKey(name) ? opts.getString(name) : defaultValue;
  }

  private static boolean getBoolean(ReadableMap opts, String name, boolean defaultValue) {
    return opts.hasKey(name) ? opts.getBoolean(name) : false;
  }
}
