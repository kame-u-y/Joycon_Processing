float bg = 100;

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

Joycon joycon;

void setup() {
  joycon = new Joycon();
  size(400, 400);
}

void draw() {
  background(bg);
  //println(joycon.getStick()[0]);

  Vector3 accel = joycon.getAccel();
  Vector3 gyro  = joycon.getGyro();
  if (frameCount%10==0) {
    //println();
    //println(accel.x, accel.y, accel.z);
    //println(gyro.x, gyro.y, gyro.z);
    //println();
    //println("{x:", String.format("%1$.2f", accel.x), "y:", String.format("%1$.2f", accel.y), "z:", String.format("%1$.2f", accel.z), "}");
    //println("{x:", String.format("%1$.2f", gyro.x), "y:", String.format("%1$.2f", gyro.y), "z:", String.format("%1$.2f", gyro.z), "}");
    
    joycon.setRumble( 160, 320, 0.6f, 200 );
    joycon.sendRumble(joycon.rumble_obj.getData());
  }

  fill(255, 0, 0);
  ellipse(width/2 + joycon.posX*10, height/2 + joycon.posY*10, 100, 100);
  textSize(20);

  if (joycon.getButton(Button.SHOULDER_1)) text("SHOULDER_1", width/2, height/2-40);
  if (joycon.getButton(Button.SHOULDER_2)) text("SHOULDER_2", width/2, height/2-20);
  if (joycon.getButton(Button.DPAD_DOWN)) text("DPAD_DOWN", width/2, height/2);
  if (joycon.getButton(Button.DPAD_RIGHT)) text("DPAD_RIGHT", width/2, height/2+20);
  if (joycon.getButton(Button.DPAD_LEFT)) {
    text("DPAD_LEFT", width/2, height/2+40);
    joycon.initialPosition();
  }
  if (joycon.getButton(Button.DPAD_UP)) text("DPAD_UP", width/2, height/2+60);

  if (joycon.getButton(Button.STICK)) text("STICK", width/2, height/2+80);
}

void exit() {
}

float maxValue3(Vector3 _v) {
  if (abs(_v.x) > abs(_v.y)) {
    if (abs(_v.x) > abs(_v.z)) return 0;
    else return 2;
  } else {
    if (abs(_v.y) > abs(_v.z)) return 1;
    else return 2;
  }
}