#!/usr/bin/perl -w

# Copyright (c) 2010 Jeremy Cole <jeremy@jcole.us>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package EasyPXE::Boot::Chain_gPXE_PXELINUX;

use strict;
use warnings;

use base qw( EasyPXE::Plugin );
our $VERSION = 1.00;

use Data::Dumper;
use Net::DHCP::Constants;

sub needed_config_keys()
{
  return (
    "gpxe_tftp_server",
    "gpxe_tftp_filename",
    "pxelinux_url",
  );
}

#
# Find boot parameters for a given host by MAC address.
#
sub find_boot_by_mac_address($$)
{
  my ($self, $mac_address, $dhcp_packet) = @_;

  my $boot = {
    'server'   => '0.0.0.0',
    'filename' => '',
  };

  if(defined($dhcp_packet->getOptionValue(DHO_VENDOR_CLASS_IDENTIFIER()))
    and $dhcp_packet->getOptionValue(DHO_VENDOR_CLASS_IDENTIFIER()) =~ /PXE/)
  {
    if($dhcp_packet->getOptionRaw(175))
    {
      # We're coming from gPXE, load PXELINUX via HTTP
      $boot = {
        'server'   => '0.0.0.0',
        'filename' => $self->config_plugin->{'pxelinux_url'},
      };
    } else {
      # We're not in gPXE yet, so boot it by TFTP
      $boot = {
        'server'   => $self->config_plugin->{'gpxe_tftp_server'},
        'filename' => $self->config_plugin->{'gpxe_tftp_filename'},
      };
    }
  }

  return $boot;
}

1;
