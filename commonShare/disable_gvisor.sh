#!/bin/bash

test -s /etc/docker/daemon.json || echo "{}" | sudo tee /etc/docker/daemon.json

jq 'del(."runtimes".runsc)' /etc/docker/daemon.json | sudo sponge /etc/docker/daemon.json
jq 'if ."default-runtime" == "runsc" then  del(."default-runtime") else . end' /etc/docker/daemon.json | sudo sponge /etc/docker/daemon.json

sudo systemctl restart docker

docker info | grep 'Runtime'