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
                    help='Token')
args = parser.parse_args()

url = args.i
jwt = args.t

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
appliations = resp.json()['result']

devices = []
for app in appliations:
    resp = requests.get(f'http://{url}/api/devices',
                        headers={'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                        params={'limit': 200,
                                'applicationID': app['id']}
                        )
    if resp.status_code < 200 or resp.status_code >= 300:
        print("Get Applications Failure - StatusCode: ", resp.status_code, resp.text)
        exit(1)
    new_devs = resp.json()['result']
    for dev in new_devs:
        devices.append(dev)

for dev in new_devs:
    resp = requests.get(f'http://{url}/api/devices/{dev["devEUI"]}/keys',
                        headers={'Grpc-Metadata-Authorization': 'Bearer ' + jwt},
                        )
    if resp.status_code < 200 or resp.status_code >= 300:
        continue
    dev['deviceKeys'] = resp.json()['deviceKeys']

print(json.dumps(devices, indent=2))
