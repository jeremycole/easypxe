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

package EasyPXE::Reservation::None;

use strict;
use warnings;

use base qw( EasyPXE::Plugin );
our $VERSION = 1.00;

#
# Find all parameters for a given IP reservation by MAC address.
#
sub find_reservation_by_mac_address($$$)
{
  my ($self, $mac_address, $dhcp_packet) = @_;

  return undef;
}

1;
