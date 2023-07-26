#!/bin/bash

# http://smarden.org/runit/
# https://docs.docker.com/config/containers/multi-service_container/
# https://gist.github.com/CMCDragonkai/e2cde09b688170fb84268cafe7a2b509

# XXX: just use runit-init as the entrypoint once the bug referenced below
# is fixed and it can cleanly quit inside containers
# http://skarnet.org/lists/supervision/2644.html

##
# Services
##

# link current service directory into /run/runit/runsvdir
mkdir -p /run/runit/runsvdir
rm -rf /run/runit/runsvdir/current
ln -sf /etc/runit/runsvdir/current /run/runit/runsvdir/current

# kill all child processes when any signal is received
cleanup () {
    echo "Terminate all processes..."
    # shellcheck disable=SC2046
    kill -TERM $(jobs -p) 2>/dev/null || true
}

trap 'exit' INT QUIT TERM
trap 'cleanup' EXIT

# start runit service as a child process
start_service () {
    NAME="$1"
    SVDIR="/run/runit/runsvdir/current/${NAME}"

    # http://smarden.org/runit/runsv.8.html
    echo "Start service: $NAME"
    runsv "$SVDIR" &
}

# wait for network port in listening state
wait_port_listen () {
    PORT="$1"

    printf "Wait for port ${PORT} "
    while [ "$(ss -H state listening sport = $PORT | wc -l)" -eq 0 ]; do
        sleep 1
        printf "."
    done
    printf "\n"
}

# TODO: start services here

##
# Foreground
##

# wait for any background process to exit
echo "Running until process exit..."
wait -n
