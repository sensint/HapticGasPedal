// Targeting Task
// To Do: In a particular trial, add a timer on the screen before the target starts moving
// Targetting trajectory

import controlP5.*;
import java.io.*;
import java.util.*;
import processing.serial.*;
import processing.data.Table;
import processing.data.TableRow;

// ====================== Defaults =============================
int loadCellValMin = 0;
int loadCellValMax = 6500; // Replace when mounted on the pedal with the maximum value which can be achieved with the load cell.
int recordInterval = 30;
int baudRate = 115200;

// ====================== GUI Layout =============================
String participantID = "";
String trialNumber = "";
String buttonPressed = "";
boolean isFirstScreen = true;
boolean isSecondScreen = false;
boolean isThirdScreen = false;
boolean isMainTrial = false;
boolean trialEnded = false;
boolean movingDown = true; // Flag to determine slider direction

boolean isSerialAvailable = false;
boolean isRecording = false;
boolean isBufferClear = false;

boolean[] buttonAvailable = { true, true, true, true }; // Array to track button availability
int runCounter = 0; // Counter to keep track of the number of trials per participant

// Target properties
float targetX;
float targetY;
float targetSize = 150;
float targetSizeWidth = 10;
color targetColor = color(255, 0, 0); // Red
float targetSpeedMin = 1;
float targetSpeedMax = 5;
float targetSpeed;

// ====================== Trajectory Settings =============================
char profile;
char difficultyOfTrajectory;
float targetAmplitude = height - 425;
; // Amplitude of the target's vertical movement
float targetFrequencySine; // Frequency of the target's vertical movement
float targetDurationSine; // Duration of the target's movement for a sine profile
float targetDirection; // Direction of the target's vertical movement
float targetAccelerationTriangle;
int direction = 1; // 1 for moving down, -1 for moving up

// Targeting Task
float[] velocityRange = {0.1, 0.3, 0.6, 0.9};   // Different velocities for the slider

float[] travelPercent =  {0, 0.25, 0.5, 0.75, 1.0}; // Different travel percentages
float[] accelerationRange = {0, 0.1, -0.1};     // Different acceleration values

// Index variables to keep track of current values from the arrays
int velocityIndex = 0;
int travelIndex = 0;
int accelerationIndex = 0;

// Player properties
float playerX;
float playerY;
float playerSize = 150;
color playerColor = color(0, 0, 255); // Blue
float playerSpeed = 5;
float velocityMultiplier = 0.15; // Adjust this value to control the velocity sensitivity

boolean gameActive = true;
int timerDuration = 30 * 1000; // 30 seconds
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
Table savedData;
String[] trajectoryArray;

void settings() {
  int windowWidth = displayWidth / 3;
  int windowHeight = displayHeight;
  size(windowWidth, windowHeight);
}

void setup() {
  frameRate(100);
  textAlign(LEFT, TOP);
  
  // Loading the Trajectory
  trajectoryArray = loadStrings("TotalTrajectoryEasy1.csv");
  printArray(trajectoryArray);

  String[] portList = Serial.list();
  if (portList.length > 0) {
    String portName = portList[0];
    try {
      teensyPort = new Serial(this, portName, baudRate);
      println("Serial port connected: " + portName);
      isSerialAvailable = true;

      resetGame();    // Initialize the game
    }
    catch (Exception e) {
      println("Failed to connect to serial port: " + portName);
    }
  } else {
    println("No serial ports available.");
  }

  savedData = new Table();
  savedData.addColumn("Time");
  savedData.addColumn("User");
  savedData.addColumn("Target");
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
      text("Click to start the first trial", width / 2, height / 2);
      if (isBufferClear == false){
        teensyPort.clear();
        isBufferClear = true;
      }
    } else if (isMainTrial) {   
      
      if (isBufferClear == false){
        teensyPort.clear();
        isBufferClear = true;
      }
      
      textSize(20);
      text("Trial: " + (runCounter + 1), width / 2 - 200, height / 1.1);
      text("Participant ID: " + participantID, width / 2 - 50, height / 1.1);
      text("Code: " + buttonPressed, width / 2 + 150, height / 1.1);
      line(width / 2 - 200, height - 300, width / 2 + 200, height - 300);
      stroke(10);
      line(width / 2 - 200, -targetSize / 2 + 100, width / 2 + 200, -targetSize / 2 + 100);
      //line(width / 2 - 200, 100, width / 2 + 200, 100);

      String filename = "P" + participantID + "_" + buttonPressed + "_" + (runCounter + 1) + ".csv";

      String data = teensyPort.readStringUntil('\n');
      if (data != null) {
        data = trim(data);
        loadCellValue = int(data);

        if (loadCellValue > loadCellValMax) {
          loadCellValue = loadCellValMax;
        }
          //playerSpeed = map(loadCellValue, 0, 20000, height, 0) * velocityMultiplier; // Feed the maximum value of the calibrate_sensor_range from
        //playerSpeed = map(loadCellValue, 0, 2000, -50, 50) * -velocityMultiplier; // Feed the maximum value of the calibrate_sensor_range
        //playerY = map(loadCellValue, 0, 1023, 125, height - 300); // For HS sliders
        //playerY = map(loadCellValue, loadCellValMin, loadCellValMax, 125, height - 300); // UNCOMMENT when using the Load Cell Value
        playerY = map(loadCellValue, loadCellValMin, loadCellValMax, height - 300, 125); // UNCOMMENT when using the Load Cell Value
      }
      // Display the current loadCellValue and number of samples
      fill(0);
      textSize(18);
      textAlign(LEFT, TOP);
      text("Speed: " + loadCellValue, 20, 20);

      if (gameActive) {
        // Update player position
        //if (keyPressed) {
        //  if (keyCode == UP) {
        //    playerY -= playerSpeed;
        //  } else if (keyCode == DOWN) {
        //    playerY += playerSpeed;
        //  }
        //}

        TableRow newRow = savedData.addRow();
        newRow.setInt("Time", (millis()-startTime));
        newRow.setFloat("User", playerY);
        newRow.setFloat("Target", targetY);

        saveTable(savedData, filename);

        //playerY += playerSpeed; // uncomment this when there is a continuous stream of data from the microcontroller.

        // Move the target continuously
        //targetY += targetSpeed;

        // Wrap the target's position around the screen
        if (movingDown) {
          targetY -= targetSpeed;
        } else {
          targetY += targetSpeed;
        }

        if (targetY < -50 / 2 + 150 || targetY > height - 300) {
          //targetY = targetY + targetSpeed * direction;
          movingDown = !movingDown;
          //resetTargetSpeed();
        } 

        // Wrap the player's position around the screen
        if (playerY < -50 / 2 + 150 || playerY > height - 300) {
          //playerY = playerY + playerSpeed * direction;
          //direction *= -1;
          //resetPlayerSpeed();
        }

        // Draw target and player
        fill(targetColor);
        rect(width / 2 - targetSize / 2, targetY - targetSize / 2, targetSize, targetSizeWidth);
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
          println("CSV saved successfully.");
        }
      } else {
        // Trial over
        fill(0);
        textSize(35);
        textAlign(CENTER, BOTTOM);
        text("Trial Over", width / 2, height / 2 - 50);
        text("Click to proceed to the next trial", width / 2, height / 2 + 50);
        textSize(20);
        savedData = new Table();
        savedData.addColumn("Time");
        savedData.addColumn("User");
        savedData.addColumn("Target");
      }
    }
  } else {
    text("Serial port is not available", width/2, height/2);
  }
}
//}

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

  // Reset target position to the center of the screen
  targetX = width/2;
  targetY = height/2;

  resetTargetSpeed();
  resetPlayerSpeed();

  gameActive = true;
  startTime = millis(); // Restart the timer
}

