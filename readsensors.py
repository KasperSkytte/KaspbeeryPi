import blescan
import bluetooth._bluetooth as bluez
import csv
import dropbox
import sys
import os
import schedule
from dropbox.files import WriteMode
from interruptingcow import timeout
from w1thermsensor import W1ThermSensor
from datetime import datetime

#get options from system environment variables
tilt_id = str(os.environ.get("tilt_id"))
tilt_sg_adjust = int(os.environ.get("tilt_sg_adjust"))
read_interval = int(os.environ.get("read_interval"))
dropbox_token = str(os.environ.get("dropbox_token"))
dropbox_folder = str(os.environ.get("dropbox_folder"))

#create a new filename with the current time as unique identifier
filepath = datetime.now().strftime("%Y%m%d_%H%M%S") + ".csv"
readings = []

def readsensors():
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
          if output[1] == tilt_id: #Change this to the colour of you tilt
            tempf = float(output[2]) #convert the string for the temperature to a float type
            gotData = 1
            tiltSG = int(output[3])+tilt_sg_adjust
            tiltTempC = round((tempf-32)/1.8, 3)
      blescan.hci_disable_le_scan(sock)
      print("Tilt temp: "+str(tiltTempC)+"\nTilt SG: "+str(tiltSG))
      pass
  except RuntimeError:
    print("Could not connect to tilt for 20 seconds...")
  blescan.hci_disable_le_scan(sock)

  if gotData == 1:
    readings.append([str(time), "tiltSG", str(tiltSG)])
    readings.append([str(time), "tiltTempC", str(tiltTempC)])

  #read 1-wire thermometers
  for sensor in W1ThermSensor.get_available_sensors():
    id = "Probe"+str(sensor.id)[0:2]
    temp = str(round(sensor.get_temperature(), 3))
    print(id+": "+temp)
    readings.append([str(time), id, temp])

  #tidy console output in blocks for each timestamp
  print("-------------------------\n")
 
  #write to local file
  with open(filepath, "a") as file:
    writer = csv.writer(file, quoting=csv.QUOTE_ALL)
    writer.writerows(readings)

  #upload file to dropbox
  try:
    dbx = dropbox.Dropbox(dropbox_token)
    with open(filepath, "rb+") as file:
        dbx.files_upload(file.read(), "/" + dropbox_folder + "/" + filepath, mode=WriteMode("overwrite"), mute=True)
  except Exception as err:
    print("Failed to upload file to dropbox:\n%s" % err)

#run immediately
readsensors()
# and then schedule to run with every chosen interval
schedule.every(read_interval).minutes.do(readsensors)

try:
  while True:
    schedule.run_pending()
except KeyboardInterrupt:
  print("Stopping by keyboard interrupt...")
  sys.exit(-1)
