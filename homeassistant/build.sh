#!/bin/bash

HA_LATEST=true
DOCKER_IMAGE_NAME="192.168.10.119:5000/home-assistant"
PYTHON_OPENZWAVE_VERSION=$(curl -L -s 'https://raw.githubusercontent.com/home-assistant/home-assistant/dev/requirements_all.txt' | grep python\_openzwave\=\=)
log() {
   now=$(date +"%Y%m%d-%H%M%S")
   echo "$now - $*" >> docker-build.log
}

log ">>--------------------->>"

## #####################################################################
## Home Assistant version
## #####################################################################
if [ "$1" != "" ]; then
   # Provided as an argument
   HA_VERSION=$1
   log "Docker image with Home Assistant $HA_VERSION"
else
   HA_VERSION="$(cat docker-build.version)"
   HA_VERSION="$(curl -s 'https://pypi.org/pypi/homeassistant/json' | jq '.info.version' | tr -d '"')"
   HA_LATEST=true
   log "Docker image with Home Assistant 'latest' (version $HA_VERSION)"
fi

## #####################################################################
## For hourly (not parameterized) builds (crontab)
## Do nothing: we're trying to build & push the same version again
## #####################################################################
if [ "$HA_LATEST" == true ] && [ "$HA_VERSION" == "$_HA_VERSION" ]; then
   log "Docker image with Home Assistant $HA_VERSION has already been built & pushed"
   log ">>--------------------->>"
   exit 0
fi


## #####################################################################
## Removing Deps folder to ensure the latest stuff gets installed
## #####################################################################
#sudo rm -rf homeassistant/configuration/deps/*

## #####################################################################
## Generate the start.sh script
## #####################################################################
cat << _EOF_ > start.sh
#!/bin/sh
set -e
echo "Updating locate DB"
updatedb
echo "Running Zwave setup"
/config/build/setupZW.sh
echo "Starting HA"
python3 -m homeassistant --config /config
exec "\$@"
_EOF_
## #####################################################################
## Generate the Dockerfile
## #####################################################################
cat << _EOF_ > Dockerfile
FROM homeassistant/home-assistant:latest
LABEL maintainer "Logan McKenna <https://github.com/1mckenna/>"

###################################
# Install Core System Utils
###################################
RUN apt-get update && \
	apt-get install -y mosquitto-clients
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
      build-essential python3-dev python3-pip python3-setuptools libcap2-bin\
      git libffi-dev libpython-dev libssl-dev \
      libgnutls28-dev libgnutlsxx28 \
      libudev-dev vim\
      bluetooth libbluetooth-dev \
      net-tools nmap \
      libmicrohttpd-dev \
      iputils-ping \
      locate \
      libmariadbclient-dev \
      ssh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###################################
# Mouting point for the user's configuration
###################################
VOLUME /config

###################################
# Install Home Assistant Additional Deps
###################################
RUN pip3 install aiohttp_cors websocket-client sqlalchemy mysqlclient pyRFXTRX cython wheel six 'PyDispatcher>=2.0.5' && pip3 uninstall -y python-openzwave

###################################
# Install Forked Branch of OpenZWave
###################################
RUN cd /root && \
	git clone https://github.com/bitdog-io/open-zwave.git && \
	cd open-zwave && \
	make
RUN export LOCAL_OPENZWAVE=/root/open-zwave && pip3 install --no-cache-dir 'python_openzwave' --install-option="--flavor=dev" -b /usr/local/lib/python3.6/site-packages/python_openzwave

###################################
# Add Start Script to Launch Services on Container Start
###################################
ADD start.sh /
RUN chmod +x /start.sh
CMD ["/start.sh"]
_EOF_

## #####################################################################
## Build the Docker image, tag and push to local registry
## #####################################################################
log "Building $DOCKER_IMAGE_NAME:$HA_VERSION"
## Force-pull the base image
docker pull homeassistant/home-assistant
docker build -t $DOCKER_IMAGE_NAME:$HA_VERSION .

log "Pushing $DOCKER_IMAGE_NAME:$HA_VERSION"
docker push $DOCKER_IMAGE_NAME:$HA_VERSION

if [ "$HA_LATEST" = true ]; then
   log "Tagging $DOCKER_IMAGE_NAME:$HA_VERSION with latest"
   docker tag $DOCKER_IMAGE_NAME:$HA_VERSION $DOCKER_IMAGE_NAME:latest
   log "Pushing $DOCKER_IMAGE_NAME:latest"
   docker push $DOCKER_IMAGE_NAME:latest
   echo $HA_VERSION > docker-build.version
   docker rmi -f $DOCKER_IMAGE_NAME:latest
fi

log ">>--------------------->>"
