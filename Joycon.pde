import purejavahidapi.*;
import purejavahidapi.HidDevice;
import java.util.List;
import java.util.Arrays;

public class Joycon {

  private HidDevice     dev;
  private HidDeviceInfo devInfo;
  // inner class "Rumble" is defined the last of class "Joycon"
  private Rumble rumble;

  private boolean[] buttonsDown = new boolean[13];
  private boolean[] buttonsUp   = new boolean[13];
  private boolean[] buttons      = new boolean[13];
  private boolean[] down_        = new boolean[13];

  private float[] stick = {0, 0};
  private short[] stickRaw = {0, 0, 0};
  private char[]  stickCal = { 0, 0, 0, 0, 0, 0 };
  private char deadzone;

  private short[] accR     = {0, 0, 0};
  private Vector3 accG     = new Vector3(0, 0, 0);
  private Vector3 preAccG = new Vector3(0, 0, 0);

  private short[] gyrR       = {0, 0, 0};
  private short[] gyrNeutral = {0, 0, 0};
  private Vector3 gyrG       = new Vector3(0, 0, 0);
  private Vector3 preGyrG   = new Vector3(0, 0, 0);

  float[] max = {0, 0, 0};
  float[] sum = {0, 0, 0};

  public Vector3 iB, jB, kB, kAcc;

  private int global_count = 0;
  private boolean firstImuPacket = true;
  private float filterweight = 0.5f;
  private int timestamp = 0;
  private int report_len = 49;
  private boolean isLeft = false;
  private float posX, posY;
  private float vx, vy;
  private int t;

  public byte[] spi() {
    return readSPI((byte)0x80, (isLeft ? (byte)0x12 : (byte)0x1d), 9, false);
  }

  Joycon(int _id) {
    if (_id == JoyconConstants.LEFT_ID) isLeft = true;
    connectDevice(_id);
    setReportListener();
    setRemovalListener();
    changeMode();
    posX = 0;
    posY = 0;
    vx = 0;
    vy = 0;
    t  = 0;
    //t  = 1;
    rumble = new Rumble(160, 320, 0, 0);
  }

  ////////////////////////////////////////////////////////////////
  /* initialize methods */
  private void connectDevice(int _id) { 
    List<HidDeviceInfo> devList = PureJavaHidApi.enumerateDevices();

    for (HidDeviceInfo info : devList) {
      if ( info.getVendorId()  != JoyconConstants.VENDOR_ID ) continue;
      if ( info.getProductId() != _id ) continue;

      devInfo = info;
      //System.out.printf(
      //  "VID = 0x%04X PID = 0x%04X Manufacturer = %s Product = %s Path = %s\n", 
      //  info.getVendorId(), 
      //  info.getProductId(), 
      //  info.getManufacturerString(), 
      //  info.getProductString(), 
      //  info.getPath()
      //  );
      break;
    }

    if (devInfo == null) {
      println("Connection Failed");
      return;
    }

    try {
      dev = PureJavaHidApi.openDevice(devInfo);
      println("Connection Successful");
    }
    catch(IOException e) {
      println(e);
    }
  }

  private void setRemovalListener() {
    if (devInfo==null) {
      println("connection error");
      return;
    }
    dev.setDeviceRemovalListener(new DeviceRemovalListener() {
      @Override
        public void onDeviceRemoval(HidDevice source) {
        System.out.println("device removed");
      }
    }
    );
  }

  private void setReportListener() {
    if (devInfo==null) {
      println("connection error");
      return;
    }
    dev.setInputReportListener(new InputReportListener() {
      @Override
        public void onInputReport(HidDevice source, byte Id, byte[] data, int len) {
        //System.out.printf("onInputReport: id %d len %d data ", Id, len);
        for (int i = 0; i < len; i++) System.out.printf("%02x ", data[i]);
        System.out.println();

        processIMU(data);
        processButtonsAndStick(data);

        posX = - ( (1/2) * (gyrG.z) + (gyrG.z) ) + posX;
        posY = (1/2) * (gyrG.y) + (gyrG.y) + posY;
        //vx   = accG.z * t + vx;
        //vy   = accG.y * t + vy;
      }
    }
    );
  }

