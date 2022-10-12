#!/usr/bin/env python3
import scrollphathd as sphd
import sys
import time
import schedule

def scroll_string(
  string = "hi",
  speed = 0.001,
  brightness = 0.3
):
  """Scroll a string on the phat display

  Args:
      string (str, optional): String to display. Defaults to "hi".
      speed (float, optional): Speed of the scroll in seconds. Defaults to 0.001.
      brightness
  """
  string = str(string)
  sphd.clear()
  length = sphd.write_string(string)
  sphd.write_string(string, brightness = brightness)
  sphd.show()
  for str_pos in range(length):
    sphd.scroll(1)
    sphd.show()
    time.sleep(speed)

def clearphat():
  """Clears phat display and exits"""
  print("Stopping by keyboard interrupt...")
  sphd.clear()
  sphd.write_string("Bye", brightness = 0.5)
  sphd.show()
  time.sleep(2)
  sphd.clear()
  sys.exit(-1)

if __name__ == "__main__":
  from readtilt import readtilt
  from read1wire import read1wire
  import vars
  try:
    while True:
      string = str()
      tiltSG, tiltTempC = readtilt(
        tilt_id = vars.tilt_id,
        bt_timeout = 20,
        tilt_sg_slope = vars.tilt_sg_slope,
        tilt_sg_offset = vars.tilt_sg_offset,
        tilt_tempC_offset = vars.tilt_tempC_offset
      )
      if tiltSG == 0:
        tiltSG = "N/A"
      string = string + "     SG: " + str(tiltSG)
      if tiltTempC == 0:
        tiltTempC = "N/A"
      string = string + "    TempC: " + str(tiltTempC)
      for probe in read1wire():
        string = string + "    " + probe[0] + ": " + probe[1]
      print(string)
      scroll_string(string)
  except KeyboardInterrupt:
    clearphat()
