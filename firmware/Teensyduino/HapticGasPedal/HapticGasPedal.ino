#include <cmath>

#include <Audio.h>
#include <EEPROM.h>
#include <HX711.h> // install the HX711 library by Rob Tillaart (https://github.com/RobTillaart/HX711)

#define VERSION "v1.0.0"

// uncomment to enable printing debug information to the serial port
#define DEBUG


namespace defaults {

/**
 * @brief Enumeration of waveforms that can be used for the signal generation.
 * The values are copied from the Teensy Audio Library.
 */
enum class Waveform : short {
  kSine = 0,
  kSawtooth = 1,
  kSquare = 2,
  kTriangle = 3,
  kArbitrary = 4,
  kPulse = 5,
  kSawtoothReverse = 6,
  kSampleHold = 7,
  kTriangleVariable = 8,
  kBandlimitSawtooth = 9,
  kBandlimitSawtoothReverse = 10,
  kBandlimitSquare = 11,
  kBandlimitPulse = 12
};

//=========== signal generator ===========
static constexpr uint16_t kNumberOfBins = 36;
static constexpr uint32_t kSignalDurationUs = 10000; // in microseconds
static constexpr short kSignalWaveform = static_cast<short>(Waveform::kSine);
static constexpr float kSignalFreqencyHz = 80.f;
static constexpr float kSignalAmp = 1.f;

//=========== sensor ===========
static constexpr uint8_t kSensorClockPin = 24;
static constexpr uint8_t kSensorDataPin = 25;
static constexpr float kFilterWeight = 0.7;
static constexpr float kSensorScale = 1.f;  // will be overwritten from EEPROM
static constexpr uint32_t kSensorMinValue = 0; // in grams - will be overwritten from EEPROM
static constexpr uint32_t kSensorMaxValue = 10000; // in grams - will be overwritten from EEPROM
static constexpr uint32_t kSensorJitterThreshold = 15; // increase value if vibration starts resonating too much
static constexpr uint32_t kSendSensorDataMaxDelayMs = 30; // in milliseconds
static constexpr uint32_t kCalibrationDelayMs = 5000; // in milliseconds
static constexpr uint16_t kCalibrationWeight = 100; // in grams - set to value of your known weight

//=========== EEPROM ===========
static constexpr int kEEPROMSensorScaleAddress = 0; // holds a 32 bit (4 byte) float
static constexpr int kEEPROMSensorMinValueAddress = 4; // holds a 32 bit (4 byte) uint32_t
static constexpr int kEEPROMSensorMaxValueAddress = 8; // holds a 32 bit (4 byte) uint32_t

//=========== serial ===========
static constexpr int kBaudRate = 115200;
}  // namespace defaults


