import purejavahidapi.*;
import purejavahidapi.HidDevice;
import java.util.List;

public class Joycon {

  private HidDevice dev;
  private HidDeviceInfo devInfo;
  private boolean isLeft;

  Joycon(int _id) {
    connectDevice(_id);
  }

  private void connectDevice(int _id) { 
    List<HidDeviceInfo> devList = PureJavaHidApi.enumerateDevices();

    for (HidDeviceInfo info : devList) {
      if ( info.getVendorId() != JoyconConstants.VENDOR_ID ) continue;

      if ( info.getProductId() == _id ) isLeft = true;
      else if ( info.getProductId() == _id ) isLeft = false;
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

  public String getProductName() {
    return devInfo.getProductString();
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

        //processButtonsAndStick(data);

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
          //Subcommand 0x40: Enable IMU (6-Axis sensor)
          joycon_send_subcommand(0x1, 0x40, new byte[] {0x01});
          Thread.sleep(100);
          ////Standard full mode. Pushes current state @60Hz
          joycon_send_subcommand(0x1, 0x3, new byte[] {0x31});
        } 
        catch(InterruptedException e) {
          println(e);
        }
      }
    }
    );
    thread.start();
  }
}