FROM python:3.7-slim-buster

WORKDIR /kaspbeerypi

#default options for readsensors.py
ENV tiltID="a495bb30c5b14b44b5121370f02d74de"
ENV dropbox_token=""
ENV read_interval=5
ENV dropbox_folder="data"

# locales
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

#stop Python from generating .pyc files
ENV PYTHONDONTWRITEBYTECODE 1

#enable Python tracebacks on segfaults
ENV PYTHONFAULTHANDLER 1

#update system
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
  apt-get -y install --no-install-recommends --no-install-suggests \
    gcc \
    python3-pip \
    bluez \
    libbluetooth-dev

RUN python -m pip install --upgrade pip && \
  pip3 install pipenv==2021.5.29

COPY Pipfile Pipfile.lock ./
RUN pipenv install --python /usr/local/bin/python --deploy --system

COPY blescan.py readsensors.py scrollit.py ./

VOLUME /data
WORKDIR /data

ENTRYPOINT ["python", "/kaspbeerypi/readsensors.py"]