namespace {

/**
 * @brief a struct to hold the settings of the sensor.
 */
typedef struct {
  float filter_weight = defaults::kFilterWeight;
  float scale = defaults::kSensorScale;
  uint32_t min_value = defaults::kSensorMinValue;
  uint32_t max_value = defaults::kSensorMaxValue;
  uint32_t send_data_delay = defaults::kSendSensorDataMaxDelayMs;
  uint32_t calibration_delay = defaults::kCalibrationDelayMs;
  uint16_t calibration_weight = defaults::kCalibrationWeight;
} SensorSettings;

/**
 * @brief a struct to hold the settings for the signal generator.
 */
typedef struct {
  uint16_t number_of_bins = defaults::kNumberOfBins;
  uint32_t duration_us = defaults::kSignalDurationUs;
  short waveform = defaults::kSignalWaveform;
  float frequency_hz = defaults::kSignalFreqencyHz;
  float amp = defaults::kSignalAmp;
} SignalGeneratorSettings;


//=========== settings instances ===========
// These instances are used to access the settings in the main code.
SensorSettings sensor_settings;
SignalGeneratorSettings signal_generator_settings;

//=========== audio variables ===========
AudioSynthWaveform signal;
AudioOutputPT8211 dac;
AudioConnection patchCord1(signal, 0, dac, 0);
AudioConnection patchCord2(signal, 0, dac, 1);

//=========== sensor variables ===========
HX711 sensor;
float filtered_sensor_value = 0.f;
float last_triggered_sensor_val = 0.f;

//=========== control flow variables ===========
elapsedMillis send_sensor_data_delay_ms = 0;
elapsedMicros pulse_time_us = 0;
bool is_vibrating = false;
uint16_t mapped_bin_id = 0;
uint16_t last_bin_id = 0;
bool augmentation_enabled = false;
bool recording_enabled = false;


//=========== helper functions ===========
// These functions were extracted to simplify the control flow and will be
// inlined by the compiler.
inline void SetupSerial() __attribute__((always_inline));
inline void SetupAudio() __attribute__((always_inline));
inline void SetupSensor() __attribute__((always_inline));
inline void CalibrateSensor() __attribute__((always_inline));

void SetupSerial() {
  while (!Serial && millis() < 5000)
    ;
  Serial.begin(defaults::kBaudRate);
}

void SetupAudio() {
  AudioMemory(20);
  delay(50);  // time for DAC voltage stable
  signal.begin(signal_generator_settings.waveform);
  signal.frequency(signal_generator_settings.frequency_hz);
}

void SetupSensor() {
#ifdef DEBUG
  Serial.print(F("HX711 library version: "));
  Serial.println(HX711_LIB_VERSION);
#endif
  sensor.begin(defaults::kSensorDataPin, defaults::kSensorClockPin);
  delay(10);
  EEPROM.get(defaults::kEEPROMSensorScaleAddress, sensor_settings.scale);
  EEPROM.get(defaults::kEEPROMSensorMinValueAddress, sensor_settings.min_value);
  EEPROM.get(defaults::kEEPROMSensorMaxValueAddress, sensor_settings.max_value);
  sensor.set_scale(sensor_settings.scale);
#ifdef DEBUG
  Serial.printf(">>> initial values from EEPROM:\n\t scale=%f\n\t min=%d\n\t max=%d\n",
                sensor_settings.scale,
                (int)sensor_settings.min_value,
                (int)sensor_settings.max_value);
#endif
}

void CalibrateSensor() {
#ifdef DEBUG
  Serial.printf("HX711 units (before calibration): %f\n", sensor.get_units(10));
  Serial.printf(F("clear the loadcell from any weight\n"));
#endif
  // you have some time to unload the cell
  delay(sensor_settings.calibration_delay);
  sensor.tare();
#ifdef DEBUG
  Serial.printf("HX711 units (after tare): %f\n", sensor.get_units(10));
  Serial.printf(F("place a calibration weight on the loadcell\n"));
#endif
  // you have some time to load the cell with the calibration weight
  delay(sensor_settings.calibration_delay);
  sensor.calibrate_scale(sensor_settings.calibration_weight, 5);
  sensor_settings.scale = sensor.get_scale();
  EEPROM.put(defaults::kEEPROMSensorScaleAddress, sensor_settings.scale);
#ifdef DEBUG
  Serial.printf("HX711 units (after calibration): %f\n", sensor.get_units(10));
  Serial.printf("HX711 scale (after calibration): %f\n", sensor_settings.scale);
#endif
}

void CalibrateSensorRange() {
#ifdef DEBUG
  Serial.printf("HX711 units (before calibration): %f\n", sensor.get_units(10));
  Serial.printf(F("clear the loadcell from any weight\n"));
#endif
  // you have some time to unload the cell
  delay(sensor_settings.calibration_delay);
  sensor.tare();
  sensor_settings.min_value = sensor.get_units(10);
  EEPROM.put(defaults::kEEPROMSensorMinValueAddress, sensor_settings.min_value);
#ifdef DEBUG
  Serial.printf("min value (after tare): %i\n", (int)sensor_settings.min_value);
  Serial.printf(F("place the max. allowed weight on the loadcell\n"));
#endif
  // you have some time to load the cell with the maximum weight/force
  delay(sensor_settings.calibration_delay);
  sensor_settings.max_value = sensor.get_units(10);
  EEPROM.put(defaults::kEEPROMSensorMaxValueAddress, sensor_settings.max_value);
#ifdef DEBUG
  Serial.printf("max. value : %i\n", (int)sensor_settings.max_value);
#endif
}

/**
 * @brief start a pulse by setting the amplitude of the signal to a predefined
 * value
 */
void StartPulse() {
  signal.begin(signal_generator_settings.waveform);
  signal.frequency(signal_generator_settings.frequency_hz);
  signal.phase(0.0);
  signal.amplitude(signal_generator_settings.amp);
  pulse_time_us = 0;
  is_vibrating = true;
#ifdef DEBUG
  Serial.printf(">>> Start pulse \n\t wave: %d \n\t amp: %.2f \n\t freq: %.2f Hz \n\t dur: %d µs\n",
                (int)signal_generator_settings.waveform,
                signal_generator_settings.amp,
                signal_generator_settings.frequency_hz,
                (int)signal_generator_settings.duration_us);
#endif
}

/**
 * @brief stop the pulse by setting the amplitude of the signal to zero
 */
void StopPulse() {
  signal.amplitude(0.f);
  is_vibrating = false;
#ifdef DEBUG
  Serial.println(F(">>> Stop pulse"));
#endif
}
}  // namespace

