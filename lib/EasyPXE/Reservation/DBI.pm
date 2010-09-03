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

package EasyPXE::Reservation::DBI;

use strict;
use warnings;

use base qw( EasyPXE::Plugin );
our $VERSION = 1.00;

#
# Find all DHCP options for a given reservation by MAC address.
#
sub find_options_by_mac_address($$$)
{
  my ($self, $mac_address, $dhcp_packet) = @_;

  my $options = {};

  my $query_find_options = <<_QUERY_END_;
SELECT
  `option`.`key`,
  `option`.`value`
FROM `reservation`
JOIN `network`
  ON `network`.`network_id` = `reservation`.`network_id`
JOIN `network_uses_option_set` AS `nuos`
  ON `nuos`.`network_id` = `network`.`network_id`
JOIN `option_set`
  ON `option_set`.`option_set_id` = `nuos`.`option_set_id`
JOIN `option`
  ON `option`.`option_set_id` = `option_set`.`option_set_id`
WHERE `reservation`.`mac_address` = ?
_QUERY_END_

  my $sth_find_options =  $self->dbh->prepare($query_find_options)
    or die "Couldn't prepare";
  
  $sth_find_options->execute($mac_address)
    or die "Couldn't execute";
  
  while(my $found_options = $sth_find_options->fetchrow_hashref)
  {
    $options->{$found_options->{'key'}} = $found_options->{'value'};
  }
    
  return $options;
}

#
# Find all parameters for a given IP reservation by MAC address.
#
sub find_reservation_by_mac_address($$$)
{
  my ($self, $mac_address, $dhcp_packet) = @_;

  my $offer = {};    

  my $query_find_reservation = <<_QUERY_END_;
SELECT
  INET_NTOA(`reservation`.`ip`)  AS `ip`,
  INET_NTOA(`network`.`network`) AS `network`,
  INET_NTOA(`network`.`netmask`) AS `netmask`,
  `network`.`network_id`
FROM `reservation`
LEFT JOIN `network` ON `network`.`network_id` = `reservation`.`network_id`
WHERE `reservation`.`mac_address` = ?
_QUERY_END_

  my $sth = $self->dbh->prepare($query_find_reservation)
    or die "Couldn't prepare";

  $sth->execute($mac_address)
    or die "Couldn't execute";

  if(my $found_reservation = $sth->fetchrow_hashref)
  {
    # We found a reservation, fill in the reservation hash.

    $offer->{'ip'}      = $found_reservation->{'ip'};
    $offer->{'network'} = $found_reservation->{'network'};
    $offer->{'netmask'} = $found_reservation->{'netmask'};
    $offer->{'options'} = 
      $self->find_options_by_mac_address($mac_address, $dhcp_packet);

    return $offer;
  } else {
    # No reservation for this MAC.
    
    return undef;
  }
}

#
# Find all parameters for a given IP reservation by MAC address.
#
sub find_pool_offer_by_mac_address($$)
{
  my $self = shift;
  return undef;
}

1;
