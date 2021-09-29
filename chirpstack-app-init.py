import sys
import argparse
import json
import requests
from os import walk
from os.path import join

parser = argparse.ArgumentParser()
parser.add_argument('-g', metavar='eui', type=str,
                    help='Gateway EUI')
parser.add_argument('-r', metavar='region', type=str,
                    help='Gateway region (i.e. au915)')
parser.add_argument('-b', metavar='band', type=int,
                    help='Gateway band (i.e. 0)')
parser.add_argument('-p', metavar='password', type=str,
                    help='Server password')

args = parser.parse_args()

gw_eui = args.g
gw_region = args.r
gw_band = args.b
password = args.p

if gw_eui is not None or gw_region is not None or gw_band is not None:
    if gw_eui is None or gw_region is None or gw_band is None:
        print("Error: Missing gateway arguments!")
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
gateway_profiles = {}
gwp_id = None
try:
    path = 'init-data/gateway-profiles'
    _, _, filenames = next(walk(path), (None, None, []))
    for file in filenames:
        f_split = file.split('.')
        if len(f_split) != 3:
            print("Gateway profile file with invalid name: " + file)
        try:
            with open(join(path, file)) as json_file:
                d = json.load(json_file)
                d['gatewayProfile']['networkServerID'] = '' + nw_id

                resp = requests.post('http://127.0.0.1:8080/api/gateway-profiles',
                                     headers={
                                         'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                                     json=d
                                     )
                if resp.status_code < 200 or resp.status_code >= 300:
                    print("POST Gateway Profile Failure - StatusCode: ",
                          resp.status_code)
                    print(resp.json())
                else:
                    print("Added gateway profile " +
                          d['gatewayProfile']['name'])
                    gateway_profiles[d['gatewayProfile']['name']] = resp.json()[
                        'id']
                    if gw_region == f_split[0] and str(gw_band) == f_split[1]:
                        gwp_id = resp.json()['id']

        except:
            print('Error adding gateway profile', file)

except IOError:
    print("No gateway profiles to add")


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
if gateway_profiles and gw_eui != None and gwp_id != None:
    resp = requests.post('http://127.0.0.1:8080/api/gateways',
                         headers={
                             'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                         json={"gateway": {
                             "description": "default gateway",
                             "discoveryEnabled": False,
                             "gatewayProfileID": ""+gwp_id,
                             "name": "default-gateway",
                             "id": gw_eui,
                             "networkServerID": ""+nw_id,
                             "organizationID": ""+org_id,
                             "serviceProfileID": ""+sp_id,
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
    path = 'init-data/device-profiles'
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

# user password
if password is not None:
    resp = requests.put('http://127.0.0.1:8080/api/users/1/password',
                        headers={
                            'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                        json={
                            "password": password
                        }
                        )
    if resp.status_code < 200 or resp.status_code >= 300:
        print("PUT Password Failure - StatusCode: ", resp.status_code)
        exit(1)
    print('User password updated')

print('Data initialisation done')
