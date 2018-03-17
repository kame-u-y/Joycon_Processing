import purejavahidapi.*;
import purejavahidapi.HidDevice;
import java.util.List;
import java.util.Arrays;


class Joycon {

  HidDevice dev;
  HidDeviceInfo joyconInfo;
  byte reportId = 33;
  int global_count = 0;

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

  private float filterweight = 0.5f;


  private boolean first_imu_packet = true;

  private int timestamp = 0;

  boolean isLeft;

  float posX, posY;
  float vx, vy;
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
    t  = 1;
  }

  private void connectDevice() {
    List<HidDeviceInfo> devList = PureJavaHidApi.enumerateDevices();

    for (HidDeviceInfo info : devList) {
      if ( (info.getVendorId()==0x057E)) {
        if (info.getProductId()==0x2007) isLeft = false;
        else if (info.getProductId()==0x2006) isLeft = true;
        else return;

        joyconInfo = info;
        System.out.printf("VID = 0x%04X PID = 0x%04X Manufacturer = %s Product = %s Path = %s\n", //
          info.getVendorId(), //
          info.getProductId(), //
          info.getManufacturerString(), //
          info.getProductString(), //
          info.getPath());

        println("get new joycon info");
        break;
      }
    }

    try {
      dev = PureJavaHidApi.openDevice(joyconInfo);
      println("create joycon as a HidDevice");
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
        //System.out.printf("onInputReport: id %d len %d data ", Id, len);
        //for (int i = 0; i < len; i++) System.out.printf("%02x ", data[i]);
        //System.out.println();
        reportId = Id;

        processIMU(data);
        //println(gyr_g);
        //println(acc_g);
        posX = - ( (1/2) * (gyr_g.z) + (gyr_g.z) ) + posX ;
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
          byte[] buf = new byte[0x400];
          Arrays.fill(int(buf), 0);
          buf[0] = 0x03;
          joycon_send_subcommand(0, 0x1, 0x3, new byte[] {0x3f}, 1);
          Thread.sleep(100);
          buf[0] = 0x01;
          joycon_send_subcommand(0, 0x1, 0x1, buf, 1);
          Thread.sleep(100);

          buf[0] = 0x02;
          joycon_send_subcommand(0, 0x1, 0x1, buf, 1);          
          Thread.sleep(100);

          buf[0] = 0x03;
          joycon_send_subcommand(0, 0x1, 0x1, buf, 1);
          Thread.sleep(100);

          buf[0] = 0x0;
          joycon_send_subcommand(0, 0x1, 0x30, buf, 1);
          Thread.sleep(100);

          joycon_send_subcommand(0, 0x1, 0x40, new byte[] {0x1}, 1);

          Thread.sleep(100);

          joycon_send_subcommand(0, 0x1, 0x3, new byte[] {0x30}, 1);
          Thread.sleep(100);

          joycon_send_subcommand(0, 0x1, 0x48, new byte[] {0x1}, 1);
          Thread.sleep(100);

          Thread.sleep(10000);
        } 
        catch(InterruptedException e) {
          println(e);
        }
      }
    }
    );
    thread.start();
  }



  //    joycon_send_subcommand(0, 0x3, 0x40, buf, 1);

  //joycon_send_subcommand(0, 0x2, 0x40, buf, 1);

  private void joycon_send_subcommand(int handle, int command, int subcommand, byte[] data, int len) {
    byte[] buf = new byte[0x400];
    Arrays.fill(int(buf), 0);
    byte[] rumble_base = {
      byte((++global_count) & 0xF), // 1 & 0xF -> 0001 AND 1111 -> 0001 -> 1
      0x00, // 0
      0x01, // 1
      0x40, // 64
      0x40, // 64
      0x00, // 0
      0x01, // 1
      0x40, // 64
      0x40  // 64
    };
    //println(rumble_base);

    for (int i=0; i<rumble_base.length; i++) {
      buf[i] = rumble_base[i];
    }

    buf[9] = byte(subcommand);
    if (data != null && len != 0) {
      for (int i=0; i<len; i++) {
        buf[i+10] = data[i];
      }
    }

    joycon_send_command(handle, command, buf, 10 + len);
  }

  private void joycon_send_command(int handle, int command, byte[] data, int len) {
    byte[] buf = new byte[0x400];
    Arrays.fill(int(buf), 0);

    buf[0] = byte(command);

    for (int i=0; i<len; i++) {
      buf[i+1] = data[i];
    }

    hid_exchange(handle, buf, len + 1);
  }

  private void hid_exchange(int handle, byte[] buf, int len) {
    //hid_write(handle, buf, len);
    //println(handle + "hoge");
    //for (int i=0; i<32; i++) {
    //  println(buf[i]);
    //}
    //println(len);
    dev.setOutputReport(byte(0x01), buf, len);
  }

  public Vector3 getAccel() {
    return acc_g;
  }

  public Vector3 getGyro() {
    return gyr_g;
  }

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
}