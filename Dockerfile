FROM alpine:3.6

ENV RANCHER_CLI_VERSION v0.6.2
ENV GOCRON_VERSION v0.0.2
ENV GOMPLATE_VERSION v1.9.1

RUN apk add --no-cache --update coreutils curl docker jq

RUN curl -sSL https://github.com/rancher/cli/releases/download/${RANCHER_CLI_VERSION}/rancher-linux-amd64-${RANCHER_CLI_VERSION}.tar.gz | tar xvz -C /tmp && \
    mv /tmp/rancher-${RANCHER_CLI_VERSION}/rancher /usr/local/bin/rancher && \
    chmod +x /usr/local/bin/rancher
RUN curl -sL https://github.com/michaloo/go-cron/releases/download/${GOCRON_VERSION}/go-cron.tar.gz | tar -x -C /usr/local/bin
RUN curl -sL -o /usr/local/bin/gomplate https://github.com/hairyhenderson/gomplate/releases/download/${GOMPLATE_VERSION}/gomplate_linux-amd64-slim && \
    chmod +x /usr/local/bin/gomplate

ADD . /backup-agent

WORKDIR /backup-agent

ENTRYPOINT /backup-agent/entrypoint.sh
