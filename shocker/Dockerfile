FROM ubuntu
RUN apt-get update && apt-get install -yq gcc
ADD . /app
WORKDIR /app
RUN cc -Wall -std=c99 -O2 shocker.c -static -Wno-unused-result -o shocker

#CMD bash -c './name_to_handle /etc/resolv.conf | ./open_by_handle_at && ./shocker'
CMD bash -c './shocker'