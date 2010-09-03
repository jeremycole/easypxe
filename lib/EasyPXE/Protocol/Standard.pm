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

package EasyPXE::Protocol::Standard;

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
  return 3;
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
# Formulate a Net::DHCP::Packet object for reply to a request from the client.
# This is done in three steps:
#
#   1. Copy the relevant fields from the incoming request as per the DHCP
#      specifications.
#
#   2. Copy the data (if any) from the simplified offer structure.
#
#   3. Determine who to send the reply to, either as a broadcast back to the
#      client, or as a unicast to a DHCP helper ("gateway") that may have
#      forwarded the request across networks on the client's behalf.
#
sub construct_dhcp_reply($$$)
{
  my ($self, $dhcp_packet, $message_type, $offer) = @_;

  my %dhcp_parameters = (
    Op     => BOOTREPLY(),
    Hops   => $dhcp_packet->hops(),
    Xid    => $dhcp_packet->xid(),
    Flags  => $dhcp_packet->flags(),
    Ciaddr => $dhcp_packet->ciaddr(),
    Yiaddr => defined($offer)?$offer->{'ip'}:'0.0.0.0',
    Siaddr => $dhcp_packet->siaddr(),
    Giaddr => $dhcp_packet->giaddr(),
    Chaddr => $dhcp_packet->chaddr(),
    Sname  => defined($offer)?$offer->{'boot'}->{'server'}   : '0.0.0.0',
    File   => defined($offer)?$offer->{'boot'}->{'filename'} : '',
    DHO_DHCP_MESSAGE_TYPE()      => $message_type,
    DHO_DHCP_SERVER_IDENTIFIER() => $self->config->get('server_identifier'),
  );

  if(defined $offer->{'lease_time'})
  {
    $dhcp_parameters{DHO_DHCP_LEASE_TIME()} = $offer->{'lease_time'};
  }
  
  if(defined $offer->{'netmask'})
  {
    $dhcp_parameters{DHO_SUBNET_MASK()} = $offer->{'netmask'};
  }

  if(defined $offer->{'routers'})
  {
    $dhcp_parameters{DHO_ROUTERS()} = $offer->{'routers'};
  }

  if(defined $offer->{'dns'})
  {
    $dhcp_parameters{DHO_DOMAIN_NAME_SERVERS()} = $offer->{'dns'};
  }

  if(defined $offer->{'domain'})
  {
    $dhcp_parameters{DHO_DOMAIN_NAME()} = $offer->{'domain'};
  }

  my $dhcp_reply = new Net::DHCP::Packet(%dhcp_parameters)
    or die "Couldn't construct reply: $!";

  # By default, all replies get broadcast to the client directly.
  my $dhcp_client = sockaddr_in($self->config->get("client_port"), INADDR_BROADCAST);
  
  # If this request was relayed, reply to the relay (giaddr) directly.
  if($dhcp_packet->giaddr() ne '0.0.0.0')
  {
    $dhcp_client = sockaddr_in($self->config->get("client_port"), $dhcp_packet->giaddr());
  }

  return ($dhcp_reply, $dhcp_client);
}

#
# A map of DHCP message types to their handler functions.
#
my %dhcp_message_handlers = (
  DHCPDISCOVER() => \&handle_dhcp_discover,
  DHCPREQUEST()  => \&handle_dhcp_request,
  DHCPDECLINE()  => \&handle_dhcp_decline,
  DHCPRELEASE()  => \&handle_dhcp_release,
  DHCPINFORM()   => \&handle_dhcp_inform,
);

#
# Dispatch a DHCP request from a client to the appropriate handler function
# using the global %dhcp_message_handlers hash.
#
sub dispatch_dhcp_packet($$)
{
  my ($self, $dhcp_packet) = @_;

  my $message_type = $dhcp_packet->getOptionValue(DHO_DHCP_MESSAGE_TYPE())
    or die "No DHCP_MESSAGE_TYPE, nothing to do";

  if(exists($dhcp_message_handlers{$message_type}))
  {
    $dhcp_message_handlers{$message_type}->($self, $dhcp_packet);
  }
}

#
# Handle a DHCPDISCOVER
#
# We should respond with a DHCPOFFER if we can help this client, or ignore
# the request if we cannot help them.
#
sub handle_dhcp_discover($$)
{
  my ($self, $dhcp_packet) = @_;
  my $offer = undef;

  if(!$self->plugin->{'balance'}->accept_request(&get_mac_address($dhcp_packet)))
  {
    return;
  }

  my $reservation = $self->plugin->{'reservation'};

  my $mac_address = &get_mac_address($dhcp_packet);

  $self->plugin->{'session'}->track_session($dhcp_packet, "INIT", 0);

  my $found_offer;
  if($found_offer = $self->plugin->{'reservation'}->find_reservation_by_mac_address($mac_address, $dhcp_packet)) {
    # We have an existing address reservation.  Craft an offer.

    $offer = {
      'xid'           => $dhcp_packet->xid(),
      'ip'            => $found_offer->{'ip'},
      'netmask'       => $found_offer->{'netmask'},
      'routers'       => $found_offer->{'options'}->{'routers'},
      'dns'           => $found_offer->{'options'}->{'dns'},
      'domain'        => $found_offer->{'options'}->{'domain'},
      'lease_time'    => $found_offer->{'options'}->{'lease_time'},
      'boot'          => $self->plugin->{'boot'}->find_boot_by_mac_address($mac_address, $dhcp_packet),
    };

  }
  elsif($found_offer = $self->plugin->{'pool'}->find_pool_offer_by_mac_address($mac_address, $dhcp_packet))
  {
    # This machine can take an address from a pool.  Craft an offer.

    $offer = {
      'xid'           => $dhcp_packet->xid(),
      'ip'            => $found_offer->{'ip'},
      'netmask'       => $found_offer->{'netmask'},
      'routers'       => $found_offer->{'options'}->{'routers'},
      'dns'           => $found_offer->{'options'}->{'dns'},
      'domain'        => $found_offer->{'options'}->{'domain'},
      'lease_time'    => $found_offer->{'options'}->{'lease_time'},
      'boot'          => $self->plugin->{'boot'}->find_boot_by_mac_address($mac_address, $dhcp_packet),
    };

  }
  else
  {
    # Nothing we can do for the client.

    $self->plugin->{'session'}->track_session($dhcp_packet, "OFFER UNAVAILABLE", 0);
    return;
  }

  if(!defined($offer->{'lease_time'}) or $offer->{'lease_time'} == 0)
  {
    $offer->{'lease_time'} = $self->config->get("default_lease_time");
  }

  if($offer->{'lease_time'} < $self->config->get("minimum_lease_time"))
  {
    $offer->{'lease_time'} = $self->config->get("minimum_lease_time");
  }

  my ($dhcp_reply, $dhcp_client) = 
    $self->construct_dhcp_reply($dhcp_packet, DHCPOFFER(), $offer);

  $self->plugin->{'lease'}->record_lease($offer->{ip}, $mac_address, "OFFER", $offer);

  $self->plugin->{'network'}->send_dhcp_packet($dhcp_reply, $dhcp_client)
    or die "Error sending DHCPOFFER in response to DHCPDISCOVER: $!";

  $self->plugin->{'session'}->track_session($dhcp_packet, "SELECTING", $offer->{ip});
}

#
# Handle a DHCPREQUEST
#
# We should respond with a DHCPACK to accept their request, or a DHCPNAK to
# reject it (for instance if their DHCPREQUEST differs from our DHCPOFFER).
#
# TODO:
#   * Need to handle/test renewals.  Currently we probably mark the client as
#     "OFFER NOT TAKEN" if they try to renew, due to mismatched server id as
#     compared with ours.
#
sub handle_dhcp_request($$)
{
  my ($self, $dhcp_packet) = @_;

  my $mac_address       = &get_mac_address($dhcp_packet);
  my $server_identifier = $dhcp_packet->getOptionValue(DHO_DHCP_SERVER_IDENTIFIER());
  my $requested_ip      = $dhcp_packet->getOptionValue(DHO_DHCP_REQUESTED_ADDRESS());
  my $client_ip         = $dhcp_packet->ciaddr();
  my $client_session    = $self->plugin->{'session'}->find_session($mac_address);
  my $client_state      = $self->plugin->{'session'}->client_state($mac_address, $client_session, $dhcp_packet);

  $self->plugin->{'session'}->track_session($dhcp_packet, $client_state, $requested_ip);

  if($client_state eq 'REQUESTING' and $server_identifier ne $self->config->get('server_identifier'))
  {
    # The client selected a different server, so we should mark our offer
    # as not taken.  This could be because the client got a better offer
    # from the other server.  We might want to generate some audit log entry
    # in this case, as it would probably imply some misconfiguration.

    $self->plugin->{'session'}->track_session($dhcp_packet, "OFFER NOT TAKEN", 0);
    return;
  }

  if(my $offer = $self->plugin->{'lease'}->find_offer_by_mac_address($mac_address))
  {
    # We found an offer in the database, try to complete this request.

    my ($dhcp_reply, $dhcp_client) = (undef, undef);

    if($client_state eq 'REQUESTING')
    {
      if($dhcp_packet->xid() eq $offer->{'xid'} and $requested_ip eq $offer->{'ip'})
      {
        # The XID is known and the offered IP matches, go ahead and ACK.

        ($dhcp_reply, $dhcp_client) = 
          $self->construct_dhcp_reply($dhcp_packet, DHCPACK(), $offer);
      }
    }

    if($client_state eq 'REBOOTING')
    {
      if($requested_ip eq $offer->{'ip'})
      {
        ($dhcp_reply, $dhcp_client) = 
          $self->construct_dhcp_reply($dhcp_packet, DHCPACK(), $offer);
      }
    }    

    if($client_state eq 'RENEWING' or $client_state eq 'REBINDING')
    {
      if($client_ip eq $offer->{'ip'})
      {
        ($dhcp_reply, $dhcp_client) = 
          $self->construct_dhcp_reply($dhcp_packet, DHCPACK(), $offer);
      }
    }    

    if(defined($dhcp_reply))
    {
      $self->plugin->{'network'}->send_dhcp_packet($dhcp_reply, $dhcp_client)
        or die "Error sending DHCPACK in response to DHCPREQUEST: $!";
  
      $self->plugin->{'lease'}->record_lease($offer->{ip}, $mac_address, "PERMANENT", $offer);
      $self->plugin->{'session'}->track_session($dhcp_packet, "BOUND", $offer->{ip});

      return;
    }
  }
    
  $self->plugin->{'session'}->track_session($dhcp_packet, "UNKNOWN REQUEST", undef);

  my ($dhcp_reply, $dhcp_client) =
    $self->construct_dhcp_reply($dhcp_packet, DHCPNAK(), undef);

  $self->plugin->{'network'}->send_dhcp_packet($dhcp_reply, $dhcp_client)
    or die "Error sending DHCPNAK in response to DHCPREQUEST: $!";
}

#
# Handle a DHCPDECLINE
#
# We should potentially generate an audit log entry on DHCPDECLINE.
# This should never happen in a production network, as it would usually
# imply that the address appeared to be in use already when the client
# tried to assume it.
#
sub handle_dhcp_decline($$)
{
  my ($self, $dhcp_packet) = @_;

  my $mac_address = &get_mac_address($dhcp_packet);

  $self->plugin->{'session'}->track_session($dhcp_packet, "OFFER DECLINED", 0);
}

#
# Handle a DHCPRELEASE
#
# We should potentially mark the host as "shut down".  In practice, these are rarely
# seen on the network, as clients generally do NOT release their IP addresses on
# shutdown (in the hopes that they will get the same IP on restart).
#
sub handle_dhcp_release($$)
{
  my ($self, $dhcp_packet) = @_;

  my $mac_address = &get_mac_address($dhcp_packet);

  if(my $offer = $self->plugin->{'lease'}->find_offer_by_mac_address($mac_address))
  {
    $self->plugin->{'session'}->track_session($dhcp_packet, "RELEASED", 0);

    # XXX We should really release it.  Need to think on this.
    #&record_lease($offer->{ip}, $mac_address, "RELEASED", $offer);
  } else {
    # XXX Log something.  We got a potentially exploitive attempt
    # to release an IP where an offer doesn't exist.
  }  
}

#
# Handle a DHCPINFORM
#
# This is used by the client to try and request various parameters
# as well as to send the DHCP server various parameters.  It should
# be safe to ignore this for now.
#
sub handle_dhcp_inform($$)
{
  my ($self, $dhcp_packet) = @_;
}

1;
