#!/usr/bin/env python3
import blescan
import vars
import bluetooth._bluetooth as bluez
import csv
import dropbox
import sys
import os
import schedule
import requests
import json
from dropbox.files import WriteMode
from interruptingcow import timeout
from w1thermsensor import W1ThermSensor
from datetime import datetime

#create a new filename with the current time as unique identifier
filepath = datetime.now().strftime("%Y%m%d_%H%M%S") + ".csv"

#function to post to BrewFather API
def postBrewfather(json, brewfatherCustomStreamURL = vars.brewfatherCustomStreamURL):
  try:
    post = requests.post(brewfatherCustomStreamURL, json = json)
    print(post.text)
  except Exception as err:
    print("Failed to upload to BrewFather:\n%s" % err)

def readsensors():
  readings = []
  #timestamp when reading sensors
  time = datetime.now().strftime("%Y-%b-%d %H:%M")
  print(" *** " + time + " ***")

  #read tilt
  try:
    with timeout(20, exception=RuntimeError):
      sock = bluez.hci_open_dev(0)
      blescan.hci_le_set_scan_parameters(sock)
      blescan.hci_enable_le_scan(sock)
      gotData = 0
      while (gotData == 0):
        returnedList = blescan.parse_events(sock, 10)
        for beacon in returnedList: #returnedList is a list datatype of string datatypes seperated by commas (,)
          output = beacon.split(',') #split the list into individual strings in an array
          if output[1] == vars.tilt_id:
            tempf = float(output[2])
            gotData = 1
            tiltSG = round(int(output[3])*float(vars.tilt_sg_slope)+float(vars.tilt_sg_offset))
            tiltTempC = round((tempf-32)/1.8, 3)+float(vars.tilt_tempC_offset)
      blescan.hci_disable_le_scan(sock)
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
        str(tiltSG))
      pass
  except RuntimeError:
    print("Could not connect to Tilt for 20 seconds...")
  blescan.hci_disable_le_scan(sock)

  if gotData == 1:
    readings.append([str(time), "tiltSG", str(tiltSG)])
    readings.append([str(time), "tiltTempC", str(tiltTempC)])

    tiltJSON = {
      "name": "Tilt",
      "temp": tiltTempC,
      "gravity": tiltSG/1000,
      "gravity_unit": "G",
      "comment": "ID: " + vars.tilt_id + " (SG offset: " + str(vars.tilt_sg_offset) + ", SG slope: " + str(vars.tilt_sg_slope) + ", tempC offset: " + str(vars.tilt_tempC_offset) + ")"
    }
    postBrewfather(tiltJSON)

  #read 1-wire thermometers
  #JSON to post to BrewFather API
  probes = {
    "name": "Probes",
    "temp_unit": "C",
    "comment": "Temp: Probe03, Room Temp: Probe05, Fridge Temp: Probe04",
  }
  for sensor in W1ThermSensor.get_available_sensors():
    id = "Probe"+str(sensor.id)[0:2]
    temp = round(sensor.get_temperature(), 3)
    if id == "Probe03":
      probes["temp"] = temp
    elif id == "Probe04":
      probes["aux_temp"] = temp
    elif id == "Probe05":
      probes["ext_temp"] = temp
    print(id+": "+str(temp))

    postBrewfather(probes)
    readings.append([str(time), id, str(temp)])

  #tidy console output in blocks for each timestamp
  print("-------------------------\n")

  #write to local file
  with open(filepath, "a") as file:
    writer = csv.writer(file, quoting=csv.QUOTE_ALL)
    writer.writerows(readings)

  #upload file to dropbox
  try:
    dbx = dropbox.Dropbox(vars.dropbox_token)
    with open(filepath, "rb+") as file:
        dbx.files_upload(file.read(), "/" + vars.dropbox_folder + "/" + filepath, mode=WriteMode("overwrite"), mute=True)
  except Exception as err:
    print("Failed to upload file to dropbox:\n%s" % err)

# Schedule to run with every chosen interval
schedule.every(vars.read_interval).minutes.do(readsensors)

try:
  while True:
    schedule.run_pending()
except KeyboardInterrupt:
  print("Stopping by keyboard interrupt...")
  sys.exit(-1)
