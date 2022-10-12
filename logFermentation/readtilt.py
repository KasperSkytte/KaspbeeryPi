#!/usr/bin/env python3
import blescan
import bluetooth._bluetooth as bluez
from interruptingcow import timeout

def readtilt(
  tilt_id = "a495bb30c5b14b44b5121370f02d74de",
  bt_timeout = 20,
  tilt_sg_slope = 1,
  tilt_sg_offset = 0,
  tilt_tempC_offset = 0
):
  """Read temperature (celcius) and SG from a Tilt via BLE

  Args:
      tilt_id (str, optional): Tilt ID. Defaults to "a495bb30c5b14b44b5121370f02d74de".
      bt_timeout (int, optional): Timeout before giving up reading BLE. Defaults to 20.
      tilt_sg_slope (int, optional): Multiply the obtained SG value by this factor for calibration. Defaults to 1.
      tilt_sg_offset (int, optional): Add this value to the obtained SG for calibration. Defaults to 0.
      tilt_tempC_offset (int, optional): Add this value to the obtained temperature (celcius). Defaults to 0.

  Returns:
      _type_: tiltSG, tiltTempC
  """
  try:
    with timeout(bt_timeout, exception=RuntimeError):
      sock = bluez.hci_open_dev(0)
      blescan.hci_le_set_scan_parameters(sock)
      blescan.hci_enable_le_scan(sock)
      gotData = 0
      while (gotData == 0):
        returnedList = blescan.parse_events(sock, 10)
        for beacon in returnedList: #returnedList is a list datatype of string datatypes seperated by commas (,)
          output = beacon.split(',') #split the list into individual strings in an array
          if output[1] == tilt_id:
            tempf = float(output[2])
            gotData = 1
            tiltSG = round(int(output[3])*float(tilt_sg_slope)+float(tilt_sg_offset))
            tiltTempC = round((tempf-32)/1.8, 3)+float(tilt_tempC_offset)
      pass
  except RuntimeError:
    print("Could not connect to Tilt for " + str(bt_timeout) + " seconds...")
    tiltSG = 0
    tiltTempC = 0
  blescan.hci_disable_le_scan(sock)
  return tiltSG, tiltTempC

if __name__ == "__main__":
  from datetime import datetime
  import vars
  time = datetime.now().strftime("%Y-%b-%d %H:%M")
  print("\n *** " + time + " ***")
  tiltSG, tiltTempC = readtilt(
    tilt_id = vars.tilt_id,
    bt_timeout = 20,
    tilt_sg_slope = vars.tilt_sg_slope,
    tilt_sg_offset = vars.tilt_sg_offset,
    tilt_tempC_offset = vars.tilt_tempC_offset
  )
  print(
    "Tilt tempC (offset: " +
    str(vars.tilt_tempC_offset) +
    "): " +
    str(tiltTempC) +
    "\nTilt SG (SG offset: " +
    str(vars.tilt_sg_offset) +
    ", SG slope: " +
    str(vars.tilt_sg_slope) +
    "): " +
    str(tiltSG)
  )
  print("-------------------------\n")
