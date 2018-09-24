float bg = 100;
int param1 = 100;
int param2 = 300;
float param3 = 4.0f;
int param4 = 100;

Joycon joyconLeft;
Joycon joyconRight;

void setup() {
  joyconLeft  = new Joycon(JoyconConstants.LEFT_ID);
  joyconRight = new Joycon(JoyconConstants.RIGHT_ID);
  size(600, 600);
  //fullScreen();
}

void draw() {
  background(bg);
  //println(joycon.getStick()[0]);

  Vector3 accelLeft = joyconLeft.getAccel();
  Vector3 gyroLeft  = joyconLeft.getGyro();

  Vector3 accelRight = joyconRight.getAccel();
  Vector3 gyroRight  = joyconRight.getGyro();
  if (frameCount%100==0) {
   //println();
   //println(accel.x, accel.y, accel.z);
   //println(gyro.x, gyro.y, gyro.z);
   //println();
   //println("{x:", String.format("%1$.2f", accel.x), "y:", String.format("%1$.2f", accel.y), "z:", String.format("%1$.2f", accel.z), "}");
   //println("{x:", String.format("%1$.2f", gyro.x), "y:", String.format("%1$.2f", gyro.y), "z:", String.format("%1$.2f", gyro.z), "}");
    
   joyconLeft.setRumble( param1, param2, param3, param4 );
   joyconLeft.sendRumble(joyconLeft.rumble_obj.getData());
  }
  if (frameCount%100==50) {

   joyconRight.setRumble( param1, param2, param3, param4);
   joyconRight.sendRumble(joyconRight.rumble_obj.getData());
   println(joyconRight.spi());
  }
  noStroke();
  fill(random(255), 0, 0);
  ellipse(width/2 + joyconLeft.posX*10, height/2 + joyconLeft.posY*10, 10, 10);
  fill(0, random(100, 255), 0);
  ellipse(width/2 + joyconRight.posX*10, height/2 + joyconRight.posY*10, 100, 100);

  textSize(20);

  if (joyconLeft.getButton(Button.SHOULDER_1)) text("SHOULDER_1", width/2, height/2-40);
  if (joyconLeft.getButton(Button.SHOULDER_2)) text("SHOULDER_2", width/2, height/2-20);
  if (joyconLeft.getButton(Button.DPAD_DOWN)) text("DPAD_DOWN", width/2, height/2);
  if (joyconLeft.getButton(Button.DPAD_RIGHT)) text("DPAD_RIGHT", width/2, height/2+20);
  if (joyconLeft.getButton(Button.DPAD_LEFT)) {
    text("DPAD_LEFT", width/2, height/2+40);
    joyconLeft.initialPosition();
  }
  if (joyconLeft.getButton(Button.DPAD_UP)) text("DPAD_UP", width/2, height/2+60);
  if (joyconLeft.getButton(Button.STICK))   text("STICK", width/2, height/2+80);

  if (joyconRight.getButton(Button.SHOULDER_1)) text("SHOULDER_1", width/2, height/2-40);
  if (joyconRight.getButton(Button.SHOULDER_2)) text("SHOULDER_2", width/2, height/2-20);
  if (joyconRight.getButton(Button.DPAD_DOWN)) text("DPAD_DOWN", width/2, height/2);
  if (joyconRight.getButton(Button.DPAD_RIGHT)) text("DPAD_RIGHT", width/2, height/2+20);
  if (joyconRight.getButton(Button.DPAD_LEFT)) {
    text("DPAD_LEFT", width/2, height/2+40);
    joyconRight.initialPosition();
  }
  if (joyconRight.getButton(Button.DPAD_UP)) text("DPAD_UP", width/2, height/2+60);

  if (joyconRight.getButton(Button.STICK)) text("STICK", width/2, height/2+80);
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

void keyPressed() {
  if (keyCode==UP) {
    param1++;
  } else if (keyCode==RIGHT) {
    param2++;
  } else if (keyCode==DOWN) {
    param3 += 0.1f;
  } else if (keyCode==LEFT) {
    param4 ++;
  }

  //println(param1, param2, param3, param4);
}

void dispose() {
  //println("hoe");
  //joyconLeft.detach();
  println(true);
}