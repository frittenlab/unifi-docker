#!/usr/bin/env bash

# fail on error
set -e

# Retry 5 times with a wait of 10 seconds between each retry
tryfail() {
    for i in $(seq 1 5);
        do [ $i -gt 1 ] && sleep 10; $* && s=0 && break || s=$?; done;
    (exit $s)
}

if [ "x${1}" == "x" ]; then
    echo please pass PKGURL as an environment variable
    exit 0
fi

apt-get update
apt-get install -qy --no-install-recommends \
    apt-transport-https \
    dirmngr \
    gpg \
    curl \
    gpg-agent \
    openjdk-17-jre-headless \
    procps \
    libcap2-bin \
    tzdata

# Add MongoDB Key & Repo
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg -o /etc/apt/keyrings/mongodb-server-7.0.gpg --dearmor

echo 'deb [ arch=amd64,arm64 signed-by=/etc/apt/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse' | tee /etc/apt/sources.list.d/mongodb-org-7.0.list

apt-get update
apt-get install -qy --no-install-recommends \
    mongodb-org-server \
    mongodb-org-shell \
    mongodb-org-tools \
    mongodb-org-mongos \
    mongodb-mongosh \
    mongodb-org-database

curl -fsSL https://dl.ui.com/unifi/unifi-repo.gpg -o /etc/apt/keyrings/unifi-repo.gpg

echo 'deb  [ arch=amd64,arm64 signed-by=/etc/apt/keyrings/unifi-repo.gpg ] https://www.ui.com/downloads/unifi/debian stable ubiquiti' | tee /etc/apt/sources.list.d/unifi.list

if [ -d "/usr/local/docker/pre_build/$(dpkg --print-architecture)" ]; then
    find "/usr/local/docker/pre_build/$(dpkg --print-architecture)" -type f -exec '{}' \;
fi

curl -L -o ./unifi.deb "${1}"
apt -qy install ./unifi.deb
rm -f ./unifi.deb
chown -R unifi:unifi /usr/lib/unifi
rm -rf /var/lib/apt/lists/*

rm -rf ${ODATADIR} ${OLOGDIR} ${ORUNDIR} ${BASEDIR}/data ${BASEDIR}/run ${BASEDIR}/logs
mkdir -p ${DATADIR} ${LOGDIR} ${RUNDIR}
ln -s ${DATADIR} ${BASEDIR}/data
ln -s ${RUNDIR} ${BASEDIR}/run
ln -s ${LOGDIR} ${BASEDIR}/logs
ln -s ${DATADIR} ${ODATADIR}
ln -s ${LOGDIR} ${OLOGDIR}
ln -s ${RUNDIR} ${ORUNDIR}
mkdir -p /var/cert ${CERTDIR}
ln -s ${CERTDIR} /var/cert/unifi

rm -rf "${0}"

ln -s /var/lib/mongodb /unifi/data/db
ln -s /var/log/mongodb/mongod.log /unifi/log/mongod.log
