#include <EEPROM.h>


#define VERSION "v1.0.0"

// uncomment to enable printing debug information to the serial port
#define DEBUG


namespace defaults {
//=========== EEPROM ===========
static constexpr int kEEPROMSensorScaleAddress = 0; // holds a 32 bit (4 byte) float
static constexpr int kEEPROMSensorMinValueAddress = 4; // holds a 32 bit (4 byte) uint32_t
static constexpr int kEEPROMSensorMaxValueAddress = 8; // holds a 32 bit (4 byte) uint32_t
//=========== sensor ===========
static constexpr float kSensorScale = 1.f;
static constexpr uint32_t kSensorMinValue = 0;
static constexpr uint32_t kSensorMaxValue = 20000;
//=========== serial ===========
static constexpr int kBaudRate = 115200;
}


namespace {
//=========== helper functions ===========
// These functions were extracted to simplify the control flow and will be inlined by the compiler.
inline void SetupSerial() __attribute__((always_inline));
inline void WriteEEPROM() __attribute__((always_inline));
inline void ReadEEPROM() __attribute__((always_inline));

void SetupSerial() {
  while (!Serial && millis() < 5000)
    ;
  Serial.begin(defaults::kBaudRate);
}

void WriteEEPROM() {
  EEPROM.put(defaults::kEEPROMSensorScaleAddress, defaults::kSensorScale);
  EEPROM.put(defaults::kEEPROMSensorMinValueAddress, defaults::kSensorMinValue);
  EEPROM.put(defaults::kEEPROMSensorMaxValueAddress, defaults::kSensorMaxValue);
}

void ReadEEPROM() {
  float scale = 0.f;
  uint32_t min = 0;
  uint32_t max = 0;
  EEPROM.get(defaults::kEEPROMSensorScaleAddress, scale);
  EEPROM.get(defaults::kEEPROMSensorMinValueAddress, min);
  EEPROM.get(defaults::kEEPROMSensorMaxValueAddress, max);
#ifdef DEBUG
  Serial.printf("initial values from EEPROM:\n  scale=%f\n  min=%d\n  max=%d\n", scale, (int)min, (int)max);
#endif
}
} // namespace


void setup() {
  SetupSerial();
#ifdef DEBUG
  Serial.printf("SET EEPROM (%s)\n\n", VERSION);
  Serial.println(F("======================= SETUP ======================="));
#endif
  WriteEEPROM();
  ReadEEPROM();
}


void loop() {
}