  private void changeMode() {
    if (devInfo==null) {
      println("connection error");
      return;
    }
    Thread thread = new Thread(new MultiThread() {
      @Override
        public void run() {
        try {
          boolean irMode    = false;
          boolean vibMode   = false;
          boolean lightMode = true;

          joycon_send_subcommand(0x1, Subcommand.EnableIMU.getId(), new byte[] {0x01});
          Thread.sleep(100);

          joycon_send_subcommand(0x1, Subcommand.SetInputReportMode.getId(), new byte[] {0x30});
          Thread.sleep(100);

          if (irMode) {
            // I can't do it.
            Thread.sleep(100);
          }

          if (vibMode) {
            joycon_send_subcommand(0x1, Subcommand.EnableVibration.getId(), new byte[] {0x01});
            Thread.sleep(100);
          }

          if (lightMode) {
            // Light up Home button
            byte[] b = {
              byte(0xaf), byte(0x00), 
              byte(0xf0), byte(0x40), byte(0x40), 
              byte(0xf0), byte(0x00), byte(0x00), 
              byte(0xf0), byte(0x00), byte(0x00), 
              byte(0xf0), byte(0x0f), byte(0x00), 
              byte(0xf0), byte(0x00), byte(0x00)
            };
            joycon_send_subcommand(0x1, Subcommand.SetHomeLight.getId(), b);
            Thread.sleep(100);

            // Light up Player button
            joycon_send_subcommand(0x1, Subcommand.SetInputReportMode.getId(), new byte[] {byte(0xa5)});
          }
        } 
        catch(InterruptedException e) {
          println(e);
        }
      }
    }
    );
    thread.start();
  }

  public void initialPosition() {
    posX = 0;
    posY = 0;
  }

  public void detach() {
    joycon_send_subcommand(0x01, Subcommand.SetInputReportMode.getId(), new byte[] { 0x3f });
    delay(100);
    joycon_send_subcommand(0x01, Subcommand.SetPlayerLights.getId(), new byte[] { 0x0 });
    delay(100);
    joycon_send_subcommand(0x01, Subcommand.SetHomeLight.getId(), new byte[] { 0x0 });
    delay(100);
    joycon_send_subcommand(0x01, Subcommand.EnableIMU.getId(), new byte[] { 0x0 });
    delay(100);
    joycon_send_subcommand(0x01, Subcommand.EnableVibration.getId(), new byte[] { 0x0 });
  }

  /////////////////////////////////////////////////////////////
  /* HID output methods */

  // {command, ++(global_count) & 0xF, 0x00, 0x01, 0x40, 0x40, 0x00, 0x01, 0x40, 0x40, subcommand, data[0], ... , data[data.length-1]}
  private void joycon_send_subcommand(int command, int subcommand, byte[] data) {
    if (devInfo==null) {
      println("connection error");
      return;
    }
    byte[] buf = new byte[0x400];
    byte[] b = {
      byte(command), 
      byte(++(global_count) & 0xF), // 1 & 0xF -> 0001 AND 1111 -> 0001 -> 1
      0x00, 0x01, 0x40, 0x40, 0x00, 0x01, 0x40, 0x40, 
      byte(subcommand)
    };

    Arrays.fill(int(buf), 0);
    System.arraycopy(b, 0, buf, 0, b.length);
    System.arraycopy(data, 0, buf, b.length, data.length);
    int len = b.length + data.length;
    dev.setOutputReport(byte(0), buf, len);
  }

  public void startVibration(int p1, int p2, float p3, int p4) {
    this.setRumble(p1, p2, p3, p4);
    this.sendRumble(this.rumble.getData());
  }

