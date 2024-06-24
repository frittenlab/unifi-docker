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

# Install common dependencies
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

# Install MongoDB
curl -o libssl1.1_1.1.1f-1ubuntu2_arm64.deb https://unipig.de/apt/libssl1.1_1.1.1f-1ubuntu2_arm64.deb && dpkg -i libssl1.1_1.1.1f-1ubuntu2_arm64.deb && rm libssl1.1_1.1.1f-1ubuntu2_arm64.deb
curl -o libstdc++6.deb https://unipig.de/apt/libstdc%2B%2B6.deb && dpkg -i libstdc++6.deb && rm libstdc++6.deb
curl -o mongodb-server.deb https://unipig.de/apt/mongodb-server.deb && dpkg -i mongodb-server.deb

# Configure UniFi Repo
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
