check that custom ISO build is ok of Ubuntui Server 24.04 LTS
Task is 
in docker build custom iso disk that must me:
- bootable by iPX from HTTP server
- have latest updates
- have network driver for `sfc` , `virtio`
- customer  app prepare for rust environment
- check that the build script is rightly used 

Primary goal is bootable disk less Ubuntu server with 256G Ram and 40G/s etehrent nic.
Configured IP /user/password/ssh key by Cloud-init 
NFS disk is mounted only in state of user boot for use custom app and some settings. 

tested environment is KVM promos server with MTU 9000 infrastructure IPV4/IPv6.

used DHCP v4
pxe load only ipxe.image from tftp
next loaded from HTTP nginx webserver by HTTP server

Was try use layered boot with Squashfs but it was unseccsufll boot since kennel with casper not start boot to http with suqash fs only works with .iso. 
So now version for boot over iso image.



 