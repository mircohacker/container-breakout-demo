# Container breakout demos

This repo contains exploits and the corresponding vulnerable component to demonstrate container breakouts.

It uses virtual machines configured with vagrant. They are only tested with the virutal box provider. Other may or may not work.

The `commonShare` folder also contains scripts to enable or disable user namespaces. Also are there scripts to use the alternative OCI Container Runtime Implementation gVisor (runsc) which powers googles container offering. GVisor is not vulnerable to any of the demonstrated Exploits.

Keep in mind that these vulnerabilities ~~are~~ should be long fixed. These demos should only demonstrate what a vulnerable kernel does imply for container security.
