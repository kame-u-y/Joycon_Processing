import purejavahidapi.*;
import purejavahidapi.HidDevice;
import java.util.List;
import java.util.Arrays;

public class Joycon {

  private class Stick {
    private float X, Y;
    private Vector2 max, center, min;

    public float[] getValues() {
      return new float[]{this.X, this.Y};
    }

    public Stick() {
      this.max = new Vector2(0, 0);
      this.center = new Vector2(0, 0);
      this.min = new Vector2(0, 0);
    }

    public void process(byte[] reportBuf) {
      this.unmarshalBinary(reportBuf);
      this.calibration();
    }

    private void unmarshalBinary(byte[] reportBuf) {
      if (reportBuf[0] == 0x00) return;

      short[] r = {0, 0, 0}; // Stick Raw Data
      r[0] = reportBuf[6 + (isLeft ? 0 : 3)];
      r[1] = reportBuf[7 + (isLeft ? 0 : 3)];
      r[2] = reportBuf[8 + (isLeft ? 0 : 3)];

      this.X = (char) ( r[0] | (r[1] & 0xf) << 8 );
      this.Y = (char) ( r[1] >> 4 | r[2] << 4 );
    }

    private void calibration() {
      float diff = this.X - this.center.X;
      if (abs(diff) < 0xae) {
        diff = 0.0;
      }
      this.X = (diff > 0) ? diff / this.max.X : diff / this.min.X;
      diff = this.Y - this.center.Y;
      this.Y = (diff > 0) ? diff / this.max.Y : diff / this.min.Y;
    }
  }

  private class Button {
    private boolean[] buttons = new boolean[13];
    
    public boolean[] getButtons() {
      return buttons;
    }
    
    public int process(byte[] reportBuf) {
      if (reportBuf[0] == 0x00) return -1;

      buttons[(int)ButtonEnum.DPAD_DOWN.ordinal()]  = (reportBuf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x01 : 0x04)) != 0;
      buttons[(int)ButtonEnum.DPAD_RIGHT.ordinal()] = (reportBuf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x04 : 0x08)) != 0;
      buttons[(int)ButtonEnum.DPAD_UP.ordinal()]    = (reportBuf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x02 : 0x02)) != 0;
      buttons[(int)ButtonEnum.DPAD_LEFT.ordinal()]  = (reportBuf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x08 : 0x01)) != 0;
      buttons[(int)ButtonEnum.HOME.ordinal()]       = ((reportBuf[4] & 0x10) != 0);
      buttons[(int)ButtonEnum.MINUS.ordinal()]      = ((reportBuf[4] & 0x01) != 0);
      buttons[(int)ButtonEnum.PLUS.ordinal()]       = ((reportBuf[4] & 0x02) != 0);
      buttons[(int)ButtonEnum.STICK.ordinal()]      = ((reportBuf[4] & (isLeft ? 0x08 : 0x04)) != 0);
      buttons[(int)ButtonEnum.SHOULDER_1.ordinal()] = (reportBuf[3 + (isLeft ? 2 : 0)] & 0x40) != 0;
      buttons[(int)ButtonEnum.SHOULDER_2.ordinal()] = (reportBuf[3 + (isLeft ? 2 : 0)] & 0x80) != 0;
      buttons[(int)ButtonEnum.SR.ordinal()]         = (reportBuf[3 + (isLeft ? 2 : 0)] & 0x10) != 0;
      buttons[(int)ButtonEnum.SL.ordinal()]         = (reportBuf[3 + (isLeft ? 2 : 0)] & 0x20) != 0;

      return 0;
    }
  }

  private Stick stick = new Stick();
  private Button button = new Button();
 

  private HidDevice     device;
  private HidDeviceInfo deviceInfo;

