#!/bin/bash

test -s /etc/docker/daemon.json || echo "{}" | sudo tee /etc/docker/daemon.json

jq '{} | .runtimes.runsc.path = "/commonShare/runsc"' /etc/docker/daemon.json | sudo sponge /etc/docker/daemon.json
jq '."default-runtime" = "runsc"' /etc/docker/daemon.json | sudo sponge /etc/docker/daemon.json

sudo systemctl restart docker

docker info | grep 'Runtime'
