// Targeting Task

import controlP5.*;
import java.io.*;
import java.util.*;
import processing.serial.*;

// ====================== Defaults =============================
int loadCellValMin = 0;
int loadCellValMax = 600; // Max Load Cell Value (Displayed at the bottom)
int recordInterval = 50;
int baudRate = 9600;

// ====================== GUI Controls =============================
ControlP5 cp5;
Textlabel recTimeLabel;
ControlTimer timer;

// ====================== GUI Layout =============================
String participantID = "";
String trialNumber = "";
String buttonPressed = "";
boolean isFirstScreen = true;
boolean isSecondScreen = false;
boolean isMainTrial = false;

boolean[] buttonAvailable = { true, true, true, true }; // Array to track button availability
int runCounter = 0; // Counter to keep track of the number of trials per participant

// ====================== Colors =============================
// https://colorhunt.co/palette/2a09443fa796fec260a10035
color colorLabelsLight = color(255);
color colorLabelsDark = color(0);
color colorBackgroundLight = color(240);
color colorVTop = color(42, 9, 68);
color colorVBottom = color(63, 167, 150);
color colorHInner = color(254, 194, 96);
color colorHOuter = color(161, 0, 53);

// Target properties
float targetX;
float targetY;
float targetSize = 50;
float targetSizeWidth = 10;
color targetColor = color(255, 0, 0); // Red
float targetSpeedMin = 1;
float targetSpeedMax = 5;
float targetSpeed;
int direction = 1; // 1 for moving down, -1 for moving up

// Player properties
float playerX;
float playerY;
float playerSize = 30;
color playerColor = color(0, 0, 255); // Blue
float playerSpeed = 5;

boolean gameActive = true;
int timerDuration = 30 * 1000; // 30 seconds
int startTime;

// ====================== I/O =============================
Serial teensyPort;
int loadCellValue ; // Reading in gms

// ====================== Saving =======================
ArrayList<Float> samples;
int sampleRate = 30; // Number of samples per second
int sampleInterval = 1000 / sampleRate; // Interval between samples in milliseconds
int lastSampleTime;
PrintWriter csvWriter;

void settings() {
  int windowWidth = displayWidth / 3;
  int windowHeight = displayHeight / 2;
  size(windowWidth, windowHeight);
}

void setup() {
  frameRate(100);

  cp5 = new ControlP5(this);
  cp5.setColor(ControlP5.THEME_RETRO);
  
  textAlign(CENTER, CENTER);
  textSize(20);

  String portName = Serial.list()[0];
  teensyPort = new Serial(this, portName, baudRate);

  // ================== Create CSV file =====================
  String filename = "load_cell_data.csv";
  csvWriter = createWriter(filename);
  csvWriter.println("Sample Time (ms), Load Cell Value, Target Value"); // Write header to the CSV file 

  resetGame();    // Initialize the game
  startTime = millis(); // Start the timer
}


void draw() {
  background(255); // Clear the background

  // Check if there is value 
  if (teensyPort.available() > 0) {
    String data = teensyPort.readStringUntil('\n');
    if (data != null) {
      data = trim(data);
      loadCellValue = int(data);
    }
  }

  // Write the sample to the CSV file
  csvWriter.println(millis() + "," + loadCellValue);

  // Display the current loadCellValue and number of samples
  fill(0);
  textSize(18);
  textAlign(LEFT, TOP);
  text("Load Cell Value: " + loadCellValue, 10, 10);
  
  if (isFirstScreen) {
    // First Screen - Participant ID
    text("Enter Participant ID:", width / 2, height / 2 - 30);
    text(participantID, width / 2, height / 2);
  } else if (isSecondScreen) {
    // Second Screen - Trial Number
    text("Select Pedal Type:", width / 2, height / 2 - 50);
    drawButtons();
  } else if (isMainTrial) {
    
    text("Trial: " + (runCounter + 1), width / 2, height / 2 - 70);
    text("Participant ID: " + participantID, width / 2, height / 2 - 30);
    text("Button Pressed: " + buttonPressed, width / 2, height / 2);

  if (gameActive) {
    // Update player position
    if (keyPressed) {
      if (keyCode == UP) {
        playerY -= playerSpeed;
      } else if (keyCode == DOWN) {
        playerY += playerSpeed;
      }
    }

    // Move the target continuously
    targetY += targetSpeed;

    // Wrap the target's position around the screen
    if (targetY < -targetSize / 2 || targetY > height) {
      targetY = targetY + targetSpeed * direction;
      direction *= -1;
      resetTargetSpeed();
    } 

    // Draw target
    fill(targetColor);
    rect(width / 2 - targetSize / 2, targetY - targetSize / 2, targetSize, targetSizeWidth);

    // Draw player
    fill(playerColor);
    rect(width / 2 - playerSize / 2, playerY - playerSize / 2, playerSize, targetSizeWidth);

    // Check for collision
    if (abs(targetY - playerY) <= targetSize / 2 + playerSize / 2) {
      // Target reached
      // Do something here, e.g., increment score, display message, etc.
    }

    // Check if the time is up
    if (millis() - startTime >= timerDuration) {
      gameActive = false;
    }
  } else {
    // Trial over
    fill(0);
    textSize(30);
    textAlign(CENTER, CENTER);
    text("Trial Over", width / 2, height / 2);
  }
}
}

