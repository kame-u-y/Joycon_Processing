public static class JoyconConstants {
  public static final int VENDOR_ID = 0x057E;
  public static final int LEFT_ID   = 0x2006;
  public static final int RIGHT_ID  = 0x2007;
}

public enum Button {
  DPAD_DOWN, 
    DPAD_RIGHT, 
    DPAD_LEFT, 
    DPAD_UP, 
    SL, 
    SR, 
    MINUS, 
    HOME, 
    PLUS, 
    CAPTURE, 
    STICK, 
    SHOULDER_1, 
    SHOULDER_2;
}


public enum Subcommand {
  SetInputReportMode(0x03), 
    SetPlayerLights(0x30), 
    SetHomeLight(0x38),
    EnableIMU(0x40), 
    EnableVibration(0x48);

  private int id;

  private Subcommand(final int id) {
    this.id = id;
  }

  public byte getId() {
    return (byte)this.id;
  }
}