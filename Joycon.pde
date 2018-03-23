import purejavahidapi.*;
import purejavahidapi.HidDevice;
import java.util.List;
import java.util.Arrays;


public class Joycon {
  private boolean ir_mode = true;


  HidDevice     dev;
  HidDeviceInfo devInfo;
  int global_count = 0;

  // inner class "Rumble" is defined the last of class "Joycon"
  private Rumble rumble_obj;

  private boolean[] buttons_down = new boolean[13];
  private boolean[] buttons_up   = new boolean[13];
  private boolean[] buttons      = new boolean[13];
  private boolean[] down_        = new boolean[13];

  private float[] stick = {0, 0};
  private short[] stick_raw = {0, 0, 0};
  private char[] stick_cal = { 0, 0, 0, 0, 0, 0 };
  private char deadzone;

  private short[] acc_r = {0, 0, 0};
  private Vector3 acc_g = new Vector3(0, 0, 0);
  private Vector3 pre_acc_g = new Vector3(0, 0, 0);

  private short[] gyr_r = {0, 0, 0};
  private short[] gyr_neutral = {0, 0, 0};
  private Vector3 gyr_g = new Vector3(0, 0, 0);
  private Vector3 pre_gyr_g = new Vector3(0, 0, 0);

  float[] max = {0, 0, 0};
  float[] sum = {0, 0, 0};

  public Vector3 i_b, j_b, k_b, k_acc;

  private boolean first_imu_packet = true;
  private float filterweight = 0.5f;
  private int timestamp = 0;
  private int report_len = 49;
  private boolean isLeft;
  private float posX, posY;
  private float vx, vy;
  int t;

  Joycon() {
    connectDevice();
    setReportListener();
    setRemovalListener();
    changeMode();
    posX = 0;
    posY = 0;
    vx = 0;
    vy = 0;
    t  = 0;
    //t  = 1;
    rumble_obj = new Rumble(160, 320, 0, 0);
  }

