#!/bin/sh

yaml_to_json() {
    local tmpfile=$(mktemp --suffix .yaml)

    echo "$*" > $tmpfile
    echo "{{ datasource \"tmpfile\" | toJSON }}" | gomplate -f - -d tmpfile=file://${tmpfile}; rm -f $tmpfile
}

CONFIG=$(yaml_to_json "$(cat $PLAN_DIR/config)")
CONFIG_KEYS=$(echo "${CONFIG}" | jq -r 'to_entries[] | .key')

for KEY in $CONFIG_KEYS; do
    VAR=$(echo "${KEY}" |  tr '[:lower:]' '[:upper:]')

    eval "$VAR"=$(echo "${CONFIG}" | jq -r ".${KEY} // empty")
    export "${VAR}"
done

docker pull ${IMAGE}

DUMP_SCRIPT=$(mktemp -p /data)
gomplate -f drivers/${DRIVER}/dump > ${DUMP_SCRIPT}
chmod +x ${DUMP_SCRIPT}

DUMP_FILE="/data/dumps/${NAME}_$(date +%s%N)"

mkdir -p /data/dumps

docker run \
       --rm \
       -v /data/dumps:/data/dumps \
       -v ${DUMP_SCRIPT}:/usr/local/bin/dump \
       -e DUMP_FILE="${DUMP_FILE}" \
       --entrypoint /usr/local/bin/dump ${IMAGE}

rm -f ${DUMP_SCRIPT}

[ -f "${DUMP_FILE}" ] && mc --quiet cp ${DUMP_FILE} s3/${S3_BUCKET}
