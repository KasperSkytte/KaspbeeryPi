# KaspbeeryPi
Live logging of the fermentation of my home brewed beer using the Raspberry Pi Zero W. Logs the readings of multiple DS18B20 digital thermometers through the 1-Wire interface as well as the specific gravity using the [Tilt hydrometer](https://tilthydrometer.com/) through Bluetooth. Data is uploaded to dropbox with every reading (default every 5 minutes), where a Shiny app can then grab it for plotty plots.

The micro SD card in my Raspberry Pi Zero W just burned out and I had to set up everything again from scratch. This time I chose Docker to be prepared for the next time this happens. Use what you can, this repo is mainly for my future self to note down wtf I did back then!

Shiny app is live for demo, see [https://kasperskytte.shinyapps.io/KaspbeeryPi/](https://kasperskytte.shinyapps.io/KaspbeeryPi/).

## Installation
### Dropbox app
Head to [DBX Platform](https://www.dropbox.com/developers) to create a Dropbox app where the data will be saved. Note down the token and secret.

### Logging on the Raspberry Pi Zero W
 - Enable 1-wire interface either from `raspi-config` or by adding a line with `dtoverlay=w1-gpio` to `/boot/config.txt`.
 - Install Docker with `sudo curl -sL get.docker.com | bash` and preferably also [docker-compose](https://docs.docker.com/compose/install/).

The Docker installation will likely error as the CPU on the Pi Zero W is old and requires an older version of `containerd` to be supported. In that case downgrade containerd by running the following:
```
wget https://packagecloud.io/Hypriot/rpi/packages/raspbian/buster/containerd.io_1.2.6-1_armhf.deb/download.deb
sudo dpkg -i download.deb
sudo rm download.deb
sudo systemctl restart docker
```

### Running the Shiny app for displaying the logged data
Run the Shiny app by either hosting it on [https://shinyapps.io](https://shinyapps.io), run a Shiny server yourself through Docker with fx the [rocker/shiny](`https://hub.docker.com/r/rocker/shiny`) images, or just from within RStudio locally. Use [renv](https://rstudio.github.io/renv/) and the `renv.lock` file to use the exact same R version and packages as me to make sure it works properly. If you run the app non-interactively you will have to authenticate using `token <- rdrop2::drop_auth(key, secret)` on a different machine and save the token to a `rds` file with `saveRDS(token, file = "token.rds")` and transfer the file to the server. Make sure the path to the file in `app.R` is correct.

### Scroll text on the [Scroll pHAT HD](https://learn.pimoroni.com/scroll-phat-hd) from Pimoroni
 - Enable I2C interface through `raspi-config`
 - Start container with either `--privileged`, or expose only the particular device with `--device /dev/i2c-1`

## How to run
Optionally build the docker container image first with `docker build -t kasperskytte/kaspbeerypi:latest .`, otherwise pull and start the container and start logging fermentation with:

### docker-compose
```
---
version: "3.5"
services:
  kaspbeerypi:
    image: kasperskytte/kaspbeerypi:latest
    container_name: kaspbeerypi
    environment:
      - TZ="Europe/Copenhagen"
      - dropbox_token="pasteyourdropboxtokenhere"
      - dropbox_folder="data" \
      - tilt_id="a495bb30c5b14b44b5121370f02d74de"
      - tilt_sg_adjust=0
      - read_interval=5
    devices:
      - /dev/i2c-1
    network_mode: "host"
    restart: unless-stopped
```

### Docker CLI
```
docker run \
  -d \
  --name readsensors \
  --net=host \
  --restart unless-stopped \
  -e TZ="Europe/Copenhagen" \
  -e dropbox_token="pasteyourdropboxtokenhere" \
  -e dropbox_folder="data" \
  -e tilt_id="a495bb30c5b14b44b5121370f02d74de" \
  -e tilt_sg_adjust=0 \
  -e read_interval=5 \
  kasperskytte/kaspbeerypi:latest
```

Setting the restart policy to `unless-stopped` makes it automatically start logging with every boot, which is handy when running in headless mode.
A few options as well as the dropbox token are set using the following environment variables (adjust with `-e key=value`):

| Variable | Description |
| --- | --- |
| TZ | Time zone, fx "Europe/London" |
| dropbox_token | The Dropbox token to the Dropbox app |
| dropbox_folder | Subfolder inside the Dropbox app folder where data will be stored |
| tilt_id | ID of the Tilt hydrometer, default is the black version |
| tilt_sg_adjust | Add an integer to the Tilt gravity reading for calibration. This is useful when changing the battery as its weight can be slightly different compared to the stock battery. |
| read_interval | Time in minutes between reading sensors and tilt |

By default a volume named `/data` is used to store the data until restart/reboot. If you want the data to be persistently stored locally on the Pi, just mount `/data` in the container to somewhere on the host. The data is continuously being uploaded to dropbox with every read, but if there is no internet connection for the entire duration, nothing will be backed up on dropbox, so in this case it's nice to save things locally.

# To-do
Data format has changed, the Shiny app cannot load it at the moment. Need to adjust to new format, right now it's expecting only one file.