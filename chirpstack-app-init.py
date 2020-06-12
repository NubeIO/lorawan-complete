import sys
import json
import requests

#get gw_eui
gw_eui = None
if len(sys.argv) == 2:
  gw_eui = sys.argv[1]

##login
resp = requests.post('http://127.0.0.1:8080/api/internal/login',
  json={'email':'admin','password':'admin'},
)
if resp.status_code < 200 or resp.status_code >= 300:
  print "Login Failure - StatusCode: ", resp.status_code
  exit(1)
jwt = resp.json()['jwt']


##get Org Id
resp = requests.get('http://127.0.0.1:8080/api/organizations',
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
    params={'limit':10}
)
if resp.status_code < 200 or resp.status_code >= 300:
  print "Get Org Failure - StatusCode: ", resp.status_code
  exit(1)
org_id = resp.json()['result'][0]['id']
print 'Organization ID: '+org_id

##network server
resp = requests.post('http://127.0.0.1:8080/api/network-servers',
  headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
  json={"networkServer": {
    "name": "local-network-server",
    "server": "chirpstack-network-server:8000"
  }}
)
if resp.status_code < 200 or resp.status_code >= 300:
  print "POST Network Server Failure - StatusCode: ", resp.status_code
  exit(1)
nw_id = resp.json()['id']
print 'Network Server ID: '+nw_id

##gateway profile
resp = requests.post('http://127.0.0.1:8080/api/gateway-profiles',
  headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
  json={"gatewayProfile": {
    "channels": [
      0, 1, 2, 3, 4, 5, 6, 7, 64
    ],
    "name": "local-gateway-profile",
    "networkServerID": ""+nw_id
  }}
)
gwp_id = None
if resp.status_code < 200 or resp.status_code >= 300:
  print "POST Gateway Profile Failure - StatusCode: ", resp.status_code
else:
  gwp_id = resp.json()['id']
  print 'Gateway Profile ID: '+gwp_id


##service profile
resp = requests.post('http://127.0.0.1:8080/api/service-profiles',
  headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
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
  print "POST Service Profile Failure - StatusCode: ", resp.status_code
  exit(1)
sp_id = resp.json()['id']
print 'Service Profile ID: '+sp_id



##gateway
if gwp_id != None and gw_eui != None:
  resp = requests.post('http://127.0.0.1:8080/api/gateways',
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
    json={"gateway": {
      "description": "rak2247 USB PCIe w/ rak packet forwarder",
      "discoveryEnabled":False,
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
    print "POST Gateway Failure - StatusCode: ", resp.status_code
  print 'Local Gateway EUI: '+gw_eui
else:
  print 'No local gateway added'

##application
resp = requests.post('http://127.0.0.1:8080/api/applications',
  headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
  json={"application": {
    "description": "default-app",
    "name": "default-app",
    "organizationID": ""+org_id,
    "serviceProfileID": ""+sp_id
  }}
)
if resp.status_code < 200 or resp.status_code >= 300:
  print "POST Application Failure - StatusCode: ", resp.status_code
  exit(1)
app_id = resp.json()['id']
print 'App ID: '+app_id



#device data
device_profiles={}
with open('init_data/init_data.json') as json_file:
    init_data = json.load(json_file)
    
    #device profiles
    for d in init_data['device_profiles']:

      d['deviceProfile']['networkServerID'] = ''+nw_id
      d['deviceProfile']['organizationID'] = ''+org_id

      resp = requests.post('http://127.0.0.1:8080/api/device-profiles',
        headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
        json=d
      )
      if resp.status_code < 200 or resp.status_code >= 300:
        print "POST Device Profile Failure - StatusCode: ", resp.status_code
        print resp.json()
      else:
        print "added device profile \"" + d['deviceProfile']['name'] + "\""
        device_profiles[d['deviceProfile']['name']] = resp.json()['id']

    #devices
    for d in init_data['devices']:


      d['device']['applicationID'] = ''+app_id
      d['device']['deviceProfileID'] = device_profiles[d['device']['deviceProfileID']]
      
      resp = requests.post('http://127.0.0.1:8080/api/devices',
        headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
        json={'device': d['device']}
      )
      if resp.status_code < 200 or resp.status_code >= 300:
        print "POST Device Failure - StatusCode: ", resp.status_code
        print resp.json()
      else:
        d['deviceKeys']['nwkKey'] = d['deviceKeys']['appKey']

        resp = requests.post('http://127.0.0.1:8080/api/devices/'+d['device']['devEUI']+'/keys',
          headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
          json={'deviceKeys': d['deviceKeys']}
        )
        if resp.status_code < 200 or resp.status_code >= 300:
          print "POST Device Keys Failure - StatusCode: ", resp.status_code
          print resp.json
        else:
          print "added device \"" + d['device']['name'] + "\" - " + d['device']['devEUI']
