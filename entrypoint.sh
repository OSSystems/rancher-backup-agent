#!/bin/sh

# Gets a list of containers labeled with "br.com.ossystems.rancher.backup.driver"
# The list of returned container objects has the following format:
#
# {
#   id: <container-id>,
#   ip: <container-ip-address>,
#   name: <container-name>,
#   driver: <value-of-br.com.ossystems.rancher.backup.driver>,
#   env: <container-environment-variables>,
#   labels: <container-labels>,
#   schedule: <cron-schedule-line>
# }
get_containers() {
    rancher ps -c --format json | \
        jq -r -f filters/get_containers.jq | \
        jq -r -f filters/create_container_object.jq
}

# Register storage service
mc config host add s3 $S3_URL $S3_ACCESS_KEY $S3_SECRET_KEY

export RANCHER_ACCESS_KEY=$CATTLE_ACCESS_KEY
export RANCHER_SECRET_KEY=$CATTLE_SECRET_KEY
export RANCHER_URL=$CATTLE_URL

# Cache the results
CONTAINERS=$(get_containers)

for ID in $(echo "${CONTAINERS}" | jq -r '.id'); do
    CONTAINER=$(echo "${CONTAINERS}" | jq -r "select(.id == \"${ID}\")")
    DRIVER=$(echo "${CONTAINER}" | jq -r "select(.id == \"${ID}\") | .driver")
    IP=$(echo "${CONTAINER}" | jq -r "select(.id == \"${ID}\") | .ip")
    NAME=$(echo "${CONTAINER}" | jq -r "select(.id == \"${ID}\") | .name")
    SCHEDULE=$(echo "${CONTAINER}" | jq -r "select(.id == \"${ID}\") | .schedule")

    # Environment variables which will be interpolated in driver template
    ENVIRONMENT="ID='${ID}' IP='${IP}' NAME='${NAME}' SCHEDULE='${SCHEDULE}'"
    for ENV in $(echo $CONTAINER | jq -r ".env | to_entries[] | .key"); do
        ENVIRONMENT="$ENVIRONMENT $ENV=$(echo $CONTAINER | jq -r ".env[\"${ENV}\"]")"
    done

    for LABEL in $(echo $CONTAINER | jq -r ".labels | to_entries[] | .key"); do
        echo "${LABEL}" | grep -q -v -F "br.com.ossystems.rancher.backup.${DRIVER}." && continue
        VAR=$(echo "${LABEL}" | sed "s,br.com.ossystems.rancher.backup.${DRIVER}.,,g")
        ENVIRONMENT="$ENVIRONMENT $VAR=$(echo $CONTAINER | jq -r ".labels[\"${LABEL}\"]")"
    done

    [ ! -f drivers/${DRIVER}/config ] && continue

    PLAN_DIR=/data/plans/${ID}
    mkdir -p ${PLAN_DIR}

    CONFIG=$(mktemp)
    sh -c "${ENVIRONMENT} gomplate -f drivers/${DRIVER}/config" > $CONFIG

    if [ -f ${PLAN_DIR}/config ]; then
        if [ "$(cat ${PLAN_DIR}/config | md5sum)" != "$(cat ${CONFIG} | md5sum)" ]; then
            echo "Configuration for ${ID} has changed"

            # Cancel old backup process
            PID=$(cat ${PLAN_DIR}/pid)
            [ -e /proc/${PID} ] && kill ${PID}
        fi
    fi

    mv ${CONFIG} ${PLAN_DIR}/config

    PLAN_DIR="${PLAN_DIR}" go-cron "${SCHEDULE}" ./dump.sh &
    echo $! > ${PLAN_DIR}/pid
done

sleep 999999