  private void sendRumble(byte[] buf) {
    if (devInfo==null) {
      println("connection error");
      return;
    }

    byte[] buf_ = new byte[report_len];
    buf_[0] = 0x10;
    buf_[1] = byte(global_count);
    global_count = (global_count==0xF) ? 0 : global_count+1;
    System.arraycopy(buf, 0, buf_, 2, buf.length);
    dev.setOutputReport(byte(0x0), buf_, report_len);
  }

  ///////////////////////////////////////////////////////////////
  /* set methods */
  private void setRumble(float _lowFreq, float _highFreq, float _amp, int _time) {
    //if (rumble.timed_rumble == false || rumble.t < 0) {
    rumble = new Rumble(_lowFreq, _highFreq, _amp, _time);
    println(rumble.getData());
    //}
  }

  /* get methods */
  public boolean getButtonDown(Button b) {
    return buttonsDown[(int)b.ordinal()];
  }

  public boolean getButton(Button b) {
    return buttons[(int)b.ordinal()];
  }

  public boolean getButtonUp(Button b) {
    return buttonsUp[(int)b.ordinal()];
  }

  public float[] getStick() {
    return stick;
  }

  public Vector3 getAccel() {
    return accG;
  }

  public Vector3 getGyro() {
    return gyrG;
  }

