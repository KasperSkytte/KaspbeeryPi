#!/usr/bin/env python3
import csv
import sys
from datetime import datetime
import dropbox
from dropbox.files import WriteMode
import schedule
import requests
from read1wire import read1wire
from readtilt import readtilt
import vars

#create a new filename with the current time as unique identifier
filename = datetime.now().strftime("%Y%m%d_%H%M%S") + ".csv"

#function to post to BrewFather API
def postBrewfather(
  json,
  brewfatherCustomStreamURL = vars.brewfatherCustomStreamURL
):
  """Post JSON to a BrewFather custom stream URL

  Args:
      json (dictionary): Dictionary to be posted as JSON 
      brewfatherCustomStreamURL (string): BrewFather custom stream URL. Defaults to vars.brewfatherCustomStreamURL.
  """  
  try:
    post = requests.post(brewfatherCustomStreamURL, json = json)
    print(post.text)
  except Exception as err:
    print("Failed to upload to BrewFather:\n%s" % err)

def upload_dropbox(
  filename,
  dropbox_token = vars.dropbox_token,
  dropbox_folder = vars.dropbox_folder
):
  """Upload file to a Dropbox APP

  Args:
      filename (string): Path to file
      dropbox_token (string): Dropbox token. Defaults to vars.dropbox_token.
      dropbox_folder (string): Folder in which to upload the file. Defaults to vars.dropbox_folder.
  """  
  try:
    dbx = dropbox.Dropbox(dropbox_token)
    with open(filename, "rb+") as file:
      dbx.files_upload(
        file.read(),
        "/" + dropbox_folder + "/" + filename,
        mode=WriteMode("overwrite"),
        mute=True
      )
  except Exception as err:
    print("Failed to upload file to dropbox:\n%s" % err)

def main():
  readings = []
  #timestamp when reading sensors
  time = datetime.now().strftime("%Y-%b-%d %H:%M")
  
  #print time stamp
  print(" *** " + time + " ***")
  
  #read Tilt SG+temp
  tiltSG, tiltTempC = readtilt(
    tilt_id = vars.tilt_id,
    bt_timeout = 20,
    tilt_sg_slope = vars.tilt_sg_slope,
    tilt_sg_offset = vars.tilt_sg_offset,
    tilt_tempC_offset = vars.tilt_tempC_offset
  )
  
  #post Tilt SG+temp to BrewFather
  if tiltSG != 0 and tiltTempC != 0:
    readings.append([str(time), "tiltSG", str(tiltSG)])
    readings.append([str(time), "tiltTempC", str(tiltTempC)])
    
    #print Tilt readings
    print(
      "Tilt tempC (offset: " +
      str(vars.tilt_tempC_offset) +
      "): " +
      str(tiltTempC)
    )
    print(
      "Tilt SG (SG offset: " +
      str(vars.tilt_sg_offset) +
      ", SG slope: " +
      str(vars.tilt_sg_slope) +
      "): " +
      str(tiltSG)
    )
    
    #post Tilt readings to BrewFather
    tiltJSON = {
      "name": "Tilt",
      "temp": tiltTempC,
      "gravity": tiltSG/1000,
      "gravity_unit": "G",
      "comment": "ID: " + vars.tilt_id + " (SG offset: " + str(vars.tilt_sg_offset) + ", SG slope: " + str(vars.tilt_sg_slope) + ", tempC offset: " + str(vars.tilt_tempC_offset) + ")"
    }
    postBrewfather(tiltJSON)

  #read 1wire probes and upload
  probesJSON = {
    "name": "Probes",
    "temp_unit": "C",
    "comment": "Temp: Probe03, Room Temp: Probe05, Fridge Temp: Probe04",
  }

  for probe in read1wire():
    #append to the right BrewFather entry
    if probe[0] == "Probe03":
      probesJSON["temp"] = str(probe[1])
    elif probe[0] == "Probe04":
      probesJSON["aux_temp"] = str(probe[1])
    elif probe[0] == "Probe05":
      probesJSON["ext_temp"] = str(probe[1])
    
    #print probe readings  
    print(probe[0] + ": " + str(probe[1]))
    
    #post to BrewFather
    postBrewfather(probesJSON)
    readings.append([str(time), str(probe[0]), str(probe[1])])

  #tidy console output in blocks for each timestamp
  print("-------------------------\n")

  #write to local CSV file
  with open(filename, "a") as file:
    writer = csv.writer(file, quoting=csv.QUOTE_ALL)
    writer.writerows(readings)

  #upload CSV file to dropbox app folder
  upload_dropbox(
    filename = filename,
    dropbox_token = vars.dropbox_token,
    dropbox_folder = vars.dropbox_folder
  )

if __name__ == "__main__":
  # Schedule to run with every chosen interval
  schedule.every(vars.read_interval).minutes.do(main)

  try:
    while True:
      schedule.run_pending()
  except KeyboardInterrupt:
    print("Stopping by keyboard interrupt...")
    sys.exit(-1)
