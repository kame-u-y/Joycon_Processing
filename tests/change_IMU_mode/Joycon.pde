import purejavahidapi.*;
import purejavahidapi.HidDevice;
import java.util.List;
import java.util.Arrays;

public class Joycon {

  private HidDevice dev;
  private HidDeviceInfo devInfo;
  private boolean isLeft;
  private int packetCount=0;

  Joycon(int _id) {
    if (_id == JoyconConstants.LEFT_ID) isLeft = true;
    connectDevice(_id);
    setRemovalListener();
    setReportListener();
    changeMode();
  }

  private void connectDevice(int _id) { 
    List<HidDeviceInfo> devList = PureJavaHidApi.enumerateDevices();

    for (HidDeviceInfo info : devList) {
      if ( info.getVendorId()  != JoyconConstants.VENDOR_ID ) continue;
      if ( info.getProductId() != _id ) continue;

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

  public String getProductName() {
    if (devInfo==null) {
      println("connection error");
      return "null, connection error";
    }
    return devInfo.getProductString();
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
        System.out.printf("onInputReport: id %d len %d data ", Id, len);
        for (int i = 0; i < len; i++) System.out.printf("%02x ", data[i]);
        System.out.println();
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
          //Subcommand 0x40: Enable IMU (6-Axis sensor)
          joycon_send_subcommand(0x1, 0x40, new byte[] {0x01});
          Thread.sleep(100);
          ////Standard full mode. Pushes current state @60Hz
          joycon_send_subcommand(0x1, 0x3, new byte[] {0x30});
        } 
        catch(InterruptedException e) {
          println(e);
        }
      }
    }
    );
    thread.start();
  }


  /* 
   {command, ++(packetCount) & 0xF, 0x00, 0x01, 0x40, 0x40, 0x00, 0x01, 0x40, 0x40, subcommand, data[0], ... , data[data.length-1]}
   */
  private void joycon_send_subcommand(int command, int subcommand, byte[] data) {
    if (devInfo==null) {
      println("connection error");
      return;
    }
    byte[] buf = new byte[0x400];
    byte[] b = {
      byte(command), 
      byte(++(packetCount) & 0xF), // 1 & 0xF -> 0001 AND 1111 -> 0001 -> 1
      0x00, 0x01, 0x40, 0x40, 0x00, 0x01, 0x40, 0x40, 
      byte(subcommand)
    };

    Arrays.fill(int(buf), 0);
    System.arraycopy(b, 0, buf, 0, b.length);
    System.arraycopy(data, 0, buf, b.length, data.length);

    int len = b.length + data.length;

    dev.setOutputReport(byte(0), buf, len);
  }
}