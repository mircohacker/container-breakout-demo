#!/bin/bash

set -xe

docker build -t shocker .

docker run --rm --cap-add DAC_READ_SEARCH -it shocker