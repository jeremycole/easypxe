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

package EasyPXE::Protocol::TFTP;

use strict;
use warnings;

use base qw( EasyPXE::Plugin EasyPXE::Plugin::Event );
our $VERSION = 1.00;

use Event::Lib;
use Sys::Hostname;
use Socket;
use IO::Select;
use IO::Socket::INET;
use Net::TFTP::Packet;
use Net::TFTP::Constants;
use Data::Dumper;

sub needed_config_keys()
{
  return ();
}

sub initialize_priority()
{
  return 3;
}

sub initialize($)
{
  my ($self) = @_;

  $self->{'sessions'} = {};

  $self->timer_add(0.0, 1.0, \&expire_sessions);

  return $EasyPXE::Plugin::PLUGIN_STATUS_OK;
}

#
# A map of TFTP operations to their handler functions.
#
my %tftp_op_handlers = (
  TFTP_RRQ()   => \&handle_tftp_rrq,
  TFTP_WRQ()   => \&handle_tftp_wrq,
  TFTP_DATA()  => \&handle_tftp_data,
  TFTP_ACK()   => \&handle_tftp_ack,
  TFTP_ERROR() => \&handle_tftp_error,
);

#
# Dispatch a DHCP request from a client to the appropriate handler function
# using the global %dhcp_message_handlers hash.
#
sub dispatch_tftp_packet($$$)
{
  my ($self, $tftp_packet, $client) = @_;

  if(exists($tftp_op_handlers{$tftp_packet->op()}))
  {
    $tftp_op_handlers{$tftp_packet->op()}->($self, $tftp_packet, $client);
  }
}

sub expire_sessions($)
{
  my ($self) = @_;
  foreach my $session_key (keys %{$self->{'sessions'}})
  {
    my $session = $self->{'sessions'}->{$session_key};
    my ($addr, $port) = split /:/, $session_key;

    if($session->{'timeout'} != -1)
    {
      if($session->{'timeout'} == 0)
      {
        print "Expiring TFTP session for $addr:$port\n";
        $self->session_destroy($addr, $port);
      } else {
        $session->{'timeout'}--;
      }
    }
  }
}

sub session_create($$$$$$)
{
  my ($self, $addr, $port, $op, $file, $mode) = @_;

  $self->{'sessions'}->{"$addr:$port"} = {
    'op' => $op,
    'file' => $file,
    'mode' => $mode,
    'block' => 1,
    'fd' => undef,
    'eof' => 0,
    'timeout' => -1,
    'error' => 0,
  };
  
  my $session = $self->{'sessions'}->{"$addr:$port"};
  
  unless(open $session->{'fd'}, "<", "/tftpboot/" . $file)
  {
    $self->session_error($addr, $port, TFTP_FILE_NOT_FOUND(), "$file");
    return undef;
  }

  binmode $session->{'fd'};

  return $self->{'sessions'}->{"$addr:$port"}->{'block'};
}

sub session_error($$$$$)
{
  my ($self, $addr, $port, $code, $message) = @_;
  my $session = $self->{'sessions'}->{"$addr:$port"};

  $session->{'error'} = 1;
  $session->{'timeout'} = 10;

  my %tftp_reply_args = (
    Op      => TFTP_ERROR(),
    Code    => $code,
    Message => $message,
  );
  
  my $tftp_client = sockaddr_in($port, inet_aton($addr));

  my $tftp_reply = new Net::TFTP::Packet(%tftp_reply_args);
  $self->plugin->{'network_tftp'}->send_tftp_packet($tftp_reply, $tftp_client)
    or die "Error sending ERROR: $!";

}

sub session_send_data($$$)
{
  my ($self, $addr, $port) = @_;
  my $session = $self->{'sessions'}->{"$addr:$port"};

  my $data_offset = (($session->{'block'}-1) * 512);
  
  seek $session->{'fd'}, $data_offset, 0;
  my $bytes_read = read $session->{'fd'}, my $data, 512;

  if(defined($bytes_read))
  {
    if($bytes_read < 512)
    {
      $session->{'eof'} = 1;
    }
  } else {
    $self->session_destroy($addr, $port);
    return undef;
  }

  my %tftp_reply_args = (
    Op      => TFTP_DATA(),
    Block   => $session->{'block'},
    Data    => $data,
    DataLen => $bytes_read,
  );
  
  my $tftp_client = sockaddr_in($port, inet_aton($addr));

  my $tftp_reply = new Net::TFTP::Packet(%tftp_reply_args);
  $self->plugin->{'network_tftp'}->send_tftp_packet($tftp_reply, $tftp_client)
    or die "Error sending DATA in response to RRQ: $!";
  
  $session->{'timeout'} = 10;
  return $session->{'block'};
}

sub session_block_ack($$$)
{
  my ($self, $addr, $port) = @_;

  return ++$self->{'sessions'}->{"$addr:$port"}->{'block'};
}

sub session_destroy($$$)
{
  my ($self, $addr, $port) = @_;
  my $session = $self->{'sessions'}->{"$addr:$port"};

  if(defined($session->{'fd'}))
  {
    close $session->{'fd'};
  }
  delete $self->{'sessions'}->{"$addr:$port"};
}

sub handle_tftp_rrq($$$)
{
  my ($self, $tftp_packet, $client) = @_;

  my ($port, $inaddr) = sockaddr_in($client);
  my $addr = inet_ntoa($inaddr);

  if(!defined($self->session_create($addr, $port, TFTP_RRQ(), $tftp_packet->file(), $tftp_packet->mode())))
  {
    return;
  }
  $self->session_send_data($addr, $port);
}

sub handle_tftp_wrq($$)
{
  my ($self, $tftp_packet, $client) = @_;

  my ($port, $inaddr) = sockaddr_in($client);
  my $addr = inet_ntoa($inaddr);

  my %tftp_reply_args = (
    Op      => TFTP_ERROR(),
    Code    => TFTP_ACCESS_VIOLATION(),
    Message => "",
  );
  
  my $tftp_client = sockaddr_in($port, inet_aton($addr));

  my $tftp_reply = new Net::TFTP::Packet(%tftp_reply_args);
  $self->plugin->{'network_tftp'}->send_tftp_packet($tftp_reply, $tftp_client)
    or die "Error sending ERROR: $!";
}

sub handle_tftp_data($$)
{
  my ($self, $tftp_packet, $client) = @_;

  my ($port, $inaddr) = sockaddr_in($client);
  my $addr = inet_ntoa($inaddr);

  my %tftp_reply_args = (
    Op      => TFTP_ERROR(),
    Code    => TFTP_ACCESS_VIOLATION(),
    Message => "",
  );
  
  my $tftp_client = sockaddr_in($port, inet_aton($addr));

  my $tftp_reply = new Net::TFTP::Packet(%tftp_reply_args);
  $self->plugin->{'network_tftp'}->send_tftp_packet($tftp_reply, $tftp_client)
    or die "Error sending ERROR: $!";
}

sub handle_tftp_ack($$)
{
  my ($self, $tftp_packet, $client) = @_;
  my ($port, $inaddr) = sockaddr_in($client);
  my $addr = inet_ntoa($inaddr);

  my $session = $self->{'sessions'}->{"$addr:$port"};

  if(!defined($session))
  {
    printf("Don't know about this session $addr:$port\n");
    return;
  }

  if($session->{'error'})
  {
    $self->session_destroy($addr, $port);
    return;
  }
  
  if($session->{'block'} != $tftp_packet->block())
  {
    printf "Incorrect block number?\n";
    $self->session_error($addr, $port, TFTP_UNDEFINED(), "Ack of incorrect block number");
    $self->session_destroy($addr, $port);
    return;
  }
  
  if($session->{'eof'} == 1)
  {
    $self->session_destroy($addr, $port);
    return;
  }

  $self->session_block_ack($addr, $port);
  $self->session_send_data($addr, $port);
}

sub handle_tftp_error($$)
{
  my ($self, $tftp_packet, $client) = @_;

  my ($port, $inaddr) = sockaddr_in($client);
  my $addr = inet_ntoa($inaddr);

  $self->session_destroy($addr, $port);
}

1;
