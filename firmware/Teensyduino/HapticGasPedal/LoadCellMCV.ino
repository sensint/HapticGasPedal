// Updated code of binning algorithm to adjust for delays, debounce and latency caused by high filter weights.
// Setting the max value based on the average of the first 10 measurements and then mapping it to the full range (or using that as the max and min in the mapping function).
//#include <AudioStream.h>
//#include <SD.h>
//=========== include libraries ===========
#include <Arduino.h>
#include <Audio.h>
#include "HX711.h"
HX711 scale;

uint8_t dataPin  = 25;//for esp32
uint8_t clockPin = 24;//for esp32

//=========== Audio Variables ===========
AudioSynthWaveform signal;
AudioOutputPT8211 toHaptuator;
AudioConnection patchCord1(signal, 0, toHaptuator, 0);
AudioConnection patchCord2(signal, 0, toHaptuator, 1);

//=========== Other Variables ===========
#define MESSAGESIZE 4
float receivedMessage[MESSAGESIZE] = {40, 40, 0.9, 0.9}; //{#bins, freq, amp-pos, amp-neg}
unsigned long vibrationDuration = 5;
unsigned long vibrationStartTime;


//=========== Sensor Variables ===========
#define sensingPin  A0
float filtered_val = 0.0;
float filter_weight = 0.8;
int currentBinNumber;

const uint8_t sensorResolution = 10;  // 10 bit resolution
//const int sensorMaxValue = (1 << sensorResolution) - 1;
const int sensorMaxValue = 10000;
const int sensorMinValue = 0;
int led = 13;
int count = 0;


//=========== Descriptors ===========
bool slope_is_positive = true;
int direction = 1;
int lastBinNumber = 0;
bool isVibrating = false; // Checks if the haptuator is vibrating
bool newTrigger = true; // New trigger to initiate the one bin
int newPulseID = 0; //ID of new pulse
int currentPulseID = 0; //ID of ongoing pulse
// its allways the smaller of the two option,
//so when going from 4 to 5, its 5, when going from 7 to 6 its 6

//do we need a current bin-number?
//======================================

void sensorSetup() {
  Serial.println(__FILE__);
  Serial.print("LIBRARY VERSION: ");
  Serial.println(HX711_LIB_VERSION);
  Serial.println();

  scale.begin(dataPin, clockPin);

  Serial.print("UNITS: ");
  Serial.println(scale.get_units(10));

  Serial.println("\nEmpty the scale, press a key to continue");
  while (!Serial.available());
  while (Serial.available()) Serial.read();

  scale.tare();
  Serial.print("UNITS: ");
  Serial.println(scale.get_units(10));


  Serial.println("\nPut 1000 gram in the scale, press a key to continue");
  while (!Serial.available());
  while (Serial.available()) Serial.read();

  scale.calibrate_scale(1000, 5);
  Serial.print("UNITS: ");
  Serial.println(scale.get_units(10));

  Serial.println("\nScale is calibrated, press a key to continue");
  // Serial.println(scale.get_scale());
  // Serial.println(scale.get_offset());
  while (!Serial.available());
  while (Serial.available()) Serial.read();
}

void setup() {
  AudioMemory(20);
  delay(50); // time for DAC voltage stable
  Serial.begin(115200);
  sensorSetup();
  pinMode(sensingPin, INPUT);
  analogReadRes(sensorResolution); // Uncomment this for button press.
  signal.frequency(receivedMessage[1]);
  pinMode(led, OUTPUT); // Used for Debugging and debounce condition
}

void loop() {

  if (scale.is_ready()) {
    auto rheo_read = scale.get_units(1);
    filtered_val = (1.0 - filter_weight) * filtered_val + filter_weight * rheo_read;
    currentBinNumber = map(filtered_val, sensorMinValue, sensorMaxValue, 0, receivedMessage[0]);       // Function for the type of mapping. (Currently used is Linear)
//    Serial.println(currentBinNumber);
      Serial.printf("%f,%f,%f\n", rheo_read, filtered_val, currentBinNumber);

  }
  //  int currentBinNumber = map(filtered_val, sensorMinValue, sensorMaxValue, 0, receivedMessage[0]);       // Function for the type of mapping. (Currently used is Linear)
  ////  Serial.println(currentBinNumber);
  //  Serial.printf("%f,%f,%f\n", rheo_read, filtered_val, currentBinNumber);
//  delay(1);
//  return;

  //=========== Logic ===========
  if (currentBinNumber != lastBinNumber) {   // Trigger if pointer moves into a new bin.

    // ******* #1 Assign a pulse number *************************
    if (currentBinNumber > lastBinNumber) { //check for the pulse ID
      newPulseID =  currentBinNumber;

    }  else {
      newPulseID =  lastBinNumber;

    }



    // ******* #2 Check if Pulse is already vibrating *************************
    if (!isVibrating) { // if its not vibrating, start a new pulse with a new ID
      //   currentPulseID = newPulseID;

    }


    // ******* #3 Check if we have a new Pulse ID *************************
    if (newPulseID == currentPulseID) { //don't do anything if its already vibrating
      //with an existing pusle
      //don't retrigger the same pulse!
      //(this is probably not needed)

    } else {
      //!!! currently same pulses cannot retrigger at all, this is maybe too strict
      currentPulseID = newPulseID;
      vibrationStartTime = millis();
      signal.begin(WAVEFORM_TRIANGLE);
      signal.amplitude(receivedMessage[2]); //<-- maybe give thes explicit variables
      isVibrating = true;



    }
    lastBinNumber = currentBinNumber;

  }

  if (isVibrating) {
    if (millis() >= vibrationStartTime + vibrationDuration) {  //if the duration is over
      signal.amplitude(0.f); // set volume to zero
      // signal.stop(WAVEFORM_PULSE);
      isVibrating = false;
    }



  }
  delay(1);
}
