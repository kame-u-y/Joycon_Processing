Joycon joyRight;
Joycon joyLeft;

void setup() {
  joyRight = new Joycon(JoyconConstants.RIGHT_ID);
  joyLeft  = new Joycon(JoyconConstants.LEFT_ID);
  
  println(joyRight.getProductName());
  println(joyLeft.getProductName());
}