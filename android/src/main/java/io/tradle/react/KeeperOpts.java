package io.tradle.react;

import com.facebook.crypto.keychain.KeyChain;
import com.facebook.react.bridge.ReadableMap;

public class KeeperOpts {
  public enum Encoding {
    utf8,
    base64
  }

  public String key;
  public String value;
  public byte[] encryptionKey;
  public byte[] hmacKey;
  public String digestAlgorithm;
  public Encoding encoding;
  public boolean hashDataUrl;
  public boolean addToImageStore;
  public KeyChain keyChain;

  private KeeperOpts() {}

  private static class Builder {
    private String key;
    private String value;
    private byte[] encryptionKey;
    private byte[] hmacKey;
    private String digestAlgorithm;
    private Encoding encoding;
    private boolean hashDataUrl;
    private boolean addToImageStore;
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

    public Builder setHashDataUrl(boolean value) {
      hashDataUrl = value;
      return this;
    }

    public Builder setAddToImageStore(boolean value) {
      addToImageStore = value;
      return this;
    }

    public KeeperOpts build() {
      KeeperOpts opts = new KeeperOpts();
      opts.key = this.key;
      opts.value = this.value;
      opts.encryptionKey = this.encryptionKey;
      opts.hmacKey = this.hmacKey;
      opts.digestAlgorithm = this.digestAlgorithm;
      opts.encoding = this.encoding;
      opts.hashDataUrl = this.hashDataUrl;
      opts.addToImageStore = this.addToImageStore;
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
    builder.setEncryptionKey(getBytesFromHexString(opts, "encryptionKey"));
    builder.setHmacKey(getBytesFromHexString(opts, "hmacKey"));
    String digestAlgorithm = getString(opts, "digestAlgorithm");
    if (!Crypto.isValidDigestAlgorithm(digestAlgorithm)) {
      throw new IllegalArgumentException("invalid digestAlgorithm");
    }

    builder.setDigestAlgorithm(digestAlgorithm);
    String encoding = getString(opts, "encoding");
    if (encoding != null) {
      try {
        builder.setEncoding(Encoding.valueOf(encoding));
      } catch (IllegalArgumentException i) {
        throw new IllegalArgumentException("invalid encoding");
      }
    }

    builder.setHashDataUrl(getBoolean(opts, "hashDataUrl", false));
    builder.setAddToImageStore(getBoolean(opts, "addToImageStore", false));
    return builder.build();
  }

  private static byte[] getBytesFromHexString(ReadableMap opts, String name) {
    String hex = getString(opts, name);
    return Crypto.hexToBytes(hex);
  }

  private static String getString(ReadableMap opts, String name) {
    return opts.hasKey(name) ? opts.getString(name) : null;
  }

  private static boolean getBoolean(ReadableMap opts, String name, boolean defaultValue) {
    return opts.hasKey(name) ? opts.getBoolean(name) : false;
  }
}