  //////////////////////////////////////////////////////////////
  /* process stick values methods */
  private int processButtonsAndStick(byte[] report_buf) {
    if (report_buf[0] == 0x00) return -1;

    stickRaw[0] = report_buf[6 + (isLeft ? 0 : 3)];
    stickRaw[1] = report_buf[7 + (isLeft ? 0 : 3)];
    stickRaw[2] = report_buf[8 + (isLeft ? 0 : 3)];

    char[] stick_precal = {0, 0};
    stick_precal[0] = (char)(stickRaw[0] | ((stickRaw[1] & 0xf) << 8));
    stick_precal[1] = (char)((stickRaw[1] >> 4) | (stickRaw[2] << 4));

    stick = centerSticks(stick_precal);
    for (int i = 0; i < buttons.length; ++i) {
      down_[i] = buttons[i];
    }
    buttons[(int)Button.DPAD_DOWN.ordinal()]  = (report_buf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x01 : 0x04)) != 0;
    buttons[(int)Button.DPAD_RIGHT.ordinal()] = (report_buf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x04 : 0x08)) != 0;
    buttons[(int)Button.DPAD_UP.ordinal()]    = (report_buf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x02 : 0x02)) != 0;
    buttons[(int)Button.DPAD_LEFT.ordinal()]  = (report_buf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x08 : 0x01)) != 0;
    buttons[(int)Button.HOME.ordinal()]       = ((report_buf[4] & 0x10) != 0);
    buttons[(int)Button.MINUS.ordinal()]      = ((report_buf[4] & 0x01) != 0);
    buttons[(int)Button.PLUS.ordinal()]       = ((report_buf[4] & 0x02) != 0);
    buttons[(int)Button.STICK.ordinal()]      = ((report_buf[4] & (isLeft ? 0x08 : 0x04)) != 0);
    buttons[(int)Button.SHOULDER_1.ordinal()] = (report_buf[3 + (isLeft ? 2 : 0)] & 0x40) != 0;
    buttons[(int)Button.SHOULDER_2.ordinal()] = (report_buf[3 + (isLeft ? 2 : 0)] & 0x80) != 0;
    buttons[(int)Button.SR.ordinal()]         = (report_buf[3 + (isLeft ? 2 : 0)] & 0x10) != 0;
    buttons[(int)Button.SL.ordinal()]         = (report_buf[3 + (isLeft ? 2 : 0)] & 0x20) != 0;

    boolean[] down_ = new boolean[13];
    for (int i = 0; i < buttons.length; ++i) {
      buttonsUp[i] = (down_[i] & !buttons[i]);
      buttonsDown[i] = (!down_[i] & buttons[i]);
    }
    return 0;
  }

  private float[] centerSticks(char[] vals) {
    if (devInfo==null) {
      println("connection error");
      return new float[]{-1};
    }

    float[] s = { 0, 0 };
    for (int i = 0; i < 2; ++i) {
      float diff = vals[i] - stickCal[2 + i];
      if (abs(diff) < deadzone) vals[i] = 0;
      else if (diff > 0) { // if axis is above center
        s[i] = diff / stickCal[i];
      } else {
        s[i] = diff / stickCal[4 + i];
      }
    }
    return s;
  }


  /////////////////////////////////////////////////////////////////
  /* process IMU values */
  private int processIMU(byte[] report_buf) {

    int dt = (report_buf[1] - timestamp);
    if (report_buf[1] < timestamp) dt += 0x100;

    for (int n=0; n<3; n++) {

      extractIMUValues(report_buf, n);

      float dt_sec = 0.005f * dt;
      sum[0] += gyrG.x * dt_sec;
      sum[1] += gyrG.y * dt_sec;
      sum[2] += gyrG.z * dt_sec;

      if (!isLeft) {
        accG.y *= -1;
        accG.z *= -1;
        gyrG.y *= -1;
        gyrG.z *= -1;
      }

      if (firstImuPacket) {
        iB = new Vector3(1, 0, 0);
        jB = new Vector3(0, 1, 0);
        kB = new Vector3(0, 0, 1);
        firstImuPacket = false;
      } else {

        Vector3 k = Vector3.Normalize(accG);
        kAcc = new Vector3(-k.x, -k.y, -k.z);

        Vector3 w_a = Vector3.Cross(kB, kAcc);
        Vector3 w_g = new Vector3(-gyrG.x * dt_sec, -gyrG.y * dt_sec, -gyrG.z * dt_sec);

        Vector3 d_theta = new Vector3(
          (filterweight * w_a.x + w_g.x) / (1f + filterweight), 
          (filterweight * w_a.y + w_g.y) / (1f + filterweight), 
          (filterweight * w_a.z + w_g.z) / (1f + filterweight)
          );
        Vector3 dxk = Vector3.Cross(d_theta, kB);
        kB = Vector3.Addition(kB, Vector3.Cross(d_theta, kB));
        iB = Vector3.Addition(iB, Vector3.Cross(d_theta, iB));
        jB = Vector3.Addition(jB, Vector3.Cross(d_theta, jB));
        //Correction, ensure new axes are orthogonal
        float err = Vector3.Dot(iB, jB) * 0.5f;
        Vector3 tmp = Vector3.Normalize(
          new Vector3(iB.x - err * jB.x, iB.y - err * jB.y, iB.z - err * jB.z)
          );

        jB = Vector3.Normalize(
          new Vector3(jB.x - err * iB.x, jB.y - err * iB.y, jB.z - err * iB.z)
          );
        iB = tmp;
        kB = Vector3.Cross(iB, jB);
      }

      dt = 1;
    }
    timestamp = report_buf[1] + 2;

    return 0;
  }

  private void extractIMUValues(byte[] report_buf, int n) {
    gyrR[0] = (short)(report_buf[19 + n * 12] | ((report_buf[20 + n * 12] << 8) & 0xff00));
    gyrR[1] = (short)(report_buf[21 + n * 12] | ((report_buf[22 + n * 12] << 8) & 0xff00));
    gyrR[2] = (short)(report_buf[23 + n * 12] | ((report_buf[24 + n * 12] << 8) & 0xff00));
    accR[0] = (short)(report_buf[13 + n * 12] | ((report_buf[14 + n * 12] << 8) & 0xff00));
    accR[1] = (short)(report_buf[15 + n * 12] | ((report_buf[16 + n * 12] << 8) & 0xff00));
    accR[2] = (short)(report_buf[17 + n * 12] | ((report_buf[18 + n * 12] << 8) & 0xff00));

    preAccG.x = accG.x;
    preGyrG.x = gyrG.x;
    accG.x = float(accR[0]) * 0.00025f;
    gyrG.x = (gyrR[0] - gyrNeutral[0]) * 0.00122187695f;
    if (abs(accG.x) > abs(max[0])) max[0] = accG.x;

    preAccG.y = accG.y;
    preGyrG.y = gyrG.y;
    accG.y = accR[1] * 0.00025f;
    gyrG.y = (gyrR[1] - gyrNeutral[1]) * 0.00122187695f;
    if (abs(accG.y) > abs(max[1])) max[1] = accG.y;

    preAccG.z = accG.z;
    preGyrG.z = gyrG.z;
    accG.z = accR[2] * 0.00025f;
    gyrG.z = (gyrR[2] - gyrNeutral[2]) * 0.00122187695f;
    if (abs(accG.z) > abs(max[2])) max[2] = accG.z;
  }

  //  private void dump_calibration_data() {
  //    byte[] buf_ = ReadSPI(0x80, (isLeft ? (byte)0x12 : (byte)0x1d), 9); // get user calibration data if possible
  //    bool found = false;
  //    for (int i = 0; i < 9; ++i)
  //    {
  //      if (buf_[i] != 0xff)
  //      {
  //        Debug.Log("Using user stick calibration data.");
  //        found = true;
  //        break;
  //      }
  //    }
  //    if (!found) {
  //      Debug.Log("Using factory stick calibration data.");
  //      buf_ = ReadSPI(0x60, (isLeft ? (byte)0x3d : (byte)0x46), 9); // get user calibration data if possible
  //    }
  //    stickCal[isLeft ? 0 : 2] = (UInt16)((buf_[1] << 8) & 0xF00 | buf_[0]); // X Axis Max above center
  //    stickCal[isLeft ? 1 : 3] = (UInt16)((buf_[2] << 4) | (buf_[1] >> 4));  // Y Axis Max above center
  //    stickCal[isLeft ? 2 : 4] = (UInt16)((buf_[4] << 8) & 0xF00 | buf_[3]); // X Axis Center
  //    stickCal[isLeft ? 3 : 5] = (UInt16)((buf_[5] << 4) | (buf_[4] >> 4));  // Y Axis Center
  //    stickCal[isLeft ? 4 : 0] = (UInt16)((buf_[7] << 8) & 0xF00 | buf_[6]); // X Axis Min below center
  //    stickCal[isLeft ? 5 : 1] = (UInt16)((buf_[8] << 4) | (buf_[7] >> 4));  // Y Axis Min below center


  //    buf_ = ReadSPI(0x60, (isLeft ? (byte)0x86 : (byte)0x98), 16);
  //    deadzone = (UInt16)((buf_[4] << 8) & 0xF00 | buf_[3]);

  //    buf_ = ReadSPI(0x80, 0x34, 10);
  //    gyrNeutral[0] = (Int16)(buf_[0] | ((buf_[1] << 8) & 0xff00));
  //    gyrNeutral[1] = (Int16)(buf_[2] | ((buf_[3] << 8) & 0xff00));
  //    gyrNeutral[2] = (Int16)(buf_[4] | ((buf_[5] << 8) & 0xff00));


  //    // This is an extremely messy way of checking to see whether there is user stick calibration data present, but I've seen conflicting user calibration data on blank Joy-Cons. Worth another look eventually.
  //    if (gyrNeutral[0] + gyrNeutral[1] + gyrNeutral[2] == -3 || Math.Abs(gyrNeutral[0]) > 100 || Math.Abs(gyrNeutral[1]) > 100 || Math.Abs(gyrNeutral[2]) > 100){
  //      buf_ = ReadSPI(0x60, 0x29, 10);
  //      gyrNeutral[0] = (Int16)(buf_[3] | ((buf_[4] << 8) & 0xff00));
  //      gyrNeutral[1] = (Int16)(buf_[5] | ((buf_[6] << 8) & 0xff00));
  //      gyrNeutral[2] = (Int16)(buf_[7] | ((buf_[8] << 8) & 0xff00));

  //    }
  //  }

  private byte[] readSPI(byte _addr1, byte _addr2, int _len, boolean print) {
    byte[] buf = { _addr2, _addr1, 0x00, 0x00, (byte)_len };
    byte[] read_buf = new byte[_len];
    byte[] buf_ = new byte[_len + 20];

    for (int i = 0; i < 100; i++) {
      joycon_send_subcommand(0x01, 0x10, buf);
      if (buf_[15] == _addr2 && buf_[16] == _addr1) {
        break;
      }
    }
    System.arraycopy(buf_, 20, read_buf, 0, _len);
    return read_buf;
  }

  ////////////////////////////////////////////////////////////////
  // inner class Rumble
  private class Rumble {
    private float h_f, amp, l_f;
    public float t;
    public boolean timed_rumble;

    Rumble(float _lowFreq, float _highFreq, float _amplitude, int _time) {
      l_f = _lowFreq;
      h_f = _highFreq;
      amp = _amplitude;
      timed_rumble = false;
      t = 0;
      if (_time != 0) {
        t = _time / 1000f;
        timed_rumble = true;
      }
    }

    private float clamp(float x, float min, float max) {
      if (x < min) return min;
      if (x > max) return max;
      return x;
    }

    private float log2 (float _f) {
      return (float)log(_f)/log(2);
    }

    public byte[] getData() {
      byte[] rumble_data = new byte[8];
      if (amp == 0.0f) {
        rumble_data[0] = 0x0;
        rumble_data[1] = 0x1;
        rumble_data[2] = 0x40;
        rumble_data[3] = 0x40;
      } else {
        l_f = clamp(l_f, 40.875885f, 626.286133f);
        amp = clamp(amp, 0.0f, 1.0f);
        h_f = clamp(h_f, 81.75177f, 1252.572266f);
        char hf = (char)((round(32f * log2(h_f * 0.1f)) - 0x60) * 4);
        byte lf = (byte)(round(32f * log2(l_f * 0.1f)) - 0x40);
        byte hf_amp;
        if (amp == 0) hf_amp = 0;
        else if (amp < 0.117) hf_amp = (byte)(((log2(amp * 1000) * 32) - 0x60) / (5 - pow(amp, 2)) - 1);
        else if (amp < 0.23) hf_amp = (byte)(((log2(amp * 1000) * 32) - 0x60) - 0x5c);
        else hf_amp = (byte)((((log2(amp * 1000) * 32) - 0x60) * 2) - 0xf6);

        char lf_amp = (char)(round(hf_amp) * .5);
        byte parity = (byte)(lf_amp % 2);
        if (parity > 0) {
          --lf_amp;
        }

        lf_amp = (char)(lf_amp >> 1);
        lf_amp += 0x40;
        if (parity > 0) lf_amp |= 0x8000;
        rumble_data = new byte[8];
        rumble_data[0] = (byte)(hf & 0xff);
        rumble_data[1] = (byte)((hf >> 8) & 0xff);
        rumble_data[2] = lf;
        rumble_data[1] += hf_amp;
        rumble_data[2] += (byte)((lf_amp >> 8) & 0xff);
        rumble_data[3] += (byte)(lf_amp & 0xff);
      }
      for (int i = 0; i < 4; ++i) {
        rumble_data[4 + i] = rumble_data[i];
      }
      //Debug.Log(string.Format("Encoded hex freq: {0:X2}", encoded_hex_freq));
      //Debug.Log(string.Format("lf_amp: {0:X4}", lf_amp));
      //Debug.Log(string.Format("hf_amp: {0:X2}", hf_amp));
      //Debug.Log(string.Format("l_f: {0:F}", l_f));
      //Debug.Log(string.Format("hf: {0:X4}", hf));
      //Debug.Log(string.Format("lf: {0:X2}", lf));
      return rumble_data;
    }
  }
}