import sys
import json
import requests
from os import walk
from os.path import join

path = 'init_data/resources/device_profiles'

# get gw_eui
filenames = []
if len(sys.argv) > 1:
    filenames.extend(sys.argv[1:])
else:
    _, _, filenames=next(walk(path), (None, None, []))


# login
resp=requests.post('http://127.0.0.1:8080/api/internal/login',
                     json={'email': 'admin', 'password': 'admin'},
                     )
if resp.status_code < 200 or resp.status_code >= 300:
    print "Login Failure - StatusCode: ", resp.status_code
    exit(1)
jwt=resp.json()['jwt']

# network server id
resp=requests.get('http://127.0.0.1:8080/api/network-servers?limit=1',
                     headers={
                         'Grpc-Metadata-Authorization': 'Bearer '+jwt},
                     )
if resp.status_code < 200 or resp.status_code >= 300:
    print "Network Server GET Failure - StatusCode: ", resp.status_code
    exit(1)
ns_id=resp.json()['result'][0]['id']

# org id
resp=requests.get('http://127.0.0.1:8080/api/organizations?limit=1',
                     headers={
                         'Grpc-Metadata-Authorization': 'Bearer '+jwt},
                     )
if resp.status_code < 200 or resp.status_code >= 300:
    print "Organisation GET Failure - StatusCode: ", resp.status_code
    exit(1)
org_id=resp.json()['result'][0]['id']

# device data
for file in filenames:
    try:
        with open(join(path, file)) as json_file:
            d=json.load(json_file)

            d['deviceProfile']['networkServerID']=ns_id
            d['deviceProfile']['organizationID']=org_id

            resp=requests.post('http://127.0.0.1:8080/api/device-profiles',
                                    headers={
                                        'Grpc-Metadata-Authorization': 'Bearer '+jwt},
                                    json=d
                                    )
            if resp.status_code < 200 or resp.status_code >= 300:
                print "POST Device Profile Failure - StatusCode: ", resp.status_code
                print resp.json()
            else:
                print "added device profile " + d['deviceProfile']['name']

    except IOError:
        print "No init data provided with init_data.json"
