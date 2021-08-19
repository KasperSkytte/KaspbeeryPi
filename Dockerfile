FROM python:3.7-slim-buster

WORKDIR /kaspbeerypi

#default options for readsensors.py
ENV tiltID="a495bb30c5b14b44b5121370f02d74de" \
  tilt_sg_adjust=0 \
  dropbox_token="" \
  read_interval=5 \
  dropbox_folder="data" \
  TZ="Europe/Copenhagen" \
  LANG="C.UTF-8" \
  LC_ALL="C.UTF-8" \
  PYTHONDONTWRITEBYTECODE=1 \
  PYTHONFAULTHANDLER=1 \
  DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
  apt-get -y install --no-install-recommends --no-install-suggests \
    gcc \
    python3-pip \
    bluez \
    libbluetooth-dev

RUN python -m pip install --upgrade pip && \
  pip3 install \
    dropbox==11.16.0 \
    interruptingcow==0.8 \
    w1thermsensor==2.0.0 \
    pybluez==0.23 \
    scrollphathd==1.3.0 \
    schedule==1.1.0

COPY blescan.py readsensors.py scrollit.py ./

VOLUME /data
WORKDIR /data

ENTRYPOINT ["python", "/kaspbeerypi/scrollit.py"]
ENTRYPOINT ["python", "/kaspbeerypi/readsensors.py"]