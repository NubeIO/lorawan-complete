#!/bin/bash

docker build --file gateway-decoder/Dockerfile --tag lorawan_gateway_test .
docker save -o lorawan_gateway_test.tar lorawan_gateway_test
zip -r lorawan_gateway_test.zip lorawan_gateway_test.tar
rm lorawan_gateway_test.tar

echo ""
du -h lorawan_gateway_test.zip
echo "Done."