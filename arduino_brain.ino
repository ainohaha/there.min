#define B1 7
#define B2 6
#define TRIG_PIN 9
#define ECHO_PIN 10
#define POT_PIN A0

void setup() {
  pinMode(B1, INPUT);
  pinMode(B2, INPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  Serial.begin(9600);
}

void loop() {
  // 1. Measure Distance (Ultrasonic)
  long duration;
  int distance;
  
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  
  duration = pulseIn(ECHO_PIN, HIGH);
  distance = duration * 0.034 / 2; // Calculate distance in cm
  
  // REMOVED THE 50CM CAP.
  // Now we just filter out "0" which is an error code.
  // We cap at 400 (hardware max) to prevent math errors.
  if (distance <= 0 || distance > 400) {
    distance = 400; 
  }

  // 2. Read Potentiometer
  int potVal = analogRead(POT_PIN);

  // 3. Read Buttons
  int b1State = digitalRead(B1);
  int b2State = digitalRead(B2);

  // 4. Send Packet: distance,pot,b1,b2
  Serial.print(distance);
  Serial.print(",");
  Serial.print(potVal);
  Serial.print(",");
  Serial.print(b1State);
  Serial.print(",");
  Serial.println(b2State);

  delay(20); 
}
