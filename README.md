# LoRaWAN Server + Gateway for RPi

#### TODO

- [ ] build rak gateway into docker image
- [ ] re-enable `tx_enable` in gateway config with new hardware
- [ ] pull only chirpstack `stable` from git to avoid another dreaded "username disaster"
- [ ] device keys POST API `nwkKey` seems to be the `appKey` - might change in future

### Solution

- **Chirpstack LoRaWAN Server (Dockerised)**
- **Rak Gateway (Optional)**

Cleaner, simpler dockerised (server for now) version of a complete gateway and server solution in comparison to using Rak's default gateway + server package [rak_common_for_gateway](https://github.com/RAKWireless/rak_common_for_gateway).  
  
Server is a clone of [Chirpstack-Docker](https://github.com/brocaar/chirpstack-docker) which currently does not support arm so is tweaked to be built for different architectures (default armv7) (idea taken from https://github.com/brocaar/chirpstack-docker/issues/19).  
Docker images must be built on a seperate system before installing on the RPi.  
  
Gateway is Rak software from [rak_common_for_gateway](https://github.com/RAKWireless/rak_common_for_gateway) (default to Rak2247 USB) which utilises [LoRa Gateway](https://github.com/Lora-net/lora_gateway) + [Lora Packet Forwarder](https://github.com/Lora-net/packet_forwarder.git) to form the complete gateway.  
  
Includes startup setup and automatic chirpstack server configuration.  
Only need to add `Device Profiles` and `Devices`.  

## Installation

**Assumes Chirpstack Docker images have been built for target architecture and tars reside in build/**  
  
1. Clone/Copy repo onto target system (RPi)
2. `sudo ./install.sh` (this will take a few minutes to complete)
    - `-h` for help
    - `-s` disable startup service
    - `-g` disable gateway install (install server only)
    - `-r` lorawan region specification (i.e. `au915` (default))
    - `-b` lorawan region band (i.e. `0` (default))
    - `-n` option to set the network interface (used for gateway EUI generation) (i.e. `sudo ./install.sh -n wlan0`)

## Usage

### Stopping / Starting

#### Startup service enabled

**Server service**  
- Start: `sudo service lorawan-server start`  
- Stop: `sudo service lorawan-server stop`  
**Gateway service**  
- Start: `sudo service lorawan-gateway start`  
- Stop: `sudo service lorawan-gateway stop`  

#### Manually

**Start**: `sudo ./start.sh`  
**Stop**: `sudo ./stop.sh`  


### Adding Devices

#### Pre-Installation

Can be added with JSON data.  
More options can be found at http://&lt;target_ip&gt;:8080/api/
1. Copy [init_data/init_data.TEMPLATE.json](init_data/init_data.TEMPLATE.json) to `init_data/init_data.json`
2. Fill out as needed
  
[init_data/resouces](init_data/resouces) contains reusable data such as Device Profiles to populate your `init_data.json`

#### Manually

Via the Web UI
1. http://&lt;target_ip&gt;:8080/ and login
2. Create `Device Profile` to match your LoRaWAN device settings
3. Create `Device` in `Applications`->`default-app` (pre created)

### Uninstalling

`sudo ./uninstall.sh` (can be ran while it's running too)

## Building (Only required for chirpstack updates and not installing on devices)

Since [Chirpstack-Docker](https://github.com/brocaar/chirpstack-docker) currently doesn't support arm, the docker images must be built manually.  
This must be done on a seperate system as the build process is too large for an RPi.  
  
[chirpstack-docker-build.sh](build/chirpstack-docker-build.sh) handles this process (run from inside the [build/](build/) directory).  
  
This pulls the required chirpstack service repos and performs the docker build with currently experimental build features.  
3 `.tar` files will be produced and should stay in the [build/](build/) directory to be installed on the target
- chirpstack-network-server
- chirpstack-application-server
- chirpstack-gateway-bridge
  
**Build process will take several minutes to complete, potentially over 30 minutes**

#### Prerequisites
- Docker v19.03 or higher
- git
  
#### Configuration
Can be tweaked inside [chirpstack-docker-build.sh](build/chirpstack-docker-build.sh)
  
from [qemu-user-static](https://github.com/multiarch/qemu-user-static#getting-started)
- `BUILD_ARCH="arm32v7"` | `BUILD_ARCH="arm64v7"`
- `BUILD_OS="debian"`
  
from [buildx](https://docs.docker.com/buildx/working-with-buildx/)
- `BUILD_PLATFORM="linux/arm/v7"` | `BUILD_PLATFORM="linux/arm64/v7"`
  
[install.sh](install.sh) `BUILD_ARCH=` needs to match the above `BUILD_ARCH`


## Info on Repo

* `build/`: folder to build and contain docker images
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
* `init_data/init_data.TEMPLATE.json`: example json file to add devices at install time. (copy to init_data.json and edit to use)
* `init_data/resources/`: folders and files containing reusable init data