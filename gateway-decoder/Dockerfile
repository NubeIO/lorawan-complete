# syntax=docker/dockerfile:1

FROM alpine AS lorawan_gateway_test

ENV DIRPATH=/lorawan-complete

WORKDIR ${DIRPATH}
COPY configuration ./configuration
COPY gateway-decoder ./gateway-decoder
COPY install-gateway-pico.sh ./
COPY start.sh ./
COPY gateway-decode.sh ./

RUN apk add --no-cache gcc make musl-dev udev bash
RUN apk add --no-cache wget jq unzip nodejs npm coreutils

# Gateways
RUN bash install-gateway-pico.sh -s

# NodeJs decoder deps
WORKDIR ${DIRPATH}/gateway-decoder
RUN npm install

WORKDIR ${DIRPATH}

# Cleanup
RUN apk del gcc make musl-dev wget jq unzip npm

# Entry Point
CMD [ "bash", "gateway-decode.sh" ]