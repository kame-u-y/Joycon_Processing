Joycon joycon;

void setup() {
  joycon = new Joycon();
  size(1000, 1000);
}

void draw() {
  background(255);

  Vector3 accel = joycon.getAccel();
  Vector3 gyro  = joycon.getGyro();
  if (frameCount%10==0) {
    //println();
    //println(accel.x, accel.y, accel.z);
    //println(gyro.x, gyro.y, gyro.z);
    //println();

    println("{x:", String.format("%1$.2f", gyro.x), "y:", String.format("%1$.2f", gyro.y), "z:", String.format("%1$.2f", gyro.z), "}");
  }
  
  fill(255, 0, 0);
  ellipse(width/2 + joycon.posX*10, height/2 + joycon.posY*10, 100, 100);
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