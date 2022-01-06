#!/usr/bin/env python3
from w1thermsensor import W1ThermSensor
import scrollphathd as sphd
import sys
import time
from subprocess import check_output
import re

def scroll_string(string, speed = 0.001):
    string = str(string)
    sphd.clear()
    length = sphd.write_string(string)
    sphd.write_string(string, brightness = 0.5)
    sphd.show()
    for str_pos in range(length):
        sphd.scroll(1)
        sphd.show()
        time.sleep(speed)

def CtrlC():
  print("Stopping by keyboard interrupt...")
  sphd.clear()
  sphd.write_string("Bye", brightness = 0.5)
  sphd.show()
  time.sleep(2)
  sphd.clear()
  sys.exit(-1)

try:
  while True:
      string = str()
      for sensor in W1ThermSensor.get_available_sensors():
        try:
          string = string+"    Probe%s: %.2f" % (sensor.id[0:2], sensor.get_temperature())
        except:
          string = string
      try:
        string = "     IP: "+re.search("[0-9]*\\.[0-9]*\\.[0-9]*\\.[0-9]*", str(check_output(['hostname', '-I']))).group()+string
      except:
        string = "     IP: N/A"+string
      scroll_string(string)
except KeyboardInterrupt:
  CtrlC()
