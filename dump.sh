#!/bin/sh

yaml_to_json() {
    local tmpfile=$(mktemp --suffix .yaml)

    echo "$*" > $tmpfile
    echo "{{ datasource \"tmpfile\" | toJSON }}" | gomplate -f - -d tmpfile=file://${tmpfile}; rm -f $tmpfile
}

CONFIG=$(yaml_to_json "$(cat $PLAN_DIR/config)")
CONFIG_KEYS=$(echo "${CONFIG}" | jq -r 'to_entries[] | .key')

ENV_FILE=$(mktemp)

for KEY in $CONFIG_KEYS; do
    VAR=$(echo "${KEY}" |  tr '[:lower:]' '[:upper:]')

    eval "$VAR='$(echo "${CONFIG}" | jq -r ".${KEY} // empty")'"
    export "${VAR}"

    echo "$VAR=$(echo "${CONFIG}" | jq -r ".${KEY} // empty")" >> $ENV_FILE
done

docker pull ${IMAGE}

DUMP_SCRIPT=$(mktemp -p /data)
gomplate -f drivers/${DRIVER}/dump > ${DUMP_SCRIPT}
chmod +x ${DUMP_SCRIPT}

DUMP_ID="${NAME}_$(date +%s%N)"
DUMP_FILE="/data/dumps/${DUMP_ID}"

echo "DUMP_ID=${DUMP_ID}" >> $ENV_FILE
echo "DUMP_FILE=${DUMP_FILE}" >> $ENV_FILE

mkdir -p /data/dumps

docker run \
       --rm \
       -l io.rancher.container.network=true \
       --net=host \
       -v /data/dumps:/data/dumps \
       -v ${DUMP_SCRIPT}:/usr/local/bin/dump \
       --env-file "${ENV_FILE}" \
       --entrypoint /usr/local/bin/dump ${IMAGE}

rm -f ${DUMP_SCRIPT}
rm -f ${ENV_FILE}

[ -f "${DUMP_FILE}" ] && mc --quiet cp ${DUMP_FILE} s3/${S3_BUCKET}
[ -f "${DUMP_FILE}" ] && rm -rf ${DUMP_FILE}
