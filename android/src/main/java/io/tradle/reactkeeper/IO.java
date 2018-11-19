package io.tradle.reactkeeper;

import java.io.Closeable;
import java.io.IOException;

public class IO {

  public final static int BUFFER_SIZE = 8192;

  protected static void closeQuietly(Closeable closeable) {
    try {
      closeable.close();
    } catch (IOException e) {
      // shhh
    }
  }
}
