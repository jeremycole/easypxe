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

package EasyPXE::Network::UDP;

use strict;
use warnings;

use base qw( EasyPXE::Plugin );
our $VERSION = 1.00;

use Event::Lib;
use Sys::Hostname;
use Socket;
use IO::Select;
use IO::Socket::INET;
use Net::DHCP::Packet;
use Net::DHCP::Constants;

sub needed_config_keys()
{
  return ();
}

sub initialize_priority()
{
  return 2;
}

sub initialize($)
{
  my ($self) = @_;

  socket($self->{'dhcp_sock'}, AF_INET, SOCK_DGRAM, getprotobyname('udp'));
  setsockopt($self->{'dhcp_sock'}, SOL_SOCKET, SO_BROADCAST, 1);
  
  if($self->config->get('interface'))
  {
    # Bind to a specific interface, such as "eth0".  This is required in
    # order to provide service on one interface but not another.  Due to
    # how broadcast stuff works, we can't bind to a specific IP.
  
    # For some reason, SO_BINDTODEVICE isn't defined, but we need it, so
    # we'll use the non-portable constant 25.
  
    setsockopt($self->{'dhcp_sock'}, SOL_SOCKET, 25, pack("Z*", $self->config->get('interface')));
  }
  
  bind($self->{'dhcp_sock'}, sockaddr_in($self->config->get("server_port"), INADDR_ANY));

  event_new($self->{'dhcp_sock'}, EV_READ|EV_PERSIST, \&event_read_and_dispatch_dhcp_request, $self)->add;

  return $EasyPXE::Plugin::PLUGIN_STATUS_OK;
}

sub shutdown($)
{
}

#
# Return the client hardware address from the Net::DHCP::Packet object.
#
sub get_mac_address($)
{
  my ($request) = @_;
  return substr($request->chaddr(), 0, 12);
}

#
# Print a received or sent Net::DHCP::Packet object in a concise one-line
# format useful for logging and debugging client/server interactions.
#
sub print_dhcp_packet($$$)
{
  my ($self, $prefix, $dhcp_packet) = @_;

  my $message_type = $Net::DHCP::Constants::REV_DHCP_MESSAGE{$dhcp_packet->getOptionValue(DHO_DHCP_MESSAGE_TYPE())};
  $message_type =~ s/DHCP//;

  my $requested_address = $dhcp_packet->getOptionValue(DHO_DHCP_REQUESTED_ADDRESS());
  $requested_address = defined($requested_address)?$requested_address:$dhcp_packet->ciaddr();

  printf("%s: %-10s%-10s%-14s%-17s%-20s\n",
    $prefix,
    $message_type,
    sprintf("%08x", $dhcp_packet->xid()),
    &get_mac_address($dhcp_packet),
    $dhcp_packet->op()==BOOTREPLY()?$dhcp_packet->yiaddr():$requested_address,
    $dhcp_packet->op()==BOOTREPLY()?
      (length($dhcp_packet->file())>20?"...".substr($dhcp_packet->file(), -17, 17):$dhcp_packet->file()):
      $self->plugin->{'session'}->client_state(&get_mac_address($dhcp_packet), undef, $dhcp_packet)
  );
  
  #print $dhcp_packet->toString();
}

#
# Send a pre-formulated Net::DHCP::Packet over the network.
#
sub send_dhcp_packet($$$)
{
  my ($self, $dhcp_packet, $dhcp_client) = @_;

  $self->print_dhcp_packet("Tx", $dhcp_packet);

  return send($self->{'dhcp_sock'}, $dhcp_packet->serialize(), 0, $dhcp_client);
}

#
# Receive a packet from the network and create a new Net::DHCP::Packet object
# for it.
#
sub recv_dhcp_packet($)
{
  my ($self) = @_;

  my $client = recv($self->{'dhcp_sock'}, my $dhcp_packet_buffer, 4096, 0)
    or die "Got error from recv\n";
  
  my $dhcp_packet = new Net::DHCP::Packet($dhcp_packet_buffer);

  $self->print_dhcp_packet("Rx", $dhcp_packet);

  return $dhcp_packet;
}

sub event_read_and_dispatch_dhcp_request($)
{
  my ($event, $event_type, $self) = @_;

  # In order to allow the dispatched subs and plugins a bit more leeway with
  # how they handle errors, we'll eval this whole block and just make note
  # of error exits from the block.
  eval
  {
    my $dhcp_packet = $self->recv_dhcp_packet();
    $self->plugin->{'protocol_dhcp'}->dispatch_dhcp_packet($dhcp_packet);
  };
  print STDERR "Got error inside eval: " . $@ if $@;
}



1;
