package io.tradle.reactkeeper;

import com.facebook.android.crypto.keychain.AndroidConceal;
import com.facebook.common.util.Hex;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.HashMap;
import java.util.Map;

public class Crypto {
  private final static Map<String, String> algorithms = new HashMap<>();
  private final static SecureRandom random = new SecureRandom();

  static {
    algorithms.put("md5", "MD5");
    algorithms.put("sha1", "SHA-1");
    algorithms.put("sha224", "SHA-224");
    algorithms.put("sha256", "SHA-256");
    algorithms.put("sha384", "SHA-384");
    algorithms.put("sha512", "SHA-512");
  }

  public static boolean isValidDigestAlgorithm(String algorithm) {
    return algorithms.containsKey(algorithm);
  }

  public static class HashGenerationException extends RuntimeException {
    public HashGenerationException(String msg) {
      super(msg);
    }
  }

  public static MessageDigest getDigestAlgorithm(String algorithm) {
    if (!isValidDigestAlgorithm(algorithm)) {
      throw new IllegalArgumentException("Invalid hash algorithm: caller at fault");
    }

    try {
      return MessageDigest.getInstance(algorithms.get(algorithm));
    } catch (NoSuchAlgorithmException n) {
      throw new IllegalArgumentException("Invalid hash algorithm: developer at fault");
    }
  }

  public static byte[] hash(byte[] data, String algorithm) throws HashGenerationException {
    MessageDigest digest = getDigestAlgorithm(algorithm);
    InputStream is = new ByteArrayInputStream(data);
    DigestInputStream digestInputStream = new DigestInputStream(is, digest);
    byte[] buffer = new byte[IO.BUFFER_SIZE];
    try {
      while (digestInputStream.read(buffer) > -1) {
      }
      return digestInputStream.getMessageDigest().digest();
    } catch (IOException i) {
      throw new HashGenerationException("failed to get digest");
    } finally {
      IO.closeQuietly(is);
      IO.closeQuietly(digestInputStream);
    }
  }

  public static String hashAndHex(byte[] data, String algorithm) {
    byte[] bytes = hash(data, algorithm);
    return bytesToHex(bytes);
  }

  public static byte[] hexToBytes(String hex) {
    return Hex.decodeHex(hex);
  }

  public static String bytesToHex(byte[] data) {
    return Hex.encodeHex(data, false).toLowerCase();
  }

  public static byte[] randomBytes(int length) {
    byte[] bytes = new byte[length];
    random.nextBytes(bytes);
    return bytes;
  }

//  public static String bytesToHex(byte[] data) {
//    StringBuilder hexString = new StringBuilder();
//    for (byte b: data) {
//      hexString.append(String.format("%02x", b));
//    }
//
//    return hexString.toString();
//  }

//  public static byte[] encrypt(String id, byte[] data, byte[] encryptionKey, byte[] hmacKey)
//          throws KeyChainException, CryptoInitializationException, IOException {
//    KeyChain keyChain = new ConcealKeyChain(encryptionKey, hmacKey);
//    com.facebook.crypto.Crypto crypto = AndroidConceal.get().createCrypto256Bits(keyChain);
//    if (!crypto.isAvailable()) {
//      throw new UnsupportedOperationException("requested crypto not available");
//    }
//
//    return crypto.encrypt(data, Entity.create(id));
//  }

  public static boolean isCryptoAvailable() {
    try {
      AndroidConceal.get().nativeLibrary.ensureCryptoLoaded();
      return true;
    } catch (Exception i) {
    }

    return false;
  }
}
