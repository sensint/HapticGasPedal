// Targeting Task

import controlP5.*;
import java.io.*;
import java.util.*;
import processing.serial.*;

// ====================== Defaults =============================
int loadCellValMin = 0;
int loadCellValMax = 600; // Max Load Cell Value (Displayed at the bottom)
int recordInterval = 50;
int baudRate = 115200;

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
boolean isThirdScreen = false;
boolean isMainTrial = false;
boolean trialEnded = false;

boolean isSerialAvailable = false;

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
float targetSize = 150;
float targetSizeWidth = 10;
color targetColor = color(255, 0, 0); // Red
float targetSpeedMin = 1;
float targetSpeedMax = 5;
float targetSpeed;
int direction = 1; // 1 for moving down, -1 for moving up

// Player properties
float playerX;
float playerY;
float playerSize = 150;
color playerColor = color(0, 0, 255); // Blue
float playerSpeed = 5;
float velocityMultiplier = 0.05; // Adjust this value to control the velocity sensitivity

boolean gameActive = true;
int timerDuration = 20 * 1000; // 30 seconds
int startTime;
int currentTrial = 0;
int maxTrials = 3;

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
  int windowHeight = displayHeight;
  size(windowWidth, windowHeight);
}

void setup() {
  frameRate(100);

  cp5 = new ControlP5(this);
  cp5.setColor(ControlP5.THEME_RETRO);

  textAlign(LEFT, TOP);

  // Code to select the sequence of pedals (Or just type the sequence of the pedals)
  // The difficulty of the trial should be pre-programmed.

  String[] portList = Serial.list();
  if (portList.length > 0) {
    String portName = portList[0];
    try {
      teensyPort = new Serial(this, portName, baudRate);
      println("Serial port connected: " + portName);
      isSerialAvailable = true;

      // ================== Create CSV file =====================
      String filename = "load_cell_data.csv";
      csvWriter = createWriter(filename);
      csvWriter.println("Sample Time (ms), Load Cell Value, Target Value"); // Write header to the CSV file 

      resetGame();    // Initialize the game
      startTime = millis(); // Start the timer
    }
    catch (Exception e) {
      println("Failed to connect to serial port: " + portName);
    }
  } else {
    println("No serial ports available.");
  }
}


void draw() {
  background(255); // Clear the background
  fill(0);
  textAlign(CENTER, BOTTOM);

  if (isSerialAvailable) {

    if (isFirstScreen) {
      // First Screen - Participant ID
      textSize(25);
      text("Enter Participant ID:", width / 2, height/2 - 30);
      text(participantID, width / 2, height/2);
    } else if (isSecondScreen) {
      // Second Screen - Pedal Type
      text("Code:", width / 2, height / 2 - 50);
      drawButtons();
      fill(playerColor);
      text("Please fill the questionnaire", width / 2, height / 2 - 250);
    } else if (isThirdScreen) {
      // Second Screen - Pedal Type
      text("Click to start the first trial", width / 2, height / 2);
    } else if (isMainTrial) {   

      textSize(20);
      text("Trial: " + (runCounter + 1), width / 2 - 200, height / 1.1);
      text("Participant ID: " + participantID, width / 2 - 50, height / 1.1);
      text("Code: " + buttonPressed, width / 2 + 150, height / 1.1);
      line(width / 2 - 200, height - 300, width / 2 + 200, height - 300);
      stroke(10);
      line(width / 2 - 200, -targetSize / 2 + 100, width / 2 + 200, -targetSize / 2 + 100);

      String data = teensyPort.readStringUntil('\n');
      if (data != null) {
        data = trim(data);
        loadCellValue = int(data);
        // the mapping should come here
        playerSpeed = map(loadCellValue, 0, 1023, height/2, 0) * velocityMultiplier;
      }

      // Write the sample to the CSV file
      csvWriter.println(millis() + "," + loadCellValue);

      // Display the current loadCellValue and number of samples
      fill(0);
      textSize(18);
      textAlign(LEFT, TOP);
      text("Load Cell Value: " + loadCellValue, 10, 10);

      if (gameActive) {
        // Update player position
        //if (keyPressed) {
        //  if (keyCode == UP) {
        //    playerY -= playerSpeed;
        //  } else if (keyCode == DOWN) {
        //    playerY += playerSpeed;
        //  }
        //}

        playerY += playerSpeed; // uncomment this when there is a continuous stream of data from the microcontroller.

        // Move the target continuously
        targetY += targetSpeed;

        // Wrap the target's position around the screen
        if (targetY < -50 / 2 + 150 || targetY > height - 300) {
          targetY = targetY + targetSpeed * direction;
          direction *= -1;
          resetTargetSpeed();
        } 

        // Wrap the player's position around the screen
        //if (targetY < -targetSize / 2 || targetY > height + 200) {
        //  targetY = targetY + targetSpeed * direction;
        //  direction *= -1;
        //  resetTargetSpeed();
        //}

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
        textSize(35);
        textAlign(CENTER, BOTTOM);
        text("Trial Over", width / 2, height / 2 - 50);
        text("Click to proceed to the next trial", width / 2, height / 2 + 50);
        textSize(20);
      }
    }
  } else {
    text("Serial port is not available", width/2, height/2);
  }
}

void drawButtons() {
  fill(20);
  for (int i = 0; i < 4; i++) {
    if (buttonAvailable[i]) {
      rect(width / 2 - 100 + i * 50, height / 2 - 20, 40, 40);
      fill(20);
      text(getButtonLabel(i), width / 2 - 100 + i * 50 + 20, height / 2 + 60);
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
}

void mousePressed() {
  if (isFirstScreen) {
    isFirstScreen = false;
    isSecondScreen = true;
  } else if (isSecondScreen) {
    // Second Screen - Select Pedal    
    for (int i = 0; i < 4; i++) {
      if (buttonAvailable[i] && mouseY > height / 2 - 20 && mouseY < height / 2 + 20 &&
        mouseX > width / 2 - 100 + i * 50 && mouseX < width / 2 - 60 + i * 50) {
        buttonPressed = getButtonLabel(i);
        buttonAvailable[i] = false; // Disable the button
        isSecondScreen = false;
        isThirdScreen = true;
        break;
      }
    }
  } else if (isThirdScreen) {
    isThirdScreen = false;
    isMainTrial = true;
  } else if (isMainTrial) {
    runCounter++;
    if (runCounter >= 3) {
      // End of main trials
      isFirstScreen = false;
      isSecondScreen = true;
      isMainTrial = false;
      buttonPressed = "";
      runCounter = 0;
    } else {
      // Reset for the next trial
      isSecondScreen = false;
      isMainTrial = true;
      resetGame();
    }
  }
}

void trialDifficulty() {
  // Code to generate trial difficulty or even load it based on preset values.
}
