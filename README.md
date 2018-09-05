# Various Build Script for Custom Docker Images
## Home Assistant
### Home Assistant Build Script utilizing a patched version of OpenZwave to add support for the Barrier Class


## My Docker Stack Setup
* OS: CentOS7
* Docker Container Management: Portainer (https://portainer.io/)
* Reverse Proxy/Load Balancing: Traefik (https://traefik.io/)
* Local Image Hosting: Docker Registry (https://docs.docker.com/registry/deploying/)
* Registry Browsing/Mangement: Docker Registry Frontend (https://hub.docker.com/r/konradkleine/docker-registry-frontend/)

## Home Assistant Docker Stack
* Home Assistant: Build in the homeassistant folder
* Database: MariaDB	(mariadb:latest)
* Time Series DB: InfluxDB (influxdb:latest)
* MQTT: Mosquitto (eclipse-mosquitto:latest)
* Data Visualization: 	Grafana (grafana/grafana:latest)
