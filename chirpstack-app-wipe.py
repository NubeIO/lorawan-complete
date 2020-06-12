import requests

##login
resp = requests.post('http://127.0.0.1:8080/api/internal/login',
    json={'email':'admin','password':'admin'},
)
if resp.status_code < 200 or resp.status_code >= 300:
  print "Login Failure - StatusCode: ", resp.status_code
  exit(1)
jwt = resp.json()['jwt']


##devices
resp = requests.get('http://127.0.0.1:8080/api/devices',
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
    params={'limit':50}
)
for x in resp.json()['result']:
  print 'Deleting Device '+x['devEUI']
  requests.delete('http://127.0.0.1:8080/api/devices/'+x['devEUI'],
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt}
  )


##device profiles
resp = requests.get('http://127.0.0.1:8080/api/device-profiles',
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
    params={'limit':10}
)
for x in resp.json()['result']:
  print 'Deleting Application '+x['id']
  requests.delete('http://127.0.0.1:8080/api/device-profiles/'+x['id'],
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt}
  )


##applications
resp = requests.get('http://127.0.0.1:8080/api/applications',
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
    params={'limit':10}
)
for x in resp.json()['result']:
  print 'Deleting Application '+x['id']
  requests.delete('http://127.0.0.1:8080/api/applications/'+x['id'],
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt}
  )


##gateways
resp = requests.get('http://127.0.0.1:8080/api/gateways',
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
    params={'limit':10}
)
for x in resp.json()['result']:
  print 'Deleting Gateway '+x['id']
  requests.delete('http://127.0.0.1:8080/api/gateways/'+x['id'],
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt}
  )


##service profiles
resp = requests.get('http://127.0.0.1:8080/api/service-profiles',
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
    params={'limit':10}
)
for x in resp.json()['result']:
  print 'Deleting Service Profile '+x['id']
  requests.delete('http://127.0.0.1:8080/api/service-profiles/'+x['id'],
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt}
  )


##gateway profiles
resp = requests.get('http://127.0.0.1:8080/api/gateway-profiles',
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
    params={'limit':10}
)
for x in resp.json()['result']:
  print 'Deleting Gateway Profile '+x['id']
  requests.delete('http://127.0.0.1:8080/api/gateway-profiles/'+x['id'],
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt}
  )


##network servers
resp = requests.get('http://127.0.0.1:8080/api/network-servers',
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt},
    params={'limit':10}
)
for x in resp.json()['result']:
  print 'Deleting Network Server '+x['id']
  requests.delete('http://127.0.0.1:8080/api/network-servers/'+x['id'],
    headers={'Grpc-Metadata-Authorization': 'Bearer '+jwt}
  )
