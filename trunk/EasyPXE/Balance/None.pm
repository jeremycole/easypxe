#!/usr/bin/perl -w

# Copyright (c) 2010 Jeremy Cole
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

package EasyPXE::Balance::None;

use strict;
use warnings;

use Data::Dumper;

use base qw( EasyPXE::Plugin );
our $VERSION = 1.00;

#
# Register this DHCP server and mark it online.
#
sub online
{
  my ($self) = @_;
}

#
# De-register this DHCP server and mark it offline.
#
sub offline
{
  my ($self) = @_;
}

#
# Re-balance the server claims.
#
# This assumes that it is executed in a transactional context from somewhere
# higher up the chain
#
sub rebalance($)
{
  my ($self, $need_transaction) = @_;
}

#
# Ping the database to show signs of life in the server list.
#
sub ping
{
  my ($self) = @_;
}

sub accept_request
{
  my ($self, $mac_address) = @_;

  return 1;
}

1;
