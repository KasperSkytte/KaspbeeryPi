<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/kasperskytte/kaspbeerypi/workflows/R-CMD-check/badge.svg)](https://github.com/kasperskytte/kaspbeerypi/actions)
<!-- badges: end -->

# KaspbeeryPi
Live logging of the fermentation of my home brewed beer using the Raspberry Pi Zero W. Logs the readings of multiple DS18B20 digital thermometers through the 1-Wire interface as well as the specific gravity using the [Tilt hydrometer](https://tilthydrometer.com/) through Bluetooth. Data is uploaded to dropbox with every reading (default every 15 minutes), where a Shiny app can then grab it for plotty plots.

The micro SD card in my Raspberry Pi Zero W just burned out and I had to set up everything again from scratch. This time I chose to use Ansible to be prepared for the next time this happens. Use what you can, this repo is mainly for my future self to note down wtf I did back then!

Shiny app is live for demo, see [https://apps.cafekapper.dk/kaspbeerypi/](https://apps.cafekapper.dk/kaspbeerypi/).

## Installation
### Dropbox app
Head to [DBX Platform](https://www.dropbox.com/developers) to create a Dropbox app where the data will be saved. Note down the token and key+secret.

### Logging on the Raspberry Pi Zero W
 - Enable 1-wire interface either from `raspi-config` or by adding a line with `dtoverlay=w1-gpio` to `/boot/config.txt`.
 - Adjust the variables in `ansible_vars.yml` and run the playbook with your inventory:

```
ansible-playbook playbook.yml
```

#### Tilt gravity calibration
The Tilt gravity reading can be calibrated by a slope and offset. When changing battery the weight of the battery might be different and this is necessary. I did some tests when changing battery and figured out that it seems to be a linear model between the raw uncalibrated value and the adjusted value with hydrometer according to the Tilt android app. When changing battery it will automatically calibrate to 1000 if you place it in plain water immediately (if not adjust the `tilt_sg_offset` variable) after changing the battery, but the cal/uncal ratio/scale needs to be calibrated with a hydrometer. Make a few measurements, preferably with high gravity and dilute a few times. Plot the points of uncal+cal value from the Tilt app and make a linear trend in whatever program.

### Running the Shiny app for displaying the logged data
Run the Shiny app by either hosting it on [https://shinyapps.io](https://shinyapps.io), run a Shiny server yourself through Docker with fx the [rocker/shiny](`https://hub.docker.com/r/rocker/shiny`) images, or just from within RStudio locally. The Shiny app is bundled as an R package using [`{golem}`](https://thinkr-open.github.io/golem/index.html), install with:

```
install.packages("remotes")
remotes::install_github("kasperskytte/kaspbeerypi", Ncpus = 4)
```

If you run the app non-interactively you will have to authenticate using `token <- rdrop2::drop_auth(key, secret)` on a different machine and save the token to a `rds` file with `saveRDS(token, file = "token.rds")` and transfer the file to the server. Make sure the path to the file in `app.R` is correct.

To start the app run `kaspbeerypi::run_app()`. 

The app will synchronize with the chosen folder on Dropbox based on content hashes and store and load the data locally. This is faster than having to download everything with every launch, and all the logs from finished brews will likely never change again, only the most recent, and maybe still active, will. The file `names.csv` must be created and stored alongside all the individual logs files in the same folder. What's in this file is ultimately deciding what's shown in the app and is also where the brews can be named. See example: [/data/names.csv](https://github.com/KasperSkytte/kaspbeerypi/blob/main/data/names.csv).

### Scroll text on the [Scroll pHAT HD](https://learn.pimoroni.com/scroll-phat-hd) from Pimoroni
 - Enable I2C interface through `raspi-config`

# To-do
 - Use Google Drive instead of Dropbox to be able to edit names.csv more easily from browser
 - Implement relay for controlling kegerator
 - Display example console output in readme + picture of setup
 - Shiny app should save data to a tmp folder, not the app folder itself. Right now have to do a chmod 777 for it to work, not ideal.

# Notes to self
 - The version of wpa_supplicant that comes with Raspbian Buster does not work with eduroam WiFi networks. Either [downgrade wpa_supplicant](https://medium.com/good-robot/connect-your-raspberry-pi-to-eduroam-special-instructions-for-raspbian-buster-dfd536003999) or install Raspbian Stretch, last image is available [here](https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-04-09/).

 - add "static domain_name_servers=1.1.1.1 1.0.0.1" to /etc/dhcpcd.conf when connecting from AAU network and connecting to VPN. The DNS servers retrieved from DHCP before VPN is established are unavailable outside AAU network.