void drawButtons() {
  fill(200);
  for (int i = 0; i < 4; i++) {
    if (buttonAvailable[i]) {
      rect(width / 2 - 100 + i * 50, height / 2 - 20, 40, 40);
      fill(0);
      text(getButtonLabel(i), width / 2 - 100 + i * 50 + 20, height / 2);
    }
  }
}

String getButtonLabel(int index) {
  switch (index) {
    case 0:
      return "CA";
    case 1:
      return "RA";
    case 2:
      return "CN";
    case 3:
      return "RN";
    default:
      return "";
  }
}

void resetGame() {
  // Reset player position to the center of the screen
  playerX = width / 2;
  playerY = height / 2;

  // Randomize target position within the window
  targetY = random(targetSize / 2, height - targetSize / 2);

  resetTargetSpeed();

  gameActive = true;
  startTime = millis(); // Restart the timer
}

void resetTargetSpeed() {
  // Randomize target speed within the specified range
  targetSpeed = random(targetSpeedMin, targetSpeedMax) * (random(0, 1) > 0.5 ? 1 : -1);
}

void keyPressed() {
  if (keyCode == ENTER) {
    resetGame(); // Reset game when Enter key is pressed
  }

  if (key == 's' || key == 'S') {
    // Save and close the CSV file
    csvWriter.flush();
    csvWriter.close();
    println("CSV file saved successfully.");
  }
  
  if (isFirstScreen) {
    // Participant ID input
    if (keyCode == BACKSPACE && participantID.length() > 0) {
      participantID = participantID.substring(0, participantID.length() - 1);
    } else if (keyCode == ENTER) {
      isFirstScreen = false;
      isSecondScreen = true;
    } else if (keyCode >= 32 && keyCode <= 126) {
      participantID += key;
    }
  } 
  //else if (isSecondScreen) {
  //  // Trial Number input
  //  if (keyCode == BACKSPACE && trialNumber.length() > 0) {
  //    trialNumber = trialNumber.substring(0, trialNumber.length() - 1);
  //  } else if (keyCode == ENTER) {
  //    isSecondScreen = false;
  //    isMainTrial = true;
  //  } else if (keyCode >= 32 && keyCode <= 126) {
  //    trialNumber += key;
  //  }
  //}
}

void mousePressed() {
  if (isFirstScreen) {
    isFirstScreen = false;
    isSecondScreen = true;
  }
  else if (isSecondScreen) {
    // Second Screen - Select Pedal
    for (int i = 0; i < 4; i++) {
      if (buttonAvailable[i] && mouseY > height / 2 - 20 && mouseY < height / 2 + 20 &&
          mouseX > width / 2 - 100 + i * 50 && mouseX < width / 2 - 60 + i * 50) {
        buttonPressed = getButtonLabel(i);
        buttonAvailable[i] = false; // Disable the button
        isSecondScreen = false;
        isMainTrial = true;
        break;
      }
    }
  }
}

void mouseClicked() {
  if (isMainTrial) {
    runCounter++;
    if (runCounter >= 4) {
      // End of main trials
      isFirstScreen = true;
      isSecondScreen = false;
      isMainTrial = false;
      buttonPressed = "";
    } else {
      // Reset for the next main trial
      isSecondScreen = true;
      isMainTrial = false;
      buttonPressed = "";
      for (int i = 0; i < 4; i++) {
        buttonAvailable[i] = true;
      }
    }
  }
}

//void mousePressed() {
//  // Transition to the next screen upon mouse click
//  if (isFirstScreen) {
//    isFirstScreen = false;
//    isSecondScreen = true;
//  } else if (isSecondScreen) {
//    isSecondScreen = false;
//    isMainTrial = true;
//  }
//}
