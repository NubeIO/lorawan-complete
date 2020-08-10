import sys
import json
import requests

#get gw_eui
filename = None
if len(sys.argv) == 2:
  filename = sys.argv[1]
else:
  print 'no filename provided for the init_data/resources/device_profiles dir'
  exit(1)


##login
resp = requests.post('http://127.0.0.1:8080/api/internal/login',
  json={'email':'admin','password':'admin'},
)
if resp.status_code < 200 or resp.status_code >= 300:
  print "Login Failure - StatusCode: ", resp.status_code
  exit(1)
jwt = resp.json()['jwt']

#device data
device_profiles={}
try:
  with open('init_data/resources/device_profiles/'+filename) as json_file:
      init_data = json.load(json_file)
      
      #device profiles
      for d in init_data['device_profiles']:

        d['deviceProfile']['networkServerID'] = '1'
        d['deviceProfile']['organizationID'] = '1'

        resp = requests.post('http://127.0.0.1:8080/api/device-profiles',
          headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
          json=d
        )
        if resp.status_code < 200 or resp.status_code >= 300:
          print "POST Device Profile Failure - StatusCode: ", resp.status_code
          print resp.json()
        else:
          print "added device profile " + d['deviceProfile']['name']
          device_profiles[d['deviceProfile']['name']] = resp.json()['id']

except IOError:
  print "No init data provided with init_data.json"
