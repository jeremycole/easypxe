A dynamic DHCP+PXE server written in Perl.  Are you currently writing out dhcpd.conf and pxelinux.cfg files, HUPing daemons, etc.?  EasyPXE can help you:

  * Serve dynamic DHCP responses (from a backend database or web service), including PXE boot information
  * Transition PXE clients from TFTP to HTTP to allow dynamic load balanced boot servers

Currently a few features are built in but not well tested:

  * DHCP load balancing support through modulus of client MAC address
  * A simple built-in TFTP server to serve primarily gPXE images and remove a dependency on tftpd (usually from xinetd)

This work is part of a larger (unreleased) datacenter management project, but is potentially useful on its own.