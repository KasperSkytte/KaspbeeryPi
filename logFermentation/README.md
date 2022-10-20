# logFermentation
Python scripts to read data from Tilt and DS18B20 temperature probes. Writes to a local CSV file and uploads it to Dropbox as well as a Brewfather custom URL webhook. I currently use a PiZeroW with a scroll phat hd display to show the readings as well. Ansible playbook to install dependencies and contents of this folder is also available.

## Protect SD card
```
sudo dphys-swapfile swapoff
sudo dphys-swapfile uninstall
sudo update-rc.d dphys-swapfile remove
sudo apt purge dphys-swapfile
sudo apt-get install busybox-syslogd
sudo apt-get remove --purge rsyslog
sudo apt-get remove --purge logrotate triggerhappy samba-common #removing fake-hwclock and cron will mess up time sync
sudo apt-get autoremove
```