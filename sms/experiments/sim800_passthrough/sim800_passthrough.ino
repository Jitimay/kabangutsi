// Pre-G0 test: Arduino Nano as a USB <-> serial bridge for a SIM800A GSM module.
// After flashing, the host sees the SIM800A as a plain AT modem on /dev/ttyUSB0
// (CH340 Nano clone) or /dev/ttyACM0, so at_probe.py / gammu can talk to it directly.
//
// Wiring (SIM800A board with its own 5V/2A supply; GND MUST be shared with the Nano):
//   SIM800A TXD -> Nano D10 (SoftwareSerial RX)
//   SIM800A RXD -> Nano D11 (SoftwareSerial TX)  (if the board is 3.3 V logic, use a divider)
//   SIM800A GND -> Nano GND
// Power the SIM800A from a supply able to give 2 A bursts; the Nano 5V pin is NOT enough
// (symptom: module resets / "UNDER-VOLTAGE" / RDY loop when it registers on the network).
//
// Host side: python ../at_probe.py /dev/ttyUSB0 --baud 9600

#include <SoftwareSerial.h>

SoftwareSerial gsm(10, 11);  // RX, TX

void setup() {
  Serial.begin(9600);  // host
  gsm.begin(9600);     // SIM800 auto-bauds; 9600 is reliable with SoftwareSerial
}

void loop() {
  while (Serial.available()) gsm.write(Serial.read());
  while (gsm.available()) Serial.write(gsm.read());
}
