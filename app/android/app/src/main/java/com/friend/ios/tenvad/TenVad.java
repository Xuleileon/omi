//
// TEN VAD Java wrapper (Android)
// - Uses JNA to call native libten_vad.so from jniLibs/
//

package com.friend.ios.tenvad;

import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.ptr.PointerByReference;

public class TenVad {
  public interface CLib extends Library {
    CLib INSTANCE = Native.load("ten_vad", CLib.class);

    int ten_vad_create(PointerByReference handle, int hopSize, float threshold);

    int ten_vad_process(
        Pointer handle,
        short[] audioData,
        int audioDataLength,
        float[] outProbability,
        int[] outFlag);

    int ten_vad_destroy(PointerByReference handle);

    String ten_vad_get_version();
  }

  private Pointer vadHandle;
  private final int hopSize;
  private final float threshold;

  public TenVad(int hopSize, float threshold) {
    this.hopSize = hopSize;
    this.threshold = threshold;

    PointerByReference ref = new PointerByReference();
    int res = CLib.INSTANCE.ten_vad_create(ref, hopSize, threshold);
    if (res != 0) throw new RuntimeException("Create TEN VAD failed, code=" + res);
    vadHandle = ref.getValue();
  }

  public VadResult process(short[] audioData) {
    if (audioData.length != hopSize)
      throw new IllegalArgumentException("Audio data length must be " + hopSize + ", got " + audioData.length);

    float[] probability = new float[1];
    int[] flag = new int[1];
    int res = CLib.INSTANCE.ten_vad_process(vadHandle, audioData, audioData.length, probability, flag);
    if (res != 0) throw new RuntimeException("TEN VAD process failed, code=" + res);

    return new VadResult(probability[0], flag[0]);
  }

  public void destroy() {
    if (vadHandle != null) {
      PointerByReference ref = new PointerByReference(vadHandle);
      CLib.INSTANCE.ten_vad_destroy(ref);
      vadHandle = null;
    }
  }

  public static String getVersion() {
    return CLib.INSTANCE.ten_vad_get_version();
  }

  public int getHopSize() {
    return hopSize;
  }

  public float getThreshold() {
    return threshold;
  }

  public static class VadResult {
    private final float probability;
    private final int flag;

    public VadResult(float probability, int flag) {
      this.probability = probability;
      this.flag = flag;
    }

    public float getProbability() {
      return probability;
    }

    public int getFlag() {
      return flag;
    }

    public boolean isVoiceDetected() {
      return flag == 1;
    }
  }
}

