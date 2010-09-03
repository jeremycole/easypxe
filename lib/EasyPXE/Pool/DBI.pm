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

package EasyPXE::Pool::DBI;

use strict;
use warnings;

use base qw( EasyPXE::Plugin );
our $VERSION = 1.00;

#
# Find all DHCP options for a given reservation by MAC address.
#
sub find_options_by_ip($$$)
{
  my ($self, $ip) = @_;

  my $options = {};

  my $query_find_options = <<_QUERY_END_;
SELECT
  `option`.`key`,
  `option`.`value`
FROM `pool`
JOIN `network`
  ON `network`.`network_id` = `pool`.`network_id`
JOIN `network_uses_option_set` AS `nuos`
  ON `nuos`.`network_id` = `network`.`network_id`
JOIN `option_set`
  ON `option_set`.`option_set_id` = `nuos`.`option_set_id`
JOIN `option`
  ON `option`.`option_set_id` = `option_set`.`option_set_id`
WHERE `pool`.`ip` = INET_ATON(?)
_QUERY_END_

  my $sth_find_options =  $self->dbh->prepare($query_find_options)
    or die "Couldn't prepare";
  
  $sth_find_options->execute($ip)
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
sub find_pool_offer_by_mac_address($$$)
{
  my ($self, $mac_address, $dhcp_packet) = @_;

  my $offer = {};    

  my $query_find_available = <<_QUERY_END_;
SELECT
  INET_NTOA(`pool`.`ip`)  AS `ip`,
  CASE
    WHEN `lease`.`ts_expiration` >= NOW() AND `lease`.`mac_address` = ? THEN 1
    WHEN `pool`.`ts_last_offered` AND `pool`.`mac_address_last_offered` = ? THEN 2
    ELSE 3
  END AS `priority`
FROM `pool`
LEFT JOIN `lease`
  ON `lease`.`ip` = `pool`.`ip`
WHERE 0
  OR `lease`.`ip` IS NULL 
  OR (`lease`.`ts_expiration` >= NOW() AND `lease`.`mac_address` = ?)
  OR `lease`.`ts_expiration` < NOW() - INTERVAL ? SECOND
ORDER BY
  `priority` ASC,
  `pool`.`ts_last_offered` ASC,
  `pool`.`ip` ASC
LIMIT 1
_QUERY_END_

  my $query_take_available = <<_QUERY_END_;
SELECT
  INET_NTOA(`pool`.`ip`)  AS `ip`,
  INET_NTOA(`network`.`network`) AS `network`,
  INET_NTOA(`network`.`netmask`) AS `netmask`,
  `network`.`network_id`
FROM `pool`
LEFT JOIN `lease`
  ON `lease`.`ip` = `pool`.`ip`
LEFT JOIN `network` ON `network`.`network_id` = `pool`.`network_id`
WHERE `pool`.`ip` = INET_ATON(?)
  AND ( 0
    OR `lease`.`ip` IS NULL 
    OR (`lease`.`ts_expiration` >= NOW() AND `lease`.`mac_address` = ?)
    OR `lease`.`ts_expiration` < NOW() - INTERVAL ? SECOND
)
FOR UPDATE
_QUERY_END_

  my $query_update_last_offered = <<_QUERY_END_;
UPDATE `pool`
SET
  `ts_last_offered` = NOW(),
  `mac_address_last_offered` = ?
WHERE `pool`.`ip` = INET_ATON(?)
_QUERY_END_

  my $sth_find_available = $self->dbh->prepare($query_find_available)
    or die "Couldn't prepare";

  $sth_find_available->execute($mac_address, $mac_address, $mac_address, 1)
    or die "Couldn't execute";

  if(my $found_available = $sth_find_available->fetchrow_hashref)
  {
    $self->dbh->do("BEGIN");

    my $sth_take_available = $self->dbh->prepare($query_take_available)
      or die "Couldn't prepare";

    $sth_take_available->execute($found_available->{'ip'}, $mac_address, 1)
      or die "Couldn't execute";

    if(my $found_reservation = $sth_take_available->fetchrow_hashref)
    {
      my $sth_update_last_offered = $self->dbh->prepare($query_update_last_offered)
        or die "Couldn't prepare";

      $sth_update_last_offered->execute($mac_address, $found_available->{'ip'});

      # We found a reservation, fill in the offer hash.

      $offer->{'ip'}      = $found_reservation->{'ip'};
      $offer->{'network'} = $found_reservation->{'network'};
      $offer->{'netmask'} = $found_reservation->{'netmask'};
      $offer->{'options'} = $self->find_options_by_ip($offer->{'ip'});

      return $offer;
    }
  } else {
    # No reservation for this MAC.
    
    return undef;
  }
}

1;