void resetTargetSpeed() {
  // Randomize target speed within the specified range
  //targetSpeed = random(targetSpeedMin, targetSpeedMax) * (random(0, 1) > 0.5 ? 1 : -1);
  //targetSpeed = velocityRange[int(random(velocityRange.length))]*5;
  targetSpeed = 0.6*5;
}

void resetPlayerSpeed() {
  playerSpeed = -1 * playerSpeed;
}

void keyPressed() {
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

  // CONTROL KEYS //
  if (key == 'c') {
    // Send command to microcontroller to calibrate load cell
    teensyPort.write('c');
    println("Calibrating load cell");
  } else if (key == 't') {
    teensyPort.write('t');
    println("Taring the load cell");
  } else if (key == 'r') {
    teensyPort.write('r');
    println("Recording On/ Off");
  } else if (key == 's') {
    teensyPort.write('s');
    println("Per participant sensor calibration");
  } else if (key == 'a') {
    teensyPort.write('a');
    println("Start/ Stop Augmentation");
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
    resetGame();
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
  // Code to generate trial based on preset values.

  // These need to be the position profiles
  // Triangle: Continuously up - reflects - continuously down
  // Plateau: Continuously up - hold up (3 seconds) - continuously down
  // Sine: sliderY = height / 2 + amplitude * sin(TWO_PI * frequency * frameCount);
  // Intermediate Plateau:
  // Custom 1: increasing velocity continuously till dropping to 0 - reflects - decreasing velocity continously to dropping it to 0;

  // Velocity = {0.2, 0.6, 1.0}
  // Acceleration = {-0.1, 0, 0.1}
  // Trajectory = {0.25, 0.5, 0.75, 1}

  // Easy: if trialDifficultyIndex = 1{
  // Velocity changes, no acceleration, no trajectory changes
  // Triangle, plateau,

  // Medium: if trialDifficultyIndex = 2{
  // Velocity changes, acceleration changes, no trajectory changes
  // Sine, custom 1

  // Hard: if trialDifficultyIndex = 3{
  // All change.
  // Intermediate Sine, intermediate plateau, full custom 1, 

  // Have a positive and negative versions of all the profiles -> Which gives 6 trials for each pedal OR run a single one for 1 minute

  // The trajectory file should be saved once and read for each trial corresponding to the trial number.

  //switch(difficultyOfTrajectory) {
  //  case 'E': // Easy

  //  break;
  //  case 'M': // Medium
  //  targetY = height / 2 + targetAmplitude * sin(TWO_PI * targetFrequencySine * targetDurationSine / 2);
  //  break;
  //  case 'D': // Difficulty

  //  break;
  //}

  switch(profile) {
  case 'S':
    // Have the sine profile
    targetY = height / 2 + targetAmplitude * sin(TWO_PI * targetFrequencySine * targetDurationSine / 2);
    break;

  case 'T':
    // Have a triangle
    if (movingDown) {
      targetY -= targetSpeed;
    } else {
      targetY += targetSpeed;
    }

    if (targetY < -50 / 2 + 150 || targetY > height - 300) {
      movingDown = !movingDown;
    } 
    break;

  case'P':
    // Have a plateau
    // Maintain a certain velocity

    // Reach the top and hold there for 3 seconds

    // Come down with the certain velocity

    break;

  case 'C':
    // Have a custom
    break;
  }
}
