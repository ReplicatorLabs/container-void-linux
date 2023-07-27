#!/bin/bash

# http://smarden.org/runit/
# https://docs.docker.com/config/containers/multi-service_container/
# https://gist.github.com/CMCDragonkai/e2cde09b688170fb84268cafe7a2b509

# XXX: just use runit-init as the entrypoint once the bug referenced below
# is fixed and it can cleanly quit inside containers
# http://skarnet.org/lists/supervision/2644.html

# prevent failed globs from working at all in loops
# https://www.shellcheck.net/wiki/SC2045
shopt -s nullglob

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
    kill -TERM "$(jobs -p)" 2>/dev/null || true
}

trap 'exit' INT QUIT TERM
trap 'cleanup' EXIT

# start all enabled services
for SVDIR in /run/runit/runsvdir/current/*; do
    SERVICE=$(basename "$SVDIR")

    echo "Start service: $SERVICE"
    runsv "$SVDIR" &
done

##
# Foreground
##

# wait for any background process to exit
echo "Running until process exit..."
wait -n
