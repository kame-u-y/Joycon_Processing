import purejavahidapi.*;
import purejavahidapi.HidDevice;
import java.util.List;

public static class JoyconConstants {
  public static final int VENDOR_ID = 0x057E;
  public static final int LEFT_ID   = 0x2006;
  public static final int RIGHT_ID  = 0x2007;
}

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
}

Joycon joyRight;
Joycon joyLeft;

void setup() {
  joyRight = new Joycon(JoyconConstants.RIGHT_ID);
  joyLeft  = new Joycon(JoyconConstants.LEFT_ID);
  
  println(joyRight.getProductName());
  println(joyLeft.getProductName());
}