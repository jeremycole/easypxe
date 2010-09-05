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

package EasyPXE::Network::TFTP;

use strict;
use warnings;

use base qw( EasyPXE::Plugin );
our $VERSION = 1.00;

use Event::Lib;
use Sys::Hostname;
use Socket;
use IO::Select;
use IO::Socket::INET;
use Net::TFTP::Packet;
use Net::TFTP::Constants;

my %TFTP_OP_NAMES = (
  1 => "RRQ",
  2 => "WRQ",
  3 => "DATA",
  4 => "ACK",
  5 => "ERROR",
);

sub needed_config_keys()
{
  return (
    "tftp_port",
  );
}

sub initialize_priority()
{
  return 2;
}

sub initialize($)
{
  my ($self) = @_;

  socket($self->{'tftp_sock'}, AF_INET, SOCK_DGRAM, getprotobyname('udp'));
  setsockopt($self->{'tftp_sock'}, SOL_SOCKET, SO_BROADCAST, 1);
  
  if(0 and $self->config->get('interface'))
  {
    # Bind to a specific interface, such as "eth0".  This is required in
    # order to provide service on one interface but not another.  Due to
    # how broadcast stuff works, we can't bind to a specific IP.
  
    # For some reason, SO_BINDTODEVICE isn't defined, but we need it, so
    # we'll use the non-portable constant 25.
  
    setsockopt($self->{'tftp_sock'}, SOL_SOCKET, 25, pack("Z*", $self->config->get('interface')));
  }
  
  bind($self->{'tftp_sock'}, sockaddr_in($self->config_plugin->{'tftp_port'}, INADDR_ANY));

  event_new($self->{'tftp_sock'}, EV_READ|EV_PERSIST, \&event_read_and_dispatch_tftp_request, $self)->add;

  return $EasyPXE::Plugin::PLUGIN_STATUS_OK;
}

sub shutdown($)
{
}

#
#
sub print_tftp_packet($$$)
{
  my ($self, $prefix, $tftp_packet, $client) = @_;

  my ($port, $inaddr) = sockaddr_in($client);
  my $addr = inet_ntoa($inaddr);

  if($tftp_packet->op() == TFTP_RRQ() or $tftp_packet->op() == TFTP_WRQ())
  {
    printf("%s: %-10s%-10s%-14s%-17s%-20s\n", $prefix,
      $TFTP_OP_NAMES{$tftp_packet->op()}, $port, 
      sprintf("TFTP %s", $tftp_packet->mode()), $addr, $tftp_packet->file()
    );
  }

  if($tftp_packet->op() == TFTP_DATA() and $tftp_packet->datalen() != 512)
  {
    printf("%s: %-10s%-10s%-14s%-17s%-20s\n", $prefix,
      $TFTP_OP_NAMES{$tftp_packet->op()}, $port, "TFTP complete", $addr, 
      sprintf("%i packets", $tftp_packet->block())
    );
  }

  if($tftp_packet->op() == TFTP_ERROR())
  {
    printf("%s: %-10s%-10s%-14s%-17s%-20s\n", $prefix,
      $TFTP_OP_NAMES{$tftp_packet->op()}, $port, "TFTP error", $addr, 
      sprintf("%s: %s", $tftp_packet->code(), $tftp_packet->message())
    );
  }

  #print $tftp_packet->toString() . "\n";
}

#
# Send a pre-formulated Net::TFTP::Packet over the network.
#
sub send_tftp_packet($$$)
{
  my ($self, $tftp_packet, $tftp_client) = @_;

  $self->print_tftp_packet("Tx", $tftp_packet, $tftp_client);

  return send($self->{'tftp_sock'}, $tftp_packet->serialize(), 0, $tftp_client);
}

#
# Receive a packet from the network and create a new Net::TFTP::Packet object
# for it.
#
sub recv_tftp_packet($)
{
  my ($self) = @_;

  my $client = recv($self->{'tftp_sock'}, my $tftp_packet_buffer, 4096, 0)
    or die "Got error from recv\n";

  my $tftp_packet = new Net::TFTP::Packet($tftp_packet_buffer);

  $self->print_tftp_packet("Rx", $tftp_packet, $client);

  return ($tftp_packet, $client);
}

sub event_read_and_dispatch_tftp_request($)
{
  my ($event, $event_type, $self) = @_;

  # In order to allow the dispatched subs and plugins a bit more leeway with
  # how they handle errors, we'll eval this whole block and just make note
  # of error exits from the block.
  eval
  {
    my ($tftp_packet, $client) = $self->recv_tftp_packet();
    $self->plugin->{'protocol_tftp'}->dispatch_tftp_packet($tftp_packet, $client);
  };
  print STDERR "Got error inside eval: " . $@ if $@;
}

1;