  private void connectDevice() {
    List<HidDeviceInfo> devList = PureJavaHidApi.enumerateDevices();

    for (HidDeviceInfo info : devList) {
      if (info.getVendorId() != JoyconConstants.VENDOR_ID) continue;

      if (info.getProductId() == JoyconConstants.LEFT_ID) isLeft = true;
      else if (info.getProductId() == JoyconConstants.RIGHT_ID) isLeft = false;
      else return;

      devInfo = info;
      System.out.printf(
        "VID = 0x%04X PID = 0x%04X Manufacturer = %s Product = %s Path = %s\n", 
        info.getVendorId(), 
        info.getProductId(), 
        info.getManufacturerString(), 
        info.getProductString(), 
        info.getPath()
        );
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
    dev.setDeviceRemovalListener(new DeviceRemovalListener() {
      @Override
        public void onDeviceRemoval(HidDevice source) {
        System.out.println("device removed");
      }
    }
    );
  }

  private void setReportListener() {

    dev.setInputReportListener(new InputReportListener() {
      @Override
        public void onInputReport(HidDevice source, byte Id, byte[] data, int len) {
        System.out.printf("onInputReport: id %d len %d data ", Id, len);
        for (int i = 0; i < len; i++) System.out.printf("%02x ", data[i]);
        System.out.println();

        processIMU(data);

        processButtonsAndStick(data);

        posX = - ( (1/2) * (gyr_g.z) + (gyr_g.z) ) + posX;
        posY = (1/2) * (gyr_g.y) + (gyr_g.y) + posY;
        //vx   = acc_g.z * t + vx;
        //vy   = acc_g.y * t + vy;
      }
    }
    );
  }

  private void changeMode() {
    Thread thread = new Thread(new MultiThread() {
      @Override
        public void run() {
        try {
          //byte[] buf = new byte[0x400];
          //Arrays.fill(int(buf), 0);


          //Thread.sleep(100);

          //buf[0] = 0x01;
          //joycon_send_subcommand(0x1, 0x1, buf);

          //Thread.sleep(100);

          //buf[0] = 0x02;
          joycon_send_subcommand(0x1, 0x1, new byte[]{0x02});

          Thread.sleep(100);

          //// 0x01: Bluetooth manual pairing
          //buf[0] = 0x03;
          //joycon_send_subcommand(0x1, 0x1, buf);

          //Thread.sleep(100);

          //buf[0] = 0x0;
          //joycon_send_subcommand(0x1, 0x30, buf);

          //Thread.sleep(100);

          //Subcommand 0x40: Enable IMU (6-Axis sensor)
          joycon_send_subcommand(0x1, 0x40, new byte[] {0x01});

          //Thread.sleep(100);

          ////Standard full mode. Pushes current state @60Hz
          joycon_send_subcommand(0x1, 0x3, new byte[] {0x30});

          Thread.sleep(100);

          if (ir_mode) {
            //Subcommand 0x03: Set input report mode
            //Subcommand 0x21: Set MCU configuration
            //Subcommand 0x22: Set MCU state

            // NFC/IR mode. Pushes large packets @60Hz
            joycon_send_subcommand(0x1, 0x3, new byte[] {0x31});
            Thread.sleep(100);

            //Subcommand 0x22: Set MCU state 
            // (00:Suspend,01:Resume,02:Resume for update)
            joycon_send_subcommand(0x11, 0x22, new byte[] {0x01});
            Thread.sleep(100);

            // subcommand 0x11 send to MCU
            // if the command is x11, it polls the MCU State? Used with IR Camera or NFC?
            joycon_send_subcommand(0x11, 0x01, new byte[] {0x00});
            Thread.sleep(100);

            // subcommand 0x11 send to MCU 
            // 21 21 00 04 is for NFC
            joycon_send_subcommand(0x11, 0x21, new byte[] {0x21, 0x00, 0x04});
            Thread.sleep(100);
            
            // 21 21 00 05 for IR
            joycon_send_subcommand(0x11, 0x21, new byte[] {0x21, 0x00, 0x05});
            Thread.sleep(100);
            
            // no.5, continue sending subcommand 1 to report 0x11
            joycon_send_subcommand(0x11, 0x01, new byte[] {0x00});
            Thread.sleep(100);
            
            joycon_send_subcommand(0x11, 0x21, new byte[] {0x23, 0x01, 0x07, 0x0f, 0x00, 0x03, 0x00, 0x09});
            Thread.sleep(100);
            
            joycon_send_subcommand(0x11, 0x03, new byte[] {0x02});
            Thread.sleep(100);
            
            //joycon_send_subcommand(0x11, 0x02, new byte[] {0x04, 0x00, 0x00, 0x08});
            //Thread.sleep(100);
            
            joycon_send_subcommand(0x01, 0x21, new byte[] {0x23});
            Thread.sleep(100);
            
            joycon_send_subcommand(0x11, 0x03, new byte[] {0x00});
          }

          Thread.sleep(100);

          // subcommand 0x48: Enable vibration data (x00: Disable) (x01: Enable)
          //joycon_send_subcommand(0x1, 0x48, new byte[] {0x01});

//          Thread.sleep(100);

//          byte[] b = {
//            byte(0xaf), byte(0x00), 
//            byte(0xf0), byte(0x40), byte(0x40), 
//            byte(0xf0), byte(0x00), byte(0x00), 
//            byte(0xf0), byte(0x00), byte(0x00), 
//            byte(0xf0), byte(0x0f), byte(0x00), 
//            byte(0xf0), byte(0x00), byte(0x00)
//          };
//          joycon_send_subcommand(0x1, 0x38, b);

//          Thread.sleep(100);


//          joycon_send_subcommand(0x1, 0x30, new byte[] {byte(0xa5)});
        } 
        catch(InterruptedException e) {
          println(e);
        }
      }
    }
    );
    thread.start();
  }

  private void joycon_send_subcommand(int command, int subcommand, byte[] data) {
    int len = data.length;
    byte[] buf = new byte[0x400];
    Arrays.fill(int(buf), 0);
    byte[] rumble_base = {
      byte((++global_count) & 0xF), // 1 & 0xF -> 0001 AND 1111 -> 0001 -> 1
      0x00, 0x01, 0x40, 0x40, 0x00, 0x01, 0x40, 0x40
    };
    System.arraycopy(rumble_base, 0, buf, 0, rumble_base.length);
    buf[9] = byte(subcommand);
    if (data != null && len != 0) {
      System.arraycopy(data, 0, buf, 10, len);
    }
    joycon_send_command(command, buf, 10 + len);
  }

  private void joycon_send_command(int command, byte[] data, int len) {
    byte[] buf = new byte[0x400];
    Arrays.fill(int(buf), 0);

    buf[0] = byte(command);

    for (int i=0; i<len; i++) {
      buf[i+1] = data[i];
    }

    hid_exchange(buf, len + 1);
  }

  private void hid_exchange(byte[] buf, int len) {
    dev.setOutputReport(byte(0), buf, len);
  }

  public void initialPosition() {
    posX = 0;
    posY = 0;
  }

  public boolean getButtonDown(Button b) {
    return buttons_down[(int)b.ordinal()];
  }

  public boolean getButton(Button b) {
    return buttons[(int)b.ordinal()];
  }

  public boolean getButtonUp(Button b) {
    return buttons_up[(int)b.ordinal()];
  }

  public float[] getStick() {
    return stick;
  }

  public Vector3 getAccel() {
    return acc_g;
  }

  public Vector3 getGyro() {
    return gyr_g;
  }

  public void setRumble(float low_freq, float high_freq, float amp, int time) {
    //if (state <= Joycon.state_.ATTACHED) return;
    if (rumble_obj.timed_rumble == false || rumble_obj.t < 0) {
      rumble_obj = new Rumble(low_freq, high_freq, amp, time);
    }
  }

  public void sendRumble(byte[] buf) {
    byte[] buf_ = new byte[report_len];
    buf_[0] = 0x10;
    buf_[1] = byte(global_count);
    if (global_count == 0xf) global_count = 0;
    else ++global_count;
    for (int i=0; i<buf.length; i++) {
      buf_[i+2] = buf[i];
    }
    //PrintArray(buf_, DebugType.RUMBLE, format: 
    //  "Rumble data sent: {0:S}");
    dev.setOutputReport(byte(0x0), buf_, report_len);
  }

  private int processButtonsAndStick(byte[] report_buf) {
    if (report_buf[0] == 0x00) return -1;

    stick_raw[0] = report_buf[6 + (isLeft ? 0 : 3)];
    stick_raw[1] = report_buf[7 + (isLeft ? 0 : 3)];
    stick_raw[2] = report_buf[8 + (isLeft ? 0 : 3)];

    char[] stick_precal = {0, 0};
    stick_precal[0] = (char)(stick_raw[0] | ((stick_raw[1] & 0xf) << 8));
    stick_precal[1] = (char)((stick_raw[1] >> 4) | (stick_raw[2] << 4));
    //println(int(stick_precal[0]), int(stick_precal[1]));

    stick = centerSticks(stick_precal);
    //lock (buttons)
    //{
    //lock (down_)
    //{
    for (int i = 0; i < buttons.length; ++i)
    {
      down_[i] = buttons[i];
    }
    //}
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
    //lock (buttons_up)
    //{
    //  lock (buttons_down)
    //  {
    for (int i = 0; i < buttons.length; ++i) {
      buttons_up[i] = (down_[i] & !buttons[i]);
      buttons_down[i] = (!down_[i] & buttons[i]);
    }
    // }
    //}
    //}
    return 0;
  }

  private float[] centerSticks(char[] vals) {

    float[] s = { 0, 0 };
    for (int i = 0; i < 2; ++i) {
      float diff = vals[i] - stick_cal[2 + i];
      if (abs(diff) < deadzone) vals[i] = 0;
      else if (diff > 0) { // if axis is above center
        s[i] = diff / stick_cal[i];
      } else {
        s[i] = diff / stick_cal[4 + i];
      }
    }
    return s;
  }


  /////////////////////////////////////////////////////////////////
  /* Process IMU Values */

  private int processIMU(byte[] report_buf) {

    int dt = (report_buf[1] - timestamp);
    if (report_buf[1] < timestamp) dt += 0x100;

    for (int n=0; n<3; n++) {

      extractIMUValues(report_buf, n);

      float dt_sec = 0.005f * dt;
      sum[0] += gyr_g.x * dt_sec;
      sum[1] += gyr_g.y * dt_sec;
      sum[2] += gyr_g.z * dt_sec;

      if (!isLeft) {
        acc_g.y *= -1;
        acc_g.z *= -1;
        gyr_g.y *= -1;
        gyr_g.z *= -1;
      }

      if (first_imu_packet) {
        i_b = new Vector3(1, 0, 0);
        j_b = new Vector3(0, 1, 0);
        k_b = new Vector3(0, 0, 1);
        first_imu_packet = false;
      } else {

        Vector3 k = Vector3.Normalize(acc_g);
        k_acc = new Vector3(-k.x, -k.y, -k.z);

        Vector3 w_a = Vector3.Cross(k_b, k_acc);
        Vector3 w_g = new Vector3(-gyr_g.x * dt_sec, -gyr_g.y * dt_sec, -gyr_g.z * dt_sec);

        Vector3 d_theta = new Vector3(
          (filterweight * w_a.x + w_g.x) / (1f + filterweight), 
          (filterweight * w_a.y + w_g.y) / (1f + filterweight), 
          (filterweight * w_a.z + w_g.z) / (1f + filterweight)
          );
        Vector3 dxk = Vector3.Cross(d_theta, k_b);
        k_b = Vector3.Addition(k_b, Vector3.Cross(d_theta, k_b));
        i_b = Vector3.Addition(i_b, Vector3.Cross(d_theta, i_b));
        j_b = Vector3.Addition(j_b, Vector3.Cross(d_theta, j_b));
        //Correction, ensure new axes are orthogonal
        float err = Vector3.Dot(i_b, j_b) * 0.5f;
        Vector3 tmp = Vector3.Normalize(
          new Vector3(i_b.x - err * j_b.x, i_b.y - err * j_b.y, i_b.z - err * j_b.z)
          );

        j_b = Vector3.Normalize(
          new Vector3(j_b.x - err * i_b.x, j_b.y - err * i_b.y, j_b.z - err * i_b.z)
          );
        i_b = tmp;
        k_b = Vector3.Cross(i_b, j_b);
      }

      dt = 1;
    }
    timestamp = report_buf[1] + 2;

    return 0;
  }

  private void extractIMUValues(byte[] report_buf, int n) {
    gyr_r[0] = (short)(report_buf[19 + n * 12] | ((report_buf[20 + n * 12] << 8) & 0xff00));
    gyr_r[1] = (short)(report_buf[21 + n * 12] | ((report_buf[22 + n * 12] << 8) & 0xff00));
    gyr_r[2] = (short)(report_buf[23 + n * 12] | ((report_buf[24 + n * 12] << 8) & 0xff00));
    acc_r[0] = (short)(report_buf[13 + n * 12] | ((report_buf[14 + n * 12] << 8) & 0xff00));
    acc_r[1] = (short)(report_buf[15 + n * 12] | ((report_buf[16 + n * 12] << 8) & 0xff00));
    acc_r[2] = (short)(report_buf[17 + n * 12] | ((report_buf[18 + n * 12] << 8) & 0xff00));

    pre_acc_g.x = acc_g.x;
    pre_gyr_g.x = gyr_g.x;
    acc_g.x = float(acc_r[0]) * 0.00025f;
    gyr_g.x = (gyr_r[0] - gyr_neutral[0]) * 0.00122187695f;
    if (abs(acc_g.x) > abs(max[0])) max[0] = acc_g.x;

    pre_acc_g.y = acc_g.y;
    pre_gyr_g.y = gyr_g.y;
    acc_g.y = acc_r[1] * 0.00025f;
    gyr_g.y = (gyr_r[1] - gyr_neutral[1]) * 0.00122187695f;
    if (abs(acc_g.y) > abs(max[1])) max[1] = acc_g.y;

    pre_acc_g.z = acc_g.z;
    pre_gyr_g.z = gyr_g.z;
    acc_g.z = acc_r[2] * 0.00025f;
    gyr_g.z = (gyr_r[2] - gyr_neutral[2]) * 0.00122187695f;
    if (abs(acc_g.z) > abs(max[2])) max[2] = acc_g.z;
  }


  // inner class Rumble
  private class Rumble {
    private float h_f, amp, l_f;
    public float t;
    public boolean timed_rumble;

    public Rumble(float low_freq, float high_freq, float amplitude, int time) {
      h_f = high_freq;
      amp = amplitude;
      l_f = low_freq;
      //timed_rumble = false;
      t = 0;
      if (time != 0) {
        t = time / 1000f;
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