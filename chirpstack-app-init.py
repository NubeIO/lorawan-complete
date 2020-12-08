import sys
import json
import requests
from os import walk
from os.path import join

# get gw_eui and band channels
gw_eui = None
channels = None
if len(sys.argv) == 3:
    gw_eui = sys.argv[1]
    channel_band = sys.argv[2]
else:
    print('no GW EUI and channel band provided')
    exit(1)

if channel_band == '0':
    channels = [0, 1, 2, 3, 4, 5, 6, 7, 64]
elif channel_band == '1':
    channels = [8, 9, 10, 11, 12, 13, 14, 15, 65]
else:
    print('Channel band not supported')
    exit(1)

# login
resp = requests.post('http://127.0.0.1:8080/api/internal/login',
                     json={'email': 'admin', 'password': 'admin'},
                     )
if resp.status_code < 200 or resp.status_code >= 300:
    print("Login Failure - StatusCode: ", resp.status_code)
    exit(1)
jwt = resp.json()['jwt']


# get Org Id
resp = requests.get('http://127.0.0.1:8080/api/organizations',
                    headers={'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                    params={'limit': 10}
                    )
if resp.status_code < 200 or resp.status_code >= 300:
    print("Get Org Failure - StatusCode: ", resp.status_code)
    exit(1)
org_id = resp.json()['result'][0]['id']
print('Organization ID: ' + org_id)

# network server
resp = requests.post('http://127.0.0.1:8080/api/network-servers',
                     headers={'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                     json={"networkServer": {
                         "name": "local-network-server",
                         "server": "chirpstack-network-server:8000"
                     }}
                     )
if resp.status_code < 200 or resp.status_code >= 300:
    print("POST Network Server Failure - StatusCode: ", resp.status_code)
    exit(1)
nw_id = resp.json()['id']
print('Network Server ID: ' + nw_id)

# gateway profile
resp = requests.post('http://127.0.0.1:8080/api/gateway-profiles',
                     headers={'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                     json={"gatewayProfile": {
                         "channels": channels,
                         "name": "local-gateway-profile",
                         "networkServerID": ""+nw_id
                     }}
                     )
gwp_id = None
if resp.status_code < 200 or resp.status_code >= 300:
    print("POST Gateway Profile Failure - StatusCode: ", resp.status_code)
else:
    gwp_id = resp.json()['id']
    print('Gateway Profile ID: ' + gwp_id)


# service profile
resp = requests.post('http://127.0.0.1:8080/api/service-profiles',
                     headers={'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                     json={"serviceProfile": {
                         "addGWMetaData": True,
                         "name": "local-service-profile-default",
                         "networkServerID": ""+nw_id,
                         "nwkGeoLoc": False,
                         "reportDevStatusBattery": False,
                         "reportDevStatusMargin": False,
                         "organizationID": ""+org_id
                     }}
                     )
if resp.status_code < 200 or resp.status_code >= 300:
    print("POST Service Profile Failure - StatusCode: ", resp.status_code)
    exit(1)
sp_id = resp.json()['id']
print('Service Profile ID: ' + sp_id)


# gateway
if gwp_id != None and gw_eui != None:
    resp = requests.post('http://127.0.0.1:8080/api/gateways',
                         headers={
                             'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                         json={"gateway": {
                             "description": "rak2247 USB PCIe w/ rak packet forwarder",
                             "discoveryEnabled": False,
                             "gatewayProfileID": ""+gwp_id,
                             "name": "local-rak-gateway",
                             "id": gw_eui,
                             "networkServerID": ""+nw_id,
                             "organizationID": ""+org_id,
                             "location": {
                                 "accuracy": 0,
                                 "altitude": 0,
                                 "latitude": 0,
                                 "longitude": 0,
                                 "source": "UNKNOWN"
                             }
                         }}
                         )
    if resp.status_code < 200 or resp.status_code >= 300:
        print("POST Gateway Failure - StatusCode: ", resp.status_code)
    print('Local Gateway EUI: ' + gw_eui)
else:
    print('No local gateway added')

# application
resp = requests.post('http://127.0.0.1:8080/api/applications',
                     headers={'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                     json={"application": {
                         "description": "default-app",
                         "name": "default-app",
                         "organizationID": ""+org_id,
                         "serviceProfileID": ""+sp_id
                     }}
                     )
if resp.status_code < 200 or resp.status_code >= 300:
    print("POST Application Failure - StatusCode: ", resp.status_code)
    exit(1)
app_id = resp.json()['id']
print('App ID: ' + app_id)


# device data
device_profiles = {}
try:
    path = 'init_data/resources/device_profiles'
    _, _, filenames = next(walk(path), (None, None, []))
    for file in filenames:
        try:
            with open(join(path, file)) as json_file:
                d = json.load(json_file)
                d['deviceProfile']['networkServerID'] = '' + nw_id
                d['deviceProfile']['organizationID'] = '' + org_id

                resp = requests.post('http://127.0.0.1:8080/api/device-profiles',
                                     headers={
                                         'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                                     json=d
                                     )
                if resp.status_code < 200 or resp.status_code >= 300:
                    print("POST Device Profile Failure - StatusCode: ",
                          resp.status_code)
                    print(resp.json())
                else:
                    print("Added device profile " + d['deviceProfile']['name'])
                    device_profiles[d['deviceProfile']['name']] = resp.json()[
                        'id']
        except:
            print('Error adding device profile', file)

except IOError:
    print("No init data provided with init_data.json")