void setup() {
  SetupSerial();
  
#ifdef DEBUG
  Serial.printf("HAPTIC GAS PEDAL (%s)\n\n", VERSION);
  Serial.println(F("======================= SETUP ======================="));
  Serial.printf("\nUSAGE \
                \n\t send 'c' to calibrate the sensor \
                \n\t send 's' to set the min. and max. vaules \
                \n\t send 't' to tare the sensor \
                \n\t send 'r' to toggle on/off sensor recording \
                \n\t send 'a' to toggle on/off augmentation \
                \n\t send 'f' + number (e.g. f150) to set the frequency \
                \n\t send 'b' + number (e.g. b10) to set the number of bins \
                \n\t send 'd' + number (e.g. d10000) to set the pulse duration (in microseconds) \
                \n");
#endif

  SetupAudio();
  SetupSensor();

#ifdef DEBUG
  Serial.printf(">>> signal generator settings \n\t bins: %d \n\t wave: %d \n\t amp: %.2f \n\t freq: %.2f Hz \n\t dur: %d µs\n",
                (int)signal_generator_settings.number_of_bins,
                (int)signal_generator_settings.waveform,
                signal_generator_settings.amp,
                signal_generator_settings.frequency_hz,
                (int)signal_generator_settings.duration_us);
  Serial.println(F("=====================================================\n\n"));
#endif

  delay(500);
}



void loop() {
  delay(1); // check if actually needed to give the serial port some time for reading
  if (Serial.available()) {
    auto serial_c = (char)Serial.read();
    switch (serial_c) {
      case 'c': CalibrateSensor();
      break;
      case 's': CalibrateSensorRange();
      break;
      case 't': sensor.tare();
      break;
      case 'a': augmentation_enabled = !augmentation_enabled;
      break;
      case 'r': recording_enabled = !recording_enabled;
      break;
      case 'f': { // frequency
        if (Serial.available()) {
          signal_generator_settings.frequency_hz = Serial.parseFloat();
          signal.frequency(signal_generator_settings.frequency_hz);
#ifdef DEBUG
          Serial.printf("new frequency: %dHz\n", (int)signal_generator_settings.frequency_hz);
#endif
        }
        break;
      }
      case 'b': { // number of bins
        if (Serial.available()) {
          signal_generator_settings.number_of_bins = (uint16_t)Serial.parseInt();
#ifdef DEBUG
          Serial.printf("new number of bins: %d\n", (int)signal_generator_settings.number_of_bins);
#endif
        }
        break;
      }
      case 'd' : { // pulse duration
        if (Serial.available()) {
          signal_generator_settings.duration_us = (uint32_t)Serial.parseInt();
#ifdef DEBUG
          Serial.printf("new pulse duration: %dus\n", (int)signal_generator_settings.duration_us);
#endif
        }
        break;
      }
    }
  }

  // once the load cell is ready to be read, we calculate the current bin
  if (sensor.is_ready()) {
    // this will use units, i.e. grams
    auto sensor_value = sensor.get_units(1);
    // this will use raw XX-bit sensor data
    // auto sensor_value = sensor.get_value(1);

    // this will limit the load cell to only one direction in the range of the calibrated values
    sensor_value = constrain(sensor_value, sensor_settings.min_value, sensor_settings.max_value);

    filtered_sensor_value =
        (1.f - sensor_settings.filter_weight) * filtered_sensor_value +
        sensor_settings.filter_weight * sensor_value;

    // calculate the bin id depending on the filtered sensor value
    // (currently linear mapping)
    mapped_bin_id = map(filtered_sensor_value,
                        sensor_settings.min_value, sensor_settings.max_value,
                        0, signal_generator_settings.number_of_bins);
  }

  // send the filtered value to the Unity application in a fixed update rate
  if (recording_enabled && send_sensor_data_delay_ms > sensor_settings.send_data_delay) {
    Serial.println((int)filtered_sensor_value);
    send_sensor_data_delay_ms = 0;    
  }

  // NOTE: If augmentation is disabled, no code below this line will be executed.
  if (!augmentation_enabled) {
    if (is_vibrating) {
      StopPulse();
      delay(1);
    }
    return;
  }

  // auto dist = std::abs((uint32_t)(filtered_sensor_value - last_triggered_sensor_val));
  // if (dist < defaults::kSensorJitterThreshold) {
  //     return;
  // }
  
  if (mapped_bin_id != last_bin_id) {
    if (is_vibrating) {
#ifdef DEBUG
      Serial.println(F(">>> Stop pulse before it finished"));
#endif
      StopPulse();
      delay(1); // debatable ;) maybe use delayMicroseconds(100) instead
    }
    
#ifdef DEBUG
    Serial.printf(">>> Change bin \n\t bin id: %d\n", (int)mapped_bin_id);
#endif
    StartPulse();
    last_bin_id = mapped_bin_id;
    last_triggered_sensor_val = filtered_sensor_value;
  }

  if (is_vibrating && pulse_time_us >= signal_generator_settings.duration_us) {
    StopPulse(); //stop pulse if duration is exceeded
  }  
}
