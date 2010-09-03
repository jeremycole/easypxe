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

package EasyPXE::Session::DBI;

use strict;
use warnings;

use base qw( EasyPXE::Plugin );
our $VERSION = 1.00;

use Net::DHCP::Packet;
use Net::DHCP::Constants;

sub get_mac_address($)
{
  my ($request) = @_;
  return substr($request->chaddr(), 0, 12);
}

#
# Track the client-server session state.
#
sub track_session($$$)
{
  my ($self, $dhcp_packet, $state, $ip) = @_;

  my $query_track_session = <<_QUERY_END_;
INSERT INTO `session` 
  (
    `mac_address`,
    `protocol`,
    `xid`,
    `server_identifier`,
    `state`,
    `ip`,
    `ts_first_seen`,
    `ts_last_seen`
  )
VALUES
  (?, ?, ?, INET_ATON(?), ?, INET_ATON(?), NOW(), NOW()) 
ON DUPLICATE KEY UPDATE
  `protocol`          = VALUES(`protocol`), 
  `xid`               = VALUES(`xid`),
  `server_identifier` = VALUES(`server_identifier`),
  `state`             = VALUES(`state`), 
  `ip`                = VALUES(`ip`), 
  `ts_last_seen`      = NOW()
_QUERY_END_

  my $sth = $self->dbh->prepare($query_track_session)
    or die "Couldn't prepare for session insert or update: $!";
  
  $sth->execute(
    &get_mac_address($dhcp_packet),
    $dhcp_packet->isDhcp()?"DHCP":"BOOTP",
    $dhcp_packet->xid(),
    $self->config->get('server_identifier'),
    $state, $ip
  ) or die "Couldn't execute for session insert or update: $!";
}

#
# Look for any session we've stored for this client.
#
sub find_session($$)
{
  my ($self, $mac_address) = @_;

  my $query_find_session = <<_QUERY_END_;
SELECT
  `mac_address`,
  `protocol`,
  `xid`,
  `server_identifier`,
  `state`,
  INET_NTOA(`ip`) AS `ip`,
  `ts_first_seen`,
  `ts_last_seen`
FROM `session`
WHERE `session`.`mac_address` = ?
_QUERY_END_

  my $sth = $self->dbh->prepare($query_find_session)
    or die "Couldn't prepare for session insert or update: $!";
  
  $sth->execute($mac_address)
    or die "Couldn't execute for session insert or update: $!";

  if(my $session = $sth->fetchrow_hashref)
  {
    return $session;
  }

  return undef;
}

#
# Try to guess what state the client is in based on the stored session (if any)
# and the provided Net::DHCP::Packet object, if any.
#
sub client_state($$$$)
{
  my ($self, $mac_address, $session, $dhcp_packet) = @_;

  if(defined($dhcp_packet))
  {
    my $dhcp_message_type = $dhcp_packet->getOptionValue(DHO_DHCP_MESSAGE_TYPE());

    # A client only sends a DHCPDISCOVER when they are in a SELECTING state.
    if($dhcp_message_type == DHCPDISCOVER())
    {
      return 'SELECTING';
    }

    # A client may send a DHCPREQUEST when they are in REBOOTING, REQUESTING,
    # RENEWING, and REBINDING states.  We don't actually care about the real
    # difference between RENEWING and REBINDING so we'll return them both as
    # RENEWING to make the code that handles the return from this simpler.
    if($dhcp_message_type == DHCPREQUEST())
    {
      my $server_identifier = $dhcp_packet->getOptionValue(DHO_DHCP_SERVER_IDENTIFIER());
      my $requested_ip      = $dhcp_packet->getOptionValue(DHO_DHCP_REQUESTED_ADDRESS());
      
      if(!defined($server_identifier) and defined($requested_ip))
      {
        return 'REBOOTING';
      }
    
      if(defined($server_identifier) and defined($requested_ip))
      {
        return 'REQUESTING';
      }
      
      if(!defined($server_identifier) and !defined($requested_ip))
      {
        # Technically, this may also be REBINDING.  A client in the RENEWING
        # state sends its request unicast, while a REBINDING one sends it as
        # a broadcast.  It doesn't matter for the purposes of answering this
        # request though.
        return 'RENEWING';
      }
    }
  }

  if(!defined($session))
  {
    if($session = $self->find_session($mac_address))
    {
      # If we have a session stored for this client, and they didn't match the
      # above criteria, return their stored state.
      return $session->{'state'};
    }
  }

  # We don't know what state the client is in.
  return 'UNKNOWN';
}

1;
