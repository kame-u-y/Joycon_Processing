float bg = 100;

Joycon joyconLeft;
Joycon joyconRight;

void setup() {
  size(600, 600);
  //fullScreen();

  joyconLeft  = new Joycon(JoyconConstants.LEFT_ID);
  joyconRight = new Joycon(JoyconConstants.RIGHT_ID);
}

void draw() {
  background(bg);
  noStroke();

  Vector3 leftAccel = joyconLeft.getAccel();
  Vector3 leftGyro  = joyconLeft.getGyro();
  fill(random(255), 0, 0);
  ellipse(width/2 + joyconLeft.posX*10, height/2 + joyconLeft.posY*10, 10, 10);
  displayInputText(joyconLeft);

  Vector3 rightAccel = joyconRight.getAccel();
  Vector3 rightGyro  = joyconRight.getGyro();
  fill(0, 255, 0);
  ellipse(width/2 + joyconRight.posX*10, height/2 + joyconRight.posY*10, 100, 100);
  displayInputText(joyconRight);
}

void displayInputText(Joycon j) {
  textSize(20);

  if (j.getButton(Button.SHOULDER_1)) {
    text("SHOULDER_1", width/2, height/2-40);
  }
  if (j.getButton(Button.SHOULDER_2)) {
    text("SHOULDER_2", width/2, height/2-20);
  }
  if (j.getButton(Button.DPAD_DOWN)) {
    text("DPAD_DOWN", width/2, height/2);
  }
  if (j.getButton(Button.DPAD_RIGHT)) {
    text("DPAD_RIGHT", width/2, height/2+20);
  }
  if (j.getButton(Button.DPAD_LEFT)) {
    text("DPAD_LEFT", width/2, height/2+40);
    j.initialPosition();
  }
  if (j.getButton(Button.DPAD_UP)) {
    text("DPAD_UP", width/2, height/2+60);
  }
  if (j.getButton(Button.STICK)) {
    text("STICK", width/2, height/2+80);
  }
}

void startVibration(Joycon j) {
  int p1 = 100;
  int p2 = 300;
  float p3 = 4.0f;
  int p4 = 100;

  j.startVibration(p1, p2, p3, p4);
}

void dispose() {
  joyconLeft.detach();
  joyconRight.detach();
  println(true);
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