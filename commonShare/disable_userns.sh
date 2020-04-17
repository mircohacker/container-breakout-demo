#!/bin/bash

# Delete all images and volumes
docker system prune --all --force --volumes

test -s /etc/docker/daemon.json || echo "{}" | sudo tee /etc/docker/daemon.json

jq 'del(."userns-remap")' /etc/docker/daemon.json | sudo tee /etc/docker/daemon.json

sudo systemctl restart docker

docker info | grep -A 10 'Security Options'