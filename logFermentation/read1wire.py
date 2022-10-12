#!/usr/bin/env python3
from w1thermsensor import W1ThermSensor

#read 1-wire thermometers
def read1wire():
  readings = []
  for sensor in W1ThermSensor.get_available_sensors():
    id = "Probe"+str(sensor.id)[0:2]
    temp = round(sensor.get_temperature(), 3)
    readings.append([id, str(temp)])
  return readings

if __name__ == "__main__":
  from datetime import datetime
  time = datetime.now().strftime("%Y-%b-%d %H:%M")
  print("\n *** " + time + " ***")
  for probe in read1wire():
    print(probe[0] + ": " + probe[1])
  print("-------------------------\n")
