#include <Audio.h>
#include <cmath>


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
static constexpr uint16_t kNumberOfBins = 20;
static constexpr uint32_t kSignalDurationUs = 10000; // in microseconds
static constexpr short kSignalWaveform = static_cast<short>(Waveform::kSine);
static constexpr float kSignalFreqencyHz = 150.f;
static constexpr float kSignalAmp = 1.f;

//=========== sensor ===========
static constexpr uint8_t kAnalogSensingPin = A1;
static constexpr float kFilterWeight = 0.05;
static constexpr uint8_t kSensorResolution = 24;
static constexpr uint32_t kSensorMaxValue = (1U << kSensorResolution) - 1;
static constexpr uint32_t kSensorMinValue = 0;
static constexpr uint32_t kSensorJitterThreshold = 7; // increase value if vibration starts resonating too much

//=========== serial ===========
static constexpr int kBaudRate = 115200;
}  // namespace defaults


namespace {

/**
 * @brief a struct to hold the settings of the sensor.
 *
 */
typedef struct {
  float filter_weight = defaults::kFilterWeight;
  uint8_t resolution = defaults::kSensorResolution;
  uint32_t max_value = defaults::kSensorMaxValue;
  uint32_t min_value = defaults::kSensorMinValue;
  bool run_calibration = false;
} SensorSettings;

/**
 * @brief a struct to hold the settings for the signal generator.
 *
 */
typedef struct {
  uint16_t number_of_bins = defaults::kNumberOfBins;
  uint32_t duration_us = defaults::kSignalDurationUs;
  short waveform = defaults::kSignalWaveform;
  float frequency_hz = defaults::kSignalFreqencyHz;
  float amp = defaults::kSignalAmp;
} SignalGeneratorSettings;

union SerializableSignalGeneratorSettings {
  SignalGeneratorSettings data;
  uint8_t serialized[sizeof(SignalGeneratorSettings)];
};

//=========== settings instances ===========
// These instances are used to access the settings in the main code.
SensorSettings sensor_settings;
SignalGeneratorSettings signal_generator_settings;
union SerializableSignalGeneratorSettings signal_generator_settings_serialized = { .data = signal_generator_settings };

//=========== audio variables ===========
AudioSynthWaveform signal;
AudioOutputPT8211 dac;
AudioConnection patchCord1(signal, 0, dac, 0);
AudioConnection patchCord2(signal, 0, dac, 1);

//=========== sensor variables ===========
float filtered_sensor_value = 0.f;

//=========== control flow variables ===========
static constexpr uint32_t kSendForceMaxDelayMs = 1000; // in milliseconds
elapsedMillis send_force_delay_ms = 0;
elapsedMicros pulse_time_us = 0;
bool is_vibrating = false;
uint16_t last_bin_id = 0;


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

/**
 * @brief set up the audio system
 */
void SetupAudio() {
  AudioMemory(20);
  delay(50);  // time for DAC voltage stable
  signal.begin(signal_generator_settings.waveform);
  signal.frequency(signal_generator_settings.frequency_hz);
}

void SetupSensor() {
  // initialize load cell (e.g., library object)
}

void CalibrateSensor() {
  // load previous values from EEPROM
  // get the readings  
  // do the math
  // store the updated value(s) to EEPROM
  // do more fancy things here :)

  sensor_settings.run_calibration = false;
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
  Serial.printf("HAPTIC SERVO (%s)\n\n", VERSION);
  Serial.println(F("======================= SETUP ======================="));
#endif

  SetupAudio();
  SetupSensor();

#ifdef DEBUG
  Serial.printf(">>> Signal generator settings \n\t bins: %d \n\t wave: %d \n\t amp: %.2f \n\t freq: %.2f Hz \n\t dur: %d µs\n",
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
  if (Serial.available()) {
    // check if 'c' is received (means 'do calibration')
    auto serial_c = (char)Serial.read();
    sensor_settings.run_calibration = (serial_c == 'c');
  }

  if (sensor_settings.run_calibration) {
    CalibrateSensor();
  }

  // replace the following line with the load cell reading
  auto sensor_value = analogRead(defaults::kAnalogSensingPin);
  
  filtered_sensor_value =
      (1.f - sensor_settings.filter_weight) * filtered_sensor_value +
      sensor_settings.filter_weight * sensor_value;
  static uint16_t last_triggered_sensor_val = filtered_sensor_value;

  // send the filtered value to the Unity application in a fixed update rate
  if (send_force_delay_ms > kSendForceMaxDelayMs) {
    Serial.print((int)filtered_sensor_value);
    send_force_delay_ms = 0;    
  }

  // calculate the bin id depending on the filtered sensor value
  // (currently linear mapping)
  uint16_t mapped_bin_id = map(filtered_sensor_value, sensor_settings.min_value,
                               sensor_settings.max_value, 0,
                               signal_generator_settings.number_of_bins);
  
  if (mapped_bin_id != last_bin_id) {
    auto dist = std::abs(filtered_sensor_value - last_triggered_sensor_val);
    if (dist < defaults::kSensorJitterThreshold) {
       return;
    }
    
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
