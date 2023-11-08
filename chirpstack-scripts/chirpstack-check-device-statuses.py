import argparse
import requests
import datetime
import pytz

parser = argparse.ArgumentParser()
parser.add_argument('-a', '--address', metavar='address', type=str,
                    help='Server address')
parser.add_argument('-u', '--username', metavar='username', type=str,
                    help='Server username', default='admin')
parser.add_argument('-p', '--password', metavar='password', type=str,
                    help='Server password')
parser.add_argument('-t', '--token', metavar='token', type=str,
                    help='Server password')
parser.add_argument('-o', '--timeout', metavar='timeout', type=int,
                    help='Device timeout period in minutes', default=30)
parser.add_argument('-r', '--rssi', metavar='rssi', type=int,
                    help='Device RSSI threshold', default=-110)
parser.add_argument('-s', '--snr', metavar='snr', type=int,
                    help='Device SNR threshold', default=-5)

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

dev_seen_count = 0
dev_active_count = 0
tz = pytz.timezone("UTC")
time_now = datetime.datetime.now(tz)

inactives = []
bad_signals = []

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

        lsa = dev['lastSeenAt']
        if lsa is not None:
            dev_seen_count += 1
            lsa = pytz.utc.localize(
                datetime.datetime.strptime(lsa, '%Y-%m-%dT%H:%M:%S.%fZ'))
            diff = time_now - lsa
            if diff.total_seconds() < args.timeout * 60:
                dev_active_count += 1
            else:
                inactives.append(
                    f'Inactive device: {dev["devEUI"]}, {round(diff.total_seconds()/60)} minutes ago - {dev["name"]}')

        time_now_str = datetime.datetime.strftime(
            time_now, '%Y-%m-%dT%H:%M:%S.%fZ')
        resp = requests.get(f'http://{args.address}/api/devices/{dev["devEUI"]}/stats',
                            headers={
                                'Grpc-Metadata-Authorization': f'Bearer {token}'},
                            params={'interval': 'day',
                                    'startTimestamp': time_now_str,
                                    'endTimestamp': time_now_str}
                            )
        if resp.status_code < 200 or resp.status_code >= 300:
            print("GET device stats failure - StatusCode: ", resp.status_code)
            exit(1)
        device_stats = resp.json()['result'][0]
        if device_stats["gwRssi"] < args.rssi and device_stats["gwSnr"] < args.snr:
            bad_signals.append(
                f'Bad device signal: {dev["devEUI"]}, RSSI={round(device_stats["gwRssi"])}, SNR={round(device_stats["gwSnr"])} - {dev["name"]}')


for dev in inactives:
    print(dev)
print()
for dev in bad_signals:
    print(dev)
print()
print(f'total devices seen:   {dev_seen_count}')
print(
    f'total devices active: {dev_active_count}, ({dev_seen_count - dev_active_count} inactive)')
