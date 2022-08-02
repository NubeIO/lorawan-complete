import argparse
import json
import requests

parser = argparse.ArgumentParser()
parser.add_argument('-i', metavar='host', type=str,
                    help='Server')
parser.add_argument('-u', metavar='username', type=str,
                    help='Username', default='admin')
parser.add_argument('-p', metavar='password', type=str,
                    help='password', default='admin')
parser.add_argument('-t', metavar='token', type=str,
                    help='Server token')
parser.add_argument('-f', metavar='filename', type=str,
                    help='Device dump JSON file')
parser.add_argument('-k', metavar='key', type=str,
                    help='New key')
parser.add_argument('profiles', type=str, nargs='*',
                    help='Device Profiles to replace in format old-name:new-name')

args = parser.parse_args()

url = args.i
jwt = args.t
filename = args.f
key = args.k


replace_profiles = {}
for pair in args.profiles:
    split = pair.split(':')
    if len(split) != 2:
        print('ERROR: invalid profile pair ', pair)
        exit(1)
    replace_profiles[split[0]] = {
        'name': split[1],
        'id': ''
    }

if not jwt:
    # login
    resp = requests.post(f'http://{url}/api/internal/login',
                         json={'email': args.u, 'password': args.p},
                         )
    if resp.status_code < 200 or resp.status_code >= 300:
        print("Login Failure - StatusCode: ", resp.status_code, resp.text)
        exit(1)
    jwt = resp.json()['jwt']

# get applications
resp = requests.get(f'http://{url}/api/applications',
                    headers={'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                    params={'limit': 200}
                    )
if resp.status_code < 200 or resp.status_code >= 300:
    print("Get Applications Failure - StatusCode: ", resp.status_code, resp.text)
    exit(1)
appID = resp.json()['result'][0]['id']

# get device profiles
resp = requests.get(f'http://{url}/api/device-profiles',
                    headers={'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                    params={'limit': 200}
                    )
if resp.status_code < 200 or resp.status_code >= 300:
    print('Get Device Profiles Failure - StatusCode: ', resp.status_code, resp.text)
    exit(1)
profiles = resp.json()['result']
for prof in profiles:
    for rep_prof in replace_profiles:
        if replace_profiles[rep_prof]['name'] == prof['name']:
            replace_profiles[rep_prof]['id'] = prof['id']
            break

for rep_prof in replace_profiles:
    if replace_profiles[rep_prof]['id'] == '':
        print('ERROR: profile not found ', rep_prof, replace_profiles[rep_prof])
        exit(1)

devices = []
with open(filename) as file:
    devices = json.load(file)

key_pl = {
    "deviceKeys": {
        "appKey": key,
        "nwkKey": key,
        "genAppKey": ""
    }
}

for dev in devices:
    devPID = ''
    if dev['deviceProfileName'] in replace_profiles:
        devPID = replace_profiles[dev['deviceProfileName']]['id']
    else:
        for prof in profiles:
            if prof['name'] == dev['deviceProfileName']:
                devPID = prof['id']
                break

    new_dev = {
        'device': {
            'name': dev['name'],
            'devEUI': dev['devEUI'],
            'description': dev['description'],
            'applicationID': appID,
            'deviceProfileID': devPID,
            'skipFCntCheck': True
        }
    }

    resp = requests.post(f'http://{url}/api/devices',
                         headers={'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                         json=new_dev)
    if resp.status_code < 200 or resp.status_code >= 300:
        print('POST Device Failure - StatusCode: ', resp.status_code, resp.text)
        continue
    print('Created device: ', new_dev['device']['name'], new_dev['device']['devEUI'])

    new_key_pl = key_pl
    if 'deviceKeys' in dev:
        new_key_pl = {'deviceKeys': dev['deviceKeys']}
    resp = requests.post(f'http://{url}/api/devices/{dev["devEUI"]}/keys',
                         headers={'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                         json=new_key_pl)
    if resp.status_code < 200 or resp.status_code >= 300:
        print('POST Device Key Failure - StatusCode: ', resp.status_code, resp.text)
        continue
