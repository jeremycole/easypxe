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

package EasyPXE::Lease::DBI;

use strict;
use warnings;

use base qw( EasyPXE::Plugin EasyPXE::Plugin::Event );
our $VERSION = 1.00;

use Storable qw( freeze thaw );

sub initialize($)
{
  my ($self) = @_;
  
  $self->timer_add(0.0, 10.0, \&expire_leases);

  return $EasyPXE::Plugin::PLUGIN_STATUS_OK;
}

#
# Record a lease made to a client.
#
sub record_lease($$$$)
{
  my ($self, $ip, $mac_address, $status, $offer) = @_;

  my $query_find_and_lock_lease = <<_QUERY_END_;
SELECT 
  `ip`,
  `mac_address`,
  `status`,
  UNIX_TIMESTAMP(`ts_expiration`) - UNIX_TIMESTAMP() AS `expire_seconds` 
FROM `lease` 
WHERE `ip` = INET_ATON(?) 
FOR UPDATE 
_QUERY_END_

  my $query_delete_lease = <<_QUERY_END_;
DELETE
  `lease`,
  `lease_data`
FROM `lease`
LEFT JOIN `lease_data` ON `lease_data`.`lease_id` = `lease`.`lease_id`
WHERE `lease`.`ip` = INET_ATON(?) OR `lease`.`mac_address` = ?
_QUERY_END_

  my $query_insert_lease = <<_QUERY_END_;
INSERT INTO `lease`
  (
    `ip`,
    `mac_address`,
    `status`,
    `lease_seconds`,
    `ts_assigned`,
    `ts_renewal`,
    `ts_rebinding`,
    `ts_expiration`
  )
VALUES 
  (
    INET_ATON(?),
    ?,
    ?,
    ?,
    NOW(),
    NOW() + INTERVAL ? SECOND,
    NOW() + INTERVAL ? SECOND,
    NOW() + INTERVAL ? SECOND
  )
_QUERY_END_

  my $query_insert_lease_data = <<_QUERY_END_;
INSERT INTO `lease_data`
  (`lease_id`, `offer`)
VALUES
  (?, ?)
_QUERY_END_

  my $query_insert_lease_history = <<_QUERY_END_;
INSERT INTO `lease_history`
  (
    `ip`,
    `mac_address`,
    `ts_assigned`
  )
VALUES 
  (
    INET_ATON(?),
    ?,
    NOW()
  )
_QUERY_END_

  $self->dbh->do("BEGIN");

  my $sth_find = $self->dbh->prepare($query_find_and_lock_lease);
  $sth_find->execute($ip);
  my $lease = $sth_find->fetchrow_hashref;
  
  if($lease)
  {
    if(($mac_address ne $lease->{mac_address})
      and (
        ($lease->{status} ne 'PERMANENT' and $lease->{expire_seconds} <= 0)
        or ($lease->{status} ne 'PERMANENT')
      )
    ) {
      # The lease may still be valid for another client, abort!
      
      $self->dbh->do("ROLLBACK");
      return;
    }
  }

  # All is well, take over this lease if it exists, and clear this client's
  # previous lease, if present.
  my $sth_delete = $self->dbh->prepare($query_delete_lease)
    or die "Couldn't prepare: $!";

  $sth_delete->execute($ip, $mac_address)
    or die "Couldn't execute: $!";       

  my $lease_time = $offer->{'lease_time'}?$offer->{'lease_time'}:0;

  my $sth_lease = $self->dbh->prepare($query_insert_lease)
    or die "Couldn't prepare: $!";

  $sth_lease->execute($ip, $mac_address, $status, 
                      $lease_time,
                      $lease_time * 0.5,
                      $lease_time * 0.875,
                      $lease_time)
    or die "Couldn't execute: $!";

  my $sth_lease_data = $self->dbh->prepare($query_insert_lease_data)
    or die "Couldn't prepare: $!";
  
  my $frozen_offer = freeze $offer
    or die "Couldn't freeze! $!";

  $sth_lease_data->execute($self->dbh->{'mysql_insertid'}, $frozen_offer) 
    or die "Couldn't execute: $!";

  my $sth_lease_history = $self->dbh->prepare($query_insert_lease_history)
    or die "Couldn't prepare: $!";

  $sth_lease_history->execute($ip, $mac_address)
    or die "Couldn't execute: $!";

  $self->dbh->do("COMMIT")
    or die "Couldn't commit: $!";
}

sub expire_leases($)
{
  my ($self) = @_;

  my $query_find_expired_leases = <<_QUERY_END_;
SELECT 
  `lease_id`,
  `status`,
  `mac_address`,
  INET_NTOA(`ip`) AS `ip`
FROM `lease` 
WHERE 1
  AND `ts_expiration` < NOW()
  OR (
    `ts_assigned` < NOW() - INTERVAL 60 SECOND
    AND `status` = 'OFFER'
  )
FOR UPDATE 
_QUERY_END_

  my $query_delete_lease = <<_QUERY_END_;
DELETE
  `lease`,
  `lease_data`
FROM `lease`
LEFT JOIN `lease_data` ON `lease_data`.`lease_id` = `lease`.`lease_id`
WHERE `lease`.`lease_id` = ?
_QUERY_END_

  $self->dbh->do("BEGIN");

  my $sth_find = $self->dbh->prepare($query_find_expired_leases);
  $sth_find->execute;

  my $sth_delete = $self->dbh->prepare($query_delete_lease);
  
  while(my $lease = $sth_find->fetchrow_hashref)
  {
    printf "Expiring lease (%s) on %s for %s\n",
      $lease->{'status'}, $lease->{'ip'}, $lease->{'mac_address'};

    $sth_delete->execute($lease->{'lease_id'});
  }

  $self->dbh->do("COMMIT");
}

sub find_offer_by_mac_address($$)
{
  my ($self, $mac_address, $dhcp_packet) = @_;

  my $query_find_offer = <<_QUERY_END_;
SELECT 
  `lease_data`.`offer`
FROM `lease`
JOIN `lease_data` ON `lease_data`.`lease_id` = `lease`.`lease_id`
WHERE 1
  AND `lease`.`mac_address` = ?
  AND `lease`.`status` IN ('OFFER', 'PERMANENT', 'TEMPORARY', 'RELEASED')
_QUERY_END_

  my $sth = $self->dbh->prepare($query_find_offer)
    or die ("Couldn't prepare");

  $sth->execute($mac_address)
    or die "Couldn't execute";

  if(my $row = $sth->fetchrow_hashref)
  {
    my $frozen_offer = $row->{offer};
    return thaw $frozen_offer;
  } else {
    # No previous offer for this MAC
    return undef;
  }
}

1;
