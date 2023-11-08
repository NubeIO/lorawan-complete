import argparse
import json
import requests
from os import walk
from os.path import join

parser = argparse.ArgumentParser()
parser.add_argument('-a', '--address', metavar='address', type=str,
                    help='Server address')
parser.add_argument('-u', '--username', metavar='username', type=str,
                    help='Server username', default='admin')
parser.add_argument('-p', '--password', metavar='password', type=str,
                    help='Server password')
parser.add_argument('-t', '--token', metavar='token', type=str,
                    help='Server password')

args = parser.parse_args()
token = args.token


if args.address is None:
    print("Error: Please provide an address")
if args.password is None and token is None:
    print("Error: Please provide a password or token")

# login
if token is None:
    resp = requests.post(f'http://{args.address}/api/internal/login',
                         json={'email': 'admin', 'password': args.password},
                         )
    if resp.status_code < 200 or resp.status_code >= 300:
        print("Login Failure - StatusCode: ", resp.status_code)
        exit(1)
    token = resp.json()['jwt']


# get applications
resp = requests.get(f'http://{args.address}/api/applications',
                    headers={'Grpc-Metadata-Authorization': 'Bearer ' + token},
                    params={'limit': 200}
                    )
if resp.status_code < 200 or resp.status_code >= 300:
    print("Get Applications Failure - StatusCode: ", resp.status_code, resp.text)
    exit(1)
appliations = resp.json()['result']

for app in appliations:
    resp = requests.get(f'http://{args.address}/api/devices',
                        headers={
                            'Grpc-Metadata-Authorization': f'Bearer {token}'},
                        params={'limit': 1000,
                                'applicationID': app['id']}
                        )
    if resp.status_code < 200 or resp.status_code >= 300:
        print("GET devices failure - StatusCode: ", resp.status_code)
        exit(1)
    devices = resp.json()['result']

    for dev in devices:
        eui = dev['devEUI']
        print(f'del dev: {eui}')
        resp = requests.delete(f'http://{args.address}/api/devices/{eui}/activation',
                               headers={
                                   'Grpc-Metadata-Authorization': f'Bearer {token}'},
                               )
        if resp.status_code < 200 or resp.status_code >= 300:
            print(
                f'DELETE device activation failed - StatusCode: {resp.status_code}, devEUI: {eui}')

        resp = requests.delete(f'http://{args.address}/api/devices/{eui}/devnonce',
                               headers={
                                   'Grpc-Metadata-Authorization': f'Bearer {token}'},
                               )
        if resp.status_code < 200 or resp.status_code >= 300:
            print(
                f'DELETE device dev-nonce failed - StatusCode: {resp.status_code}, devEUI: {eui}')

print()
print('Done')
