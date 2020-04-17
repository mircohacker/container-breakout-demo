#!/bin/bash

# Detelte all images and volumes
docker system prune --all --force --volumes

test -s /etc/docker/daemon.json || echo "{}" | sudo tee /etc/docker/daemon.json

jq '."userns-remap" = "default"' /etc/docker/daemon.json | sudo sponge /etc/docker/daemon.json

sudo systemctl restart docker

docker info | grep -A 10 'Security Options'