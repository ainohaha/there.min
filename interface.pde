import processing.serial.*;
import processing.sound.*;

Serial myConnection;

// --- AUDIO OBJECTS ---
// We now have 3 oscillators for harmonic layering
SinOsc sine1, sine2, sine3; 

// --- DATA & SMOOTHING ---
float targetFreq = 440;
float currentFreq = 440; 
float currentNote = 60; 

// --- STATE ---
int harmonicLevel = 0; // 0 = Clean, 1 = +Octave, 2 = +Fifth
int lastB1 = 0; // For detecting button clicks
int lastB2 = 0;

// MEDIAN FILTER VARIABLES
float[] history = new float[7]; 
int historyIdx = 0;
float smoothedDist = 50; 

float targetAmp = 0;
float currentAmp = 0; 

void setup() {
  size(1000, 600); 
  surface.setResizable(true); 
  background(20); 

  // Initialize all 3 oscillators
  sine1 = new SinOsc(this);
  sine2 = new SinOsc(this); // Octave
  sine3 = new SinOsc(this); // Fifth

  // Start them all silently
  sine1.play(); sine1.amp(0);
  sine2.play(); sine2.amp(0);
  sine3.play(); sine3.amp(0);
  
  for(int i=0; i<history.length; i++) history[i] = 50;

  printArray(Serial.list());
  
  try {
    String portName = Serial.list()[5]; 
    myConnection = new Serial(this, portName, 9600);
    myConnection.bufferUntil('\n');
  } catch (Exception e) {
    println("SERIAL ERROR: Check port index.");
  }
}

void draw() {
  // --- PHYSICS SMOOTHING ---
  currentFreq = lerp(currentFreq, targetFreq, 0.15); 
  currentAmp = lerp(currentAmp, targetAmp, 0.2);

  background(25); 
  
  drawPitchGuide();

  // --- WAVEFORM VISUALIZER ---
  pushMatrix();
  translate(60, 0); 
  
  noFill();
  
  float r = map(currentFreq, 100, 800, 50, 255);
  float b = map(currentFreq, 100, 800, 255, 50);
  stroke(r, 100, b); 
  strokeWeight(3);
  
  beginShape();
  for (int x = 0; x < width-60; x+=4) {
    float angle = map(x, 0, width, 0, TWO_PI * (currentFreq / 60.0)) - (frameCount * 0.2);
    
    // Calculate visual wave based on active harmonics for accurate representation
    float y = sin(angle);
    if (harmonicLevel >= 1) y += sin(angle * 2.0) * 0.5; // Visual Octave
    if (harmonicLevel >= 2) y += sin(angle * 1.5) * 0.4; // Visual Fifth
    
    y = y * (height/4 * currentAmp); // Scale by volume
    vertex(x, height/2 + y);
  }
  endShape();
  popMatrix();

  // UI Text
  fill(255);
  textAlign(CENTER);
  text("CHROMATIC THEREMIN (HARMONICS: " + harmonicLevel + ")", width/2 + 30, height - 50);
  text("NOTE: " + getNoteName(int(currentNote)), width/2 + 30, height - 30);
  
  updateAudio();
}

void updateAudio() {
  // Base Note
  sine1.freq(currentFreq);
  sine1.amp(currentAmp);
  
  // Harmonic 1: Octave (2x Frequency)
  if (harmonicLevel >= 1) {
    sine2.freq(currentFreq * 2.0);
    sine2.amp(currentAmp * 0.4); // Lower volume for harmonic
  } else {
    sine2.amp(0);
  }

  // Harmonic 2: Perfect Fifth (1.5x Frequency)
  if (harmonicLevel >= 2) {
    sine3.freq(currentFreq * 1.5);
    sine3.amp(currentAmp * 0.3); // Lower volume for harmonic
  } else {
    sine3.amp(0);
  }
}

void drawPitchGuide() {
  noStroke();
  fill(40);
  rect(0, 0, 60, height);
  
  stroke(255, 50, 50); 
  strokeWeight(2);
  
  for (int n = 52; n <= 88; n += 12) {
    float y = map(n, 52, 88, height - 20, 20);
    line(0, y, 60, y);
    fill(255, 150);
    textSize(10);
    textAlign(LEFT);
    text("E" + ((n/12)-1), 5, y - 2);
  }
  
  float cursorY = map(currentNote, 52, 88, height - 20, 20);
  fill(255);
  noStroke();
  rect(0, cursorY - 3, 60, 6);
}

void serialEvent(Serial conn) {
  String incoming = conn.readString();
  
  if (incoming != null) {
    incoming = trim(incoming);
    String[] data = split(incoming, ',');

    if (data.length == 4) {
      try {
        float rawDist = float(data[0]); 
        float potRaw = float(data[1]);   
        int b1 = int(data[2]); // Button 1
        int b2 = int(data[3]); // Button 2

        // --- BUTTON LOGIC ---
        if (b1 == 1 && lastB1 == 0) {
          harmonicLevel++;
          if (harmonicLevel > 2) harmonicLevel = 2; 
        }
        if (b2 == 1 && lastB2 == 0) {
          harmonicLevel--;
          if (harmonicLevel < 0) harmonicLevel = 0; 
        }
        lastB1 = b1;
        lastB2 = b2;

        float sliderVol = map(potRaw, 0, 1023, 0.0, 0.8);

        // --- GATE LOGIC ---
        // If hand is within 60cm (Musical 50cm + 10cm Buffer), play sound.
        // Otherwise, mute the output.
        if (rawDist > 2 && rawDist < 60) { 
           targetAmp = sliderVol; // Hand Present -> Volume UP
           
           history[historyIdx] = rawDist;
           historyIdx = (historyIdx + 1) % history.length;
           float[] sorted = sort(history);
           float medianDist = sorted[history.length / 2];
           smoothedDist = lerp(smoothedDist, medianDist, 0.2);
           
           float d = constrain(smoothedDist, 5, 50);
           float rawNote = map(d, 5, 50, 88, 52); 
           currentNote = round(rawNote); 
           targetFreq = 440 * pow(2, (currentNote - 69) / 12.0);
        } else {
           targetAmp = 0; // Hand Gone -> Volume CUT
        }
        
      } catch (Exception e) {}
    }
  }
}

String getNoteName(int note) {
  String[] names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
  return names[note % 12] + ((note / 12) - 1);
}
