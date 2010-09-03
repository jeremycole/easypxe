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

#
# TODO:
#   * Make it work 100% with multiple servers running and responding.
#   * Some mechanism to check the work of the other servers?
#

package EasyPXE::Balance::Xor;

use strict;
use warnings;

use base qw( EasyPXE::Plugin );
our $VERSION = 1.00;

use Data::Dumper;

my $opt_claim_buckets = 256;

sub initialize()
{
  my ($self) = @_;

  $self->online();
}

sub shutdown()
{
  my ($self) = @_;

  $self->offline();
}

#
# Register this DHCP server and mark it online.
#
sub online
{
  my ($self) = @_;

  my $query_server_online = <<_QUERY_END_;
INSERT INTO `server`
  (
    `server_identifier`,
    `hostname`,
    `ts_online`,
    `ts_offline`,
    `ts_ping`
  )
VALUES
  (INET_ATON(?), ?, NOW(), NULL, NOW())
ON DUPLICATE KEY UPDATE
  `hostname`   = VALUES(`hostname`),
  `ts_online`  = NOW(),
  `ts_offline` = NULL,
  `ts_ping`    = NOW()
_QUERY_END_

  my $query_count_claims = "SELECT COUNT(*) AS `claims` FROM `server_claim`";

  $self->dbh->do("BEGIN");

  my $sth_count_claims = $self->dbh->prepare($query_count_claims)
    or die "Couldn't prepare: $!";
  
  $sth_count_claims->execute
    or die "Couldn't execute: $!";
  
  my $count = $sth_count_claims->fetchrow_hashref;
  
  if($count->{'claims'} > 0 and $count->{'claims'} != $opt_claim_buckets)
  {
    die sprintf("claim-buckets setting of %i does not match number of claims in database, which is %i", $opt_claim_buckets, $count->{'claims'});
  }

  my $sth_server_online = $self->dbh->prepare($query_server_online)
    or die "Couldn't prepare: $!";
  
  $sth_server_online->execute($self->config->get('server_identifier'), "")
    or die "Couldn't execute: $!";

  $self->rebalance(0);

  $self->dbh->do("COMMIT");

}

#
# De-register this DHCP server and mark it offline.
#
sub offline
{
  my ($self) = @_;

  my $query_server_offline = <<_QUERY_END_;
UPDATE `server`
SET
  `ts_offline`  = NOW(),
  `ts_ping`     = NULL
WHERE `server_identifier` = INET_ATON(?)
_QUERY_END_

  $self->dbh->do("BEGIN");

  my $sth_server_offline = $self->dbh->prepare($query_server_offline)
    or die "Couldn't prepare: $!";
  
  $sth_server_offline->execute($self->config->get('server_identifier'))
    or die "Couldn't execute: $!";

  $self->rebalance(0);

  $self->dbh->do("COMMIT");

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

  my @server_list;

  my $query_select_servers = <<_QUERY_END_;
SELECT
  INET_NTOA(`server_identifier`) AS `server_identifier`,
  (`ts_offline` IS NULL) AS `is_online`
FROM `server`
ORDER BY `server_identifier`
FOR UPDATE
_QUERY_END_

  my $query_clear_claims = "DELETE FROM `server_claim`";

  my $query_insert_claim = <<_QUERY_END_;
INSERT INTO `server_claim`
  (`server_identifier`, `claim`)
VALUES
  (INET_ATON(?), ?)
_QUERY_END_

  my $sth_select_servers = $self->dbh->prepare($query_select_servers)
    or die "Couldn't prepare: $!";

  $sth_select_servers->execute;
  
  my $server_count = 0;
  while(my $row = $sth_select_servers->fetchrow_hashref)
  {
    $server_list[$server_count++] = $row->{'server_identifier'} 
      if $row->{'is_online'};
  }
  
  print STDERR "Server list:\n";
  print STDERR Dumper \@server_list;

  $self->dbh->do($query_clear_claims)
    or die "Couldn't do: $!";

  if($server_count > 0)
  {
    my $sth_insert_claim = $self->dbh->prepare($query_insert_claim)
      or die "Couldn't prepare: $!";
    
    for(my $bucket=0; $bucket < $opt_claim_buckets; $bucket++)
    {
      my $server_claim = ($bucket % $server_count);
      printf STDERR "Claiming bucket %i for server %s\n",
        $bucket, $server_list[$server_claim];
      $sth_insert_claim->execute($server_list[$server_claim], $bucket)
        or die "Couldn't execute: $!";
    }
  }
  
  $self->load_claim_table();
}

sub load_claim_table
{
  my ($self) = @_;

  my $query_load_claims = <<_QUERY_END_;
SELECT
  `claim`,
  INET_NTOA(`server_identifier`) AS `server_identifier`
FROM `server_claim`
ORDER BY `claim` ASC
_QUERY_END_

  my $query_get_timestamp = "SELECT UNIX_TIMESTAMP() AS `ts_now`";

  my $sth_load_claims =     ->prepare($query_load_claims)
    or die "Couldn't prepare: $!";
  
  $sth_load_claims->execute
    or die "Couldn't execute: $!";

  my $sth_get_timestamp = $self->dbh->prepare($query_get_timestamp)
    or die "Couldn't prepare: $!";
  
  $sth_get_timestamp->execute
    or die "Couldn't execute: $!";

  my $row_timestamp = $sth_get_timestamp->fetchrow_hashref;

  $self->{'claim_table'} = [];
  
  while(my $row = $sth_load_claims->fetchrow_hashref)
  {
    $self->{'claim_table'}->[$row->{'claim'}] = $row->{'server_identifier'};
  }
  
  $self->{'claim_table_reloaded'} = $row_timestamp->{'ts_now'};
  
  print STDERR "Claim table reloaded at $self->{'claim_table_reloaded'}\n";
}

#
# Ping the database to show signs of life in the server list.
#
sub ping
{
  my ($self) = @_;

  my $query_server_ping = <<_QUERY_END_;
UPDATE `server`
SET
  `ts_ping`     = NOW()
WHERE `server_identifier` = INET_ATON(?)
_QUERY_END_

  my $query_server_activity = <<_QUERY_END_;
SELECT
  UNIX_TIMESTAMP(GREATEST(
    IFNULL(MAX(`ts_online`), 0),
    IFNULL(MAX(`ts_offline`), 0)
  )) AS `ts_activity`
FROM `server`
_QUERY_END_

  my $sth_server_ping = $self->dbh->prepare($query_server_ping)
    or die "Couldn't prepare: $!";
  
  $sth_server_ping->execute($self->config->get('server_identifier'))
    or die "Couldn't execute: $!";

  my $sth_server_activity = $self->dbh->prepare($query_server_activity)
    or die "Couldn't prepare: $!";
  
  $sth_server_activity->execute
    or die "Couldn't execute: $!";
  
  my $row = $sth_server_activity->fetchrow_hashref;
  
  $self->load_claim_table if($self->{'claim_table_reloaded'} < $row->{'ts_activity'});
}

sub accept_request
{
  my ($self, $mac_address) = @_;

  my $claim_slot = ((hex $mac_address) % $opt_claim_buckets);

  if(my $claim_server = $self->{'claim_table'}->[$claim_slot] != $self->config->get('server_identifier'))
  {
    printf STDERR "Request from %s (claim slot %i) should be handled by %s\n",
      $mac_address, $claim_slot, $claim_server;
    return 0;
  }
  return 1;
}

1;
