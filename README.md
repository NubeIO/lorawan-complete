# LoRaWAN Server + Gateway install scripts

#### TODO

- build gateways into docker images?

### About

- **Chirpstack LoRaWAN Server (Dockerised)**
- **LoRaWAN Gateway (Optional)**

Automated LoRaWAN Server and Gateway installation.  
Dockerised server [Chirpstack-Docker](https://github.com/brocaar/chirpstack-docker)  
Server and Gateway can be installed separately

#### Gateways:
- Rak gateway [rak_common_for_gateway](https://github.com/RAKWireless/rak_common_for_gateway).  
- PicoCell gateway [Lora-net](https://github.com/Lora-net/picoGW_packet_forwarder)
  
## Installation

**Note:** 
- if installting both gateway and server it is recommended to install gateway first as it will
be automatically added to the server afterwards.
- Postgres and Redis latest have errors on arm so this requires manually built docker images of older versions.
### Gateway
```
sudo bash install-gateway.sh
```
- `-h` for help

### Server
1. download the redis and postgres local docker images and copy them to the [docker-build/](docker-build/) folder (`postgres-local.tar` & `redis-local.tar`)
2. install with command:
    ```
    sudo bash install-server.sh
    ```
    (this will take a few minutes to complete)
    - `-h` for help

### Uninstalling

(can be ran while it's running)  
```
sudo bash uninstall-gateway.sh
``` 
or
```
sudo bash uninstall-server.sh
``` 
## Usage

### Stopping / Starting

#### System services enabled:

**Server service**  
- Start: `sudo service lorawan-server start`  
- Stop: `sudo service lorawan-server stop`  

**Gateway service**  
- Start: `sudo service lorawan-gateway start`  
- Stop: `sudo service lorawan-gateway stop`  

#### System services NOT enabled:

**Start**: `sudo ./start.sh`  
**Stop**: `sudo ./stop.sh`  

---
## (LEGACY) Building (Only required for chirpstack updates and not installing on devices)

**THIS WAS RELEVENT BEFORE CHIRPSTACK PROVIDED DOCKER IMAGES FOR ARM**  

Since [Chirpstack-Docker](https://github.com/brocaar/chirpstack-docker) currently doesn't support arm, the docker images must be built manually.  
This must be done on a seperate system as the build process is too large for an RPi.  
  
[chirpstack-docker-build.sh](docker-build/chirpstack-docker-build.sh) handles this process (run from inside the [docker-build/](docker-build/) directory).  
  
This pulls the required chirpstack service repos and performs the docker build with currently experimental build features.  
3 `.tar` files will be produced and should stay in the [docker-build/](docker-build/) directory to be installed on the target
- chirpstack-network-server
- chirpstack-application-server
- chirpstack-gateway-bridge
  
**Build process will take several minutes to complete, potentially over 30 minutes**

#### Prerequisites
- Docker v19.03 or higher
- git
  
#### Configuration
Can be tweaked inside [chirpstack-docker-build.sh](docker-build/chirpstack-docker-build.sh)
  
from [qemu-user-static](https://github.com/multiarch/qemu-user-static#getting-started)
- `BUILD_ARCH="arm32v7"` | `BUILD_ARCH="arm64v7"`
- `BUILD_OS="debian"`
  
from [buildx](https://docs.docker.com/buildx/working-with-buildx/)
- `BUILD_PLATFORM="linux/arm/v7"` | `BUILD_PLATFORM="linux/arm64/v7"`
  
[install.sh](install.sh) `BUILD_ARCH=` needs to match the above `BUILD_ARCH`


## Info on Repo

**TODO:** slightly out of date.

* `docker-build/`: folder to build and contain docker images
* `configuration/chirpstack*`: directory containing the ChirpStack configuration files, see:
    * https://www.chirpstack.io/gateway-bridge/install/config/
    * https://www.chirpstack.io/network-server/install/config/
    * https://www.chirpstack.io/application-server/install/config/
* `configuration/postgresql/initdb/`: directory containing PostgreSQL initialization scripts
* `systemd/`: systemd service files for startup (gets edited by install script to change absolute paths)
* `docker-compose.yml`: the docker-compose file containing the services (edited to utilise local chirpstack images)
* `docker-compose-env.yml`: alternate docker-compose file using environment variables, can be run with the docker-compose `-f` flag (edited to utilise local chirpstack images)
* `install.sh`: install script for target (RPi). Installs all dependencies too
* `uninstall.sh`: uninstall script for target (RPi). Removes startup service, all Chirpstack application data and docker containers/images
* `start.sh`: starts gateway and server. Used by startup service
* `stop.sh`: stops gateway and server. Used by startup service
* `chirpstack-app-init.py`: initialises Chirpstack application data. Takes 1 argument to set the gateway EUI
* `chirpstack-app-wipe.py`: wipes all Chirpstack application data (including devices)
* `chirpstack-app-device-profiles.py`: adds device profiles located in init data directory. filenames can be provided for specifics or none to add all
* `init_data/init_data.TEMPLATE.json`: example json file to add devices at install time. (copy to init_data.json and edit to use) (Not used anymore. Potentially removing completely)
* `init_data/resources/`: folders and files containing reusable init data
