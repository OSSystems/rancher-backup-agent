#!/bin/sh

yaml_to_json() {
    local tmpfile=$(mktemp --suffix .yaml)

    echo "$*" > $tmpfile
    echo "{{ datasource \"tmpfile\" | toJSON }}" | gomplate -f - -d tmpfile=file://${tmpfile}; rm -f $tmpfile
}

CONFIG=$(yaml_to_json "$(cat $PLAN_DIR/config)")
ID=$(echo "${CONFIG}" | jq -r '.id')
IP=$(echo "${CONFIG}" | jq -r '.ip')
DRIVER=$(echo "${CONFIG}" | jq -r '.driver')
IMAGE=$(echo "${CONFIG}" | jq -r '.image')
USERNAME=$(echo "${CONFIG}" | jq -r '.username')
PASSWORD=$(echo "${CONFIG}" | jq -r '.password')

export ID
export IP
export USERNAME
export PASSWORD

docker pull ${IMAGE}

DUMP_SCRIPT=$(mktemp -p /data)
gomplate -f drivers/${DRIVER}/dump > ${DUMP_SCRIPT}
chmod +x ${DUMP_SCRIPT}

docker run \
       --rm \
       -v /data/dumps:/data/dumps \
       -v ${DUMP_SCRIPT}:/usr/local/bin/dump \
       --entrypoint /usr/local/bin/dump ${IMAGE}

rm -f ${DUMP_SCRIPT}