//  private boolean[] buttonsDown = new boolean[13];
//  private boolean[] buttonsUp   = new boolean[13];
  private boolean[] buttons      = new boolean[13];

  //private float[] stick = {0, 0};
  //private char[]  stickCal = { 0, 0, 0, 0, 0, 0 };
  //private char deadzone;

  private short[] accR     = {0, 0, 0};
  private Vector3 accG     = new Vector3(0, 0, 0);
  private Vector3 preAccG = new Vector3(0, 0, 0);

  private short[] gyrR       = {0, 0, 0};
  private short[] gyrNeutral = {0, 0, 0};
  private Vector3 gyrG       = new Vector3(0, 0, 0);
  private Vector3 preGyrG    = new Vector3(0, 0, 0);

  private float[] max = {0, 0, 0};
  private float[] sum = {0, 0, 0};

  public Vector3 iB, jB, kB, kAcc;

  private int global_count = 0;
  private boolean firstImuPacket = true;
  private float filterweight = 0.5f;
  private int timestamp = 0;
  private final int report_len = 49;
  private final boolean isLeft;
  private float posX, posY;
  private float vx, vy;
  private int t;



  ////////////////////////////////////////////////////////////////
  /* initialize methods */
  private void connectDevice(int _id) { 
    List<HidDeviceInfo> deviceList = PureJavaHidApi.enumerateDevices();

    for (HidDeviceInfo info : deviceList) {
      if ( info.getVendorId() != JoyconConstants.VENDOR_ID ) continue;
      if ( info.getProductId() != _id ) continue;

      this.deviceInfo = info;
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

    if (deviceInfo == null) {
      println("Connection Failed");
      return;
    }

    try {
      device = PureJavaHidApi.openDevice(deviceInfo);
      println("Connection Successful");
    }
    catch(IOException e) {
      println(e);
    }
  }

  private void setRemovalListener() {
    if (deviceInfo==null) {
      println("connection error");
      return;
    }
    device.setDeviceRemovalListener(new DeviceRemovalListener() {
      @Override
        public void onDeviceRemoval(HidDevice source) {
        System.out.println("device removed");
      }
    }
    );
  }

  private void setReportListener() {
    if (deviceInfo==null) {
      println("connection error");
      return;
    }
    device.setInputReportListener(new InputReportListener() {
      @Override
        public void onInputReport(HidDevice source, byte id, byte[] data, int len) {
        //System.out.printf("onInputReport: id %d len %d data ", id, len);
        //for (int i = 0; i < len; i++) {
        //  if (i==3) System.out.print("Button: ");
        //  if (i==6) System.out.print("LeftStick: ");
        //  if (i==9) System.out.print("RightStick: ");
        //  if (i==12) System.out.print("Vibrator: ");
        //  if (i==13) System.out.print("ACKByte: ");
        //  if (i==14) System.out.print("SubcmdID: ");
        //  if (i==15) System.out.print("ReplyData: ");
        //  System.out.printf("%02x ", data[i]);
        //}
        //System.out.println();

        processIMU(data);
        //processStick(data);
        stick.process(data);
        //processButton(data);
        button.process(data);

        posX = - ( (1/2) * (gyrG.z) + (gyrG.z) ) + posX;
        posY = (1/2) * (gyrG.y) + (gyrG.y) + posY;
        //vx   = accG.z * t + vx;
        //vy   = accG.y * t + vy;
      }
    }
    );
  }

  private void initializeMode() {
    if (deviceInfo==null) {
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

          sendSubcommand(0x1, Subcommand.EnableIMU.getId(), new byte[] {0x01});
          Thread.sleep(100);
          sendSubcommand(0x1, Subcommand.SetInputReportMode.getId(), new byte[] {0x30});
          Thread.sleep(100);
          if (irMode) {
            // I can't do it.
            Thread.sleep(100);
          }
          if (vibMode) {
            sendSubcommand(0x1, Subcommand.EnableVibration.getId(), new byte[] {0x01});
            Thread.sleep(100);
          }
          if (lightMode) {            
            byte[] b = {
              byte(0xaf), byte(0x00), 
              byte(0xf0), byte(0x40), byte(0x40), 
              byte(0xf0), byte(0x00), byte(0x00), 
              byte(0xf0), byte(0x00), byte(0x00), 
              byte(0xf0), byte(0x0f), byte(0x00), 
              byte(0xf0), byte(0x00), byte(0x00)
            };
            sendSubcommand(0x1, Subcommand.SetHomeLight.getId(), b);
            Thread.sleep(100);
            sendSubcommand(0x1, Subcommand.SetPlayerLights.getId(), new byte[] {byte(0xa5)});
            Thread.sleep(100);
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

  public void disconnectDevice() {
    sendSubcommand(0x01, Subcommand.SetInputReportMode.getId(), new byte[] { 0x3f });
    delay(100);
    sendSubcommand(0x01, Subcommand.SetPlayerLights.getId(), new byte[] { 0x0 });
    delay(100);
    sendSubcommand(0x01, Subcommand.SetHomeLight.getId(), new byte[] { 0x0 });
    delay(100);
    sendSubcommand(0x01, Subcommand.EnableIMU.getId(), new byte[] { 0x0 });
    delay(100);
    sendSubcommand(0x01, Subcommand.EnableVibration.getId(), new byte[] { 0x0 });
  }

  public Joycon(int _id) {
    this.isLeft = _id==JoyconConstants.LEFT_ID;
    connectDevice(_id);
    setReportListener();
    setRemovalListener();
    initializeMode();
    this.posX = 0;
    this.posY = 0;
    this.vx = 0;
    this.vy = 0;
    this.t  = 0;
  }


  /////////////////////////////////////////////////////////////
  /* HID output methods */

  // {command, ++(global_count) & 0xF, 0x00, 0x01, 0x40, 0x40, 0x00, 0x01, 0x40, 0x40, subcommand, data[0], ... , data[data.length-1]}
  private void sendSubcommand(int command, int subcommand, byte[] data) {
    if (deviceInfo==null) {
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
    device.setOutputReport(byte(0), buf, len);
  }

  // read by startVibration()
  private void sendRumble(byte[] buf) {
    if (deviceInfo==null) {
      println("connection error");
      return;
    }

    byte[] buf_ = new byte[report_len];
    buf_[0] = 0x10;
    buf_[1] = byte(global_count);
    global_count = (global_count==0xF) ? 0 : global_count+1;
    System.arraycopy(buf, 0, buf_, 2, buf.length);
    device.setOutputReport(byte(0x0), buf_, report_len);
  }

  public void startVibration(float _lowFreq, float _highFreq, float _amp, int _time) {
    Rumble rumble = new Rumble(_lowFreq, _highFreq, _amp, _time);
    this.sendRumble(rumble.getData());
  }
  ///////////////////////////////////////////////////////////////
  /* set methods */

  public void initializePosition() {
    this.posX = 0;
    this.posY = 0;
  }

  /* get methods */
  public boolean getButton(ButtonEnum b) {
    return button.getButtons() [(int)b.ordinal()];
  }

  public float[] getStick() {
    return stick.getValues();
  }

  public Vector3 getAccel() {
    return accG;
  }

  public Vector3 getGyro() {
    return gyrG;
  }

  //////////////////////////////////////////////////////////////
  /* process stick values methods */
  //private int processStick(byte[] reportBuf) {
  //  if (reportBuf[0] == 0x00) return -1;

  //  short[] r = {0, 0, 0}; // Stick Raw Data
  //  r[0] = reportBuf[6 + (isLeft ? 0 : 3)];
  //  r[1] = reportBuf[7 + (isLeft ? 0 : 3)];
  //  r[2] = reportBuf[8 + (isLeft ? 0 : 3)];

  //  char X = (char) ( r[0] | (r[1] & 0xf) << 8 );
  //  char Y = (char) ( r[1] >> 4 | r[2] << 4 );
  //  char[] stick_precal = {X, Y};

  //  stick = centerSticks(stick_precal);
  //  return 0;
  //}

  private int processButton(byte[] reportBuf) {
    if (reportBuf[0] == 0x00) return -1;

    buttons[(int)ButtonEnum.DPAD_DOWN.ordinal()]  = (reportBuf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x01 : 0x04)) != 0;
    buttons[(int)ButtonEnum.DPAD_RIGHT.ordinal()] = (reportBuf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x04 : 0x08)) != 0;
    buttons[(int)ButtonEnum.DPAD_UP.ordinal()]    = (reportBuf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x02 : 0x02)) != 0;
    buttons[(int)ButtonEnum.DPAD_LEFT.ordinal()]  = (reportBuf[3 + (isLeft ? 2 : 0)] & (isLeft ? 0x08 : 0x01)) != 0;
    buttons[(int)ButtonEnum.HOME.ordinal()]       = ((reportBuf[4] & 0x10) != 0);
    buttons[(int)ButtonEnum.MINUS.ordinal()]      = ((reportBuf[4] & 0x01) != 0);
    buttons[(int)ButtonEnum.PLUS.ordinal()]       = ((reportBuf[4] & 0x02) != 0);
    buttons[(int)ButtonEnum.STICK.ordinal()]      = ((reportBuf[4] & (isLeft ? 0x08 : 0x04)) != 0);
    buttons[(int)ButtonEnum.SHOULDER_1.ordinal()] = (reportBuf[3 + (isLeft ? 2 : 0)] & 0x40) != 0;
    buttons[(int)ButtonEnum.SHOULDER_2.ordinal()] = (reportBuf[3 + (isLeft ? 2 : 0)] & 0x80) != 0;
    buttons[(int)ButtonEnum.SR.ordinal()]         = (reportBuf[3 + (isLeft ? 2 : 0)] & 0x10) != 0;
    buttons[(int)ButtonEnum.SL.ordinal()]         = (reportBuf[3 + (isLeft ? 2 : 0)] & 0x20) != 0;

    return 0;
  }

  //  private float[] centerSticks(char[] vals) {
  //    if (deviceInfo==null) {
  //      println("connection error");
  //      return new float[]{-1};
  //    }

  //    float[] s = { 0, 0 };
  //    for (int i = 0; i < 2; ++i) {
  //      float diff = vals[i] - stickCal[2 + i];
  //      if (abs(diff) < deadzone) vals[i] = 0;
  //      else if (diff > 0) { // if axis is above center
  //        s[i] = diff / stickCal[i];
  //      } else {
  //        s[i] = diff / stickCal[4 + i];
  //      }
  //    }
  //    return s;
  //  }


  /////////////////////////////////////////////////////////////////
  /* process IMU values */


  // read by processIMU()
  private void extractIMUValues(byte[] reportBuf, int n) {
    gyrR[0] = (short)(reportBuf[19 + n * 12] | ((reportBuf[20 + n * 12] << 8) & 0xff00));
    gyrR[1] = (short)(reportBuf[21 + n * 12] | ((reportBuf[22 + n * 12] << 8) & 0xff00));
    gyrR[2] = (short)(reportBuf[23 + n * 12] | ((reportBuf[24 + n * 12] << 8) & 0xff00));
    accR[0] = (short)(reportBuf[13 + n * 12] | ((reportBuf[14 + n * 12] << 8) & 0xff00));
    accR[1] = (short)(reportBuf[15 + n * 12] | ((reportBuf[16 + n * 12] << 8) & 0xff00));
    accR[2] = (short)(reportBuf[17 + n * 12] | ((reportBuf[18 + n * 12] << 8) & 0xff00));

    preAccG.x = accG.x;
    preGyrG.x = gyrG.x;
    accG.x = accR[0] * 0.00025f;
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

  private int processIMU(byte[] reportBuf) {
    int dt = (reportBuf[1] - timestamp);
    if (reportBuf[1] < timestamp) dt += 0x100;

    for (int n=0; n<3; n++) {
      extractIMUValues(reportBuf, n);

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
        Vector3 k = Vector3.normalize(accG);
        kAcc = new Vector3(-k.x, -k.y, -k.z);

        Vector3 w_a = Vector3.cross(kB, kAcc);
        Vector3 w_g = new Vector3(-gyrG.x * dt_sec, -gyrG.y * dt_sec, -gyrG.z * dt_sec);

        Vector3 d_theta = new Vector3(
          (filterweight * w_a.x + w_g.x) / (1f + filterweight), 
          (filterweight * w_a.y + w_g.y) / (1f + filterweight), 
          (filterweight * w_a.z + w_g.z) / (1f + filterweight)
          );
        Vector3 dxk = Vector3.cross(d_theta, kB);
        kB = Vector3.addition(kB, Vector3.cross(d_theta, kB));
        iB = Vector3.addition(iB, Vector3.cross(d_theta, iB));
        jB = Vector3.addition(jB, Vector3.cross(d_theta, jB));
        //Correction, ensure new axes are orthogonal
        float err = Vector3.dot(iB, jB) * 0.5f;
        Vector3 tmp = Vector3.normalize( new Vector3(
          iB.x - err * jB.x, 
          iB.y - err * jB.y, 
          iB.z - err * jB.z
          ));

        jB = Vector3.normalize( new Vector3(
          jB.x - err * iB.x, 
          jB.y - err * iB.y, 
          jB.z - err * iB.z
          ));
        iB = tmp;
        kB = Vector3.cross(iB, jB);
      }

      dt = 1;
    }
    timestamp = reportBuf[1] + 2;

    return 0;
  }

  /*
   private void dump_calibration_data() {
   byte[] buf_ = ReadSPI(0x80, (isLeft ? (byte)0x12 : (byte)0x1d), 9); // get user calibration data if possible
   bool found = false;
   for (int i = 0; i < 9; ++i)
   {
   if (buf_[i] != 0xff)
   {
   Debug.Log("Using user stick calibration data.");
   found = true;
   break;
   }
   }
   if (!found) {
   Debug.Log("Using factory stick calibration data.");
   buf_ = ReadSPI(0x60, (isLeft ? (byte)0x3d : (byte)0x46), 9); // get user calibration data if possible
   }
   stickCal[isLeft ? 0 : 2] = (UInt16)((buf_[1] << 8) & 0xF00 | buf_[0]); // X Axis Max above center
   stickCal[isLeft ? 1 : 3] = (UInt16)((buf_[2] << 4) | (buf_[1] >> 4));  // Y Axis Max above center
   stickCal[isLeft ? 2 : 4] = (UInt16)((buf_[4] << 8) & 0xF00 | buf_[3]); // X Axis Center
   stickCal[isLeft ? 3 : 5] = (UInt16)((buf_[5] << 4) | (buf_[4] >> 4));  // Y Axis Center
   stickCal[isLeft ? 4 : 0] = (UInt16)((buf_[7] << 8) & 0xF00 | buf_[6]); // X Axis Min below center
   stickCal[isLeft ? 5 : 1] = (UInt16)((buf_[8] << 4) | (buf_[7] >> 4));  // Y Axis Min below center
   
   
   buf_ = ReadSPI(0x60, (isLeft ? (byte)0x86 : (byte)0x98), 16);
   deadzone = (UInt16)((buf_[4] << 8) & 0xF00 | buf_[3]);
   
   buf_ = ReadSPI(0x80, 0x34, 10);
   gyrNeutral[0] = (Int16)(buf_[0] | ((buf_[1] << 8) & 0xff00));
   gyrNeutral[1] = (Int16)(buf_[2] | ((buf_[3] << 8) & 0xff00));
   gyrNeutral[2] = (Int16)(buf_[4] | ((buf_[5] << 8) & 0xff00));
   
   
   // This is an extremely messy way of checking to see whether there is user stick calibration data present, but I've seen conflicting user calibration data on blank Joy-Cons. Worth another look eventually.
   if (gyrNeutral[0] + gyrNeutral[1] + gyrNeutral[2] == -3 || Math.Abs(gyrNeutral[0]) > 100 || Math.Abs(gyrNeutral[1]) > 100 || Math.Abs(gyrNeutral[2]) > 100){
   buf_ = ReadSPI(0x60, 0x29, 10);
   gyrNeutral[0] = (Int16)(buf_[3] | ((buf_[4] << 8) & 0xff00));
   gyrNeutral[1] = (Int16)(buf_[5] | ((buf_[6] << 8) & 0xff00));
   gyrNeutral[2] = (Int16)(buf_[7] | ((buf_[8] << 8) & 0xff00));
   
   }
   }
   */

  public byte[] spi() {
    return readSPI((byte)0x80, (isLeft ? (byte)0x12 : (byte)0x1d), 9, false);
  }

  private byte[] readSPI(byte _addr1, byte _addr2, int _len, boolean print) {
    byte[] buf = { _addr2, _addr1, 0x00, 0x00, (byte)_len };
    byte[] readBuf = new byte[_len];
    byte[] buf_ = new byte[_len + 20];

    for (int i = 0; i < 100; i++) {
      sendSubcommand(0x01, 0x10, buf);
      if (buf_[15] == _addr2 && buf_[16] == _addr1) {
        break;
      }
    }
    System.arraycopy(buf_, 20, readBuf, 0, _len);
    return readBuf;
  }



  ////////////////////////////////////////////////////////////////
  // inner class Rumble
  private class Rumble {
    private float highFreq, amplitude, lowFreq;
    public float t;
    public boolean timedRumble;

    Rumble(float _lowFreq, float _highFreq, float _amplitude, int _time) {
      lowFreq = _lowFreq;
      highFreq = _highFreq;
      amplitude = _amplitude;
      timedRumble = false;
      t = 0;
      if (_time != 0) {
        t = _time / 1000f;
        timedRumble = true;
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
      byte[] rumbleData = new byte[8];
      if (amplitude == 0.0f) {
        rumbleData[0] = 0x0;
        rumbleData[1] = 0x1;
        rumbleData[2] = 0x40;
        rumbleData[3] = 0x40;
      } else {
        lowFreq   = clamp(lowFreq, 40.875885f, 626.286133f);
        amplitude = clamp(amplitude, 0.0f, 1.0f);
        highFreq  = clamp(highFreq, 81.75177f, 1252.572266f);
        char hf = (char)((round(32f * log2(this.highFreq * 0.1f)) - 0x60) * 4);
        byte lf = (byte)(round(32f * log2(this.lowFreq * 0.1f)) - 0x40);
        byte hfAmp;
        if (amplitude == 0) {
          hfAmp = 0;
        } else if (amplitude < 0.117) {
          hfAmp = (byte)(((log2(amplitude * 1000) * 32) - 0x60) / (5 - pow(amplitude, 2)) - 1);
        } else if (amplitude < 0.23) { 
          hfAmp = (byte)(((log2(amplitude * 1000) * 32) - 0x60) - 0x5c);
        } else {
          hfAmp = (byte)((((log2(amplitude * 1000) * 32) - 0x60) * 2) - 0xf6);
        }

        char lfAmp = (char)(round(hfAmp) * .5);
        byte parity = (byte)(lfAmp % 2);
        if (parity > 0) {
          --lfAmp;
        }

        lfAmp = (char)(lfAmp >> 1);
        lfAmp += 0x40;
        if (parity > 0) lfAmp |= 0x8000;
        rumbleData = new byte[8];
        rumbleData[0] = (byte)(hf & 0xff);
        rumbleData[1] = (byte)((hf >> 8) & 0xff);
        rumbleData[2] = lf;
        rumbleData[1] += hfAmp;
        rumbleData[2] += (byte)((lfAmp >> 8) & 0xff);
        rumbleData[3] += (byte)(lfAmp & 0xff);
      }
      for (int i = 0; i < 4; ++i) {
        rumbleData[4 + i] = rumbleData[i];
      }
      //Debug.Log(string.Format("Encoded hex freq: {0:X2}", encoded_hex_freq));
      //Debug.Log(string.Format("lfAmp: {0:X4}", lfAmp));
      //Debug.Log(string.Format("hfAmp: {0:X2}", hfAmp));
      //Debug.Log(string.Format("lf: {0:F}", lf));
      //Debug.Log(string.Format("hf: {0:X4}", hf));
      //Debug.Log(string.Format("lf: {0:X2}", lf));
      return rumbleData;
    }
  }
}