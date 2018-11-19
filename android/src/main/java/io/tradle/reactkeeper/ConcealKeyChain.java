package io.tradle.reactkeeper;

import com.facebook.crypto.keychain.KeyChain;

public class ConcealKeyChain implements KeyChain {
  private static final int GCM_IV_SIZE = 12;

  private final byte[] encryptionKey;
  private final byte[] hmacKey;

  public ConcealKeyChain(final byte[] encryptionKey, final byte[] hmacKey) {
    this.encryptionKey = encryptionKey;
    this.hmacKey = hmacKey;
  }

  @Override
  public byte[] getCipherKey() {
    return encryptionKey;
  }

  @Override
  public byte[] getMacKey() {
    return hmacKey;
  }

  @Override
  public byte[] getNewIV() {
    return Crypto.randomBytes(GCM_IV_SIZE);
  }

  @Override
  public void destroyKeys() {
  }
};