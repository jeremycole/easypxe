# Net::TFTP::Packet.pm
# Author: Jeremy Cole

package Net::TFTP::Packet;

# standard module declaration
use 5.8.0;
use strict;
our (@ISA, @EXPORT, @EXPORT_OK, $VERSION);
use Exporter;
$VERSION = 0.66;
@ISA = qw(Exporter);
@EXPORT_OK = qw( );

use Socket;
use Carp;
use Net::TFTP::Constants qw(:DEFAULT :tftp_ops :tftp_errors :tftp_hashes);
use Scalar::Util qw(looks_like_number);   # for numerical testing

#=======================================================================
sub new {
  my $class = shift;
  
  my $self = {};
  bless $self, $class;
  if (scalar @_ == 1) { # we build the packet from a binary string
    $self->marshall(shift);
  } else {
    my %args = @_;
    exists($args{Op})     ? $self->op($args{Op})            : $self->{op}      = undef;
    exists($args{File})   ? $self->file($args{File})        : $self->{file}    = undef;    
    exists($args{Mode})   ? $self->mode($args{Mode})        : $self->{mode}    = undef;
    exists($args{Block})  ? $self->block($args{Block})      : $self->{block}   = undef;
    exists($args{Data})   ? $self->data($args{Data})        : $self->{data}    = undef;
    exists($args{DataLen})? $self->datalen($args{DataLen})  : $self->{datalen} = undef;
    exists($args{Code})   ? $self->code($args{Code})        : $self->{code}    = undef;
    exists($args{Message})? $self->message($args{Message})  : $self->{message} = undef;
  }
  return $self;
}

# op attribute
sub op {
    my $self = shift;
    if (@_) { $self->{op} = shift } 
    return $self->{op};
} 

# file attribute
sub file {
  my $self = shift;
  if (@_) { $self->{file} = shift }
  return $self->{file};
}

# mode attribute
sub mode {
  my $self = shift;
  if (@_) { $self->{mode} = shift }
  return $self->{mode};
}

# block attribute
sub block {
  my $self = shift;
  if (@_) { $self->{block} = shift }
  return $self->{block};
}

# data attribute
sub data {
  my $self = shift;
  if (@_) { $self->{data} = shift }
  return $self->{data};
}

# datalen attribute
sub datalen {
  my $self = shift;
  if (@_) { $self->{datalen} = shift }
  return $self->{datalen};
}

# code attribute
sub code {
  my $self = shift;
  if (@_) { $self->{code} = shift }
  return $self->{code};
}

# message attribute
sub message {
  my $self = shift;
  if (@_) { $self->{message} = shift }
  return $self->{message};
}

#=======================================================================
sub serialize {
  use bytes;
  my ($self) = shift;
  my $bytes = undef;
  
  if(0) {
  } elsif($self->{op} == TFTP_RRQ()) {
    $bytes = pack($TFTP_PACKET_FORMATS{'TFTP_RRQ'}, $self->{op}, $self->{file}, $self->{mode});
  } elsif($self->{op} == TFTP_WRQ()) {
    $bytes = pack($TFTP_PACKET_FORMATS{'TFTP_WRQ'}, $self->{op}, $self->{file}, $self->{mode});
  } elsif($self->{op} == TFTP_DATA()) {
    $bytes = pack($TFTP_PACKET_FORMATS{'TFTP_DATA'} . $self->{datalen}, $self->{op}, $self->{block},
      $self->{data}, substr($self->{data}, 0, $self->{datalen}));
  } elsif($self->{op} == TFTP_ACK()) {
    $bytes = pack($TFTP_PACKET_FORMATS{'TFTP_ACK'}, $self->{op}, $self->{block});
  } elsif($self->{op} == TFTP_ERROR()) {
    my $message = $TFTP_ERROR_MESSAGES{$REV_TFTP_ERRORS{$self->code()}} . ": " . $self->message();
    $bytes = pack($TFTP_PACKET_FORMATS{'TFTP_ERROR'}, $self->{op}, $self->{code}, $message);
  } else {
    return undef;
  }

  return $bytes;
}
#=======================================================================
sub marshall {
  use bytes;
  my ($self, $buf) = @_;
  my $opt_buf;
  
  #if (length($buf) < BOOTP_MIN_LEN()) {
  #  carp("marshall: packet too small (".length($buf)."), minimum size is ".BOOTP_MIN_LEN());
  #}
  
  ($self->{op}) = unpack('n', $buf);

  my $x;
  if(0) {
  } elsif($self->{op} == TFTP_RRQ()) {
    ($x, $self->{file}, $self->{mode})    = unpack($TFTP_PACKET_FORMATS{'TFTP_RRQ'}, $buf);
  } elsif($self->{op} == TFTP_WRQ()) {
    ($x, $self->{file}, $self->{mode})    = unpack($TFTP_PACKET_FORMATS{'TFTP_WRQ'}, $buf);
  } elsif($self->{op} == TFTP_DATA()) {
    ($x, $self->{block}, $self->{data})   = unpack($TFTP_PACKET_FORMATS{'TFTP_DATA'} . '*', $buf);
    $self->{datalen} = 512;
  } elsif($self->{op} == TFTP_ACK()) {
    ($x, $self->{block})                  = unpack($TFTP_PACKET_FORMATS{'TFTP_ACK'}, $buf);
  } elsif($self->{op} == TFTP_ERROR()) {
    ($x, $self->{code}, $self->{message}) = unpack($TFTP_PACKET_FORMATS{'TFTP_ERROR'}, $buf);
  } else {
    carp("marshall: Bad opcode ".$self->{op});
    return undef;
  }
  
  return $self;
}

#=======================================================================
sub toString {
  my ($self) = @_;
  my $s = "";
  
  $s .= sprintf("op      = %s\n", (exists($REV_TFTP_OPS{$self->op()}) && $REV_TFTP_OPS{$self->op()}) || $self->op());
  $s .= sprintf("file    = %s\n", defined($self->file()) ? $self->file() : "");
  $s .= sprintf("mode    = %s\n", defined($self->mode()) ? $self->mode() : "");
  $s .= sprintf("block   = %i\n", defined($self->block()) ? $self->block() : 0);
  $s .= sprintf("data    = %s\n", defined($self->data()) ? "data" : "no data");
  $s .= sprintf("datalen = %i\n", defined($self->datalen()) ? $self->datalen() : 0);
  $s .= sprintf("code    = %i\n", defined($self->code()) ? $self->code() : 0);
  $s .= sprintf("message = %s\n", defined($self->message()) ? $self->message() : "");
  
  return $s;
}

#=======================================================================

1;

=pod

=head1 NAME

Net::DHCP::Packet - Object methods to create a DHCP packet.

=head1 SYNOPSIS

   use Net::DHCP::Packet;

   my $p = new Net::DHCP::Packet->new(
        'Chaddr' => '000BCDEF', 
        'Xid' => 0x9F0FD,
        'Ciaddr' => '0.0.0.0',
        'Siaddr' => '0.0.0.0',
        'Hops' => 0);

=head1 DESCRIPTION

Represents a DHCP packet as specified in RFC 1533, RFC 2132.

=head1 CONSTRUCTOR

This module only provides basic constructor. For "easy" constructors, you can use
the L<Net::DHCP::Session> module.  

=over 4

=item new( )

=item new( BUFFER )

=item new( ARG => VALUE, ARG => VALUE... )

Creates an C<Net::DHCP::Packet> object, which can be used to send or receive
DHCP network packets. BOOTP is not supported.

Without argument, a default empty packet is created.

  $packet = Net::DHCP::Packet();

A C<BUFFER> argument is interpreted as a binary buffer like one provided
by the socket C<recv()> function. if the packet is malformed, a fatal error
is issued.

   use IO::Socket::INET;
   use Net::DHCP::Packet;
   
   $sock = IO::Socket::INET->new(LocalPort => 67, Proto => "udp", Broadcast => 1)
           or die "socket: $@";
           
   while ($sock->recv($newmsg, 1024)) {
       $packet = Net::DHCP::Packet->new($newmsg);
       print $packet->toString();
   }

To create a fresh new packet C<new()> takes arguments as a key-value pairs :

   ARGUMENT   FIELD      OCTETS       DESCRIPTION
   --------   -----      ------       -----------
   
   Op         op            1  Message op code / message type.
                               1 = BOOTREQUEST, 2 = BOOTREPLY
   Htype      htype         1  Hardware address type, see ARP section in "Assigned
                               Numbers" RFC; e.g., '1' = 10mb ethernet.
   Hlen       hlen          1  Hardware address length (e.g.  '6' for 10mb
                               ethernet).
   Hops       hops          1  Client sets to zero, optionally used by relay agents
                               when booting via a relay agent.
   Xid        xid           4  Transaction ID, a random number chosen by the
                               client, used by the client and server to associate
                               messages and responses between a client and a
                               server.
   Secs       secs          2  Filled in by client, seconds elapsed since client
                               began address acquisition or renewal process.
   Flags      flags         2  Flags (see figure 2).
   Ciaddr     ciaddr        4  Client IP address; only filled in if client is in
                               BOUND, RENEW or REBINDING state and can respond
                               to ARP requests.
   Yiaddr     yiaddr        4  'your' (client) IP address.
   Siaddr     siaddr        4  IP address of next server to use in bootstrap;
                               returned in DHCPOFFER, DHCPACK by server.
   Giaddr     giaddr        4  Relay agent IP address, used in booting via a
                               relay agent.
   Chaddr     chaddr       16  Client hardware address.
   Sname      sname        64  Optional server host name, null terminated string.
   File       file        128  Boot file name, null terminated string; "generic"
                               name or null in DHCPDISCOVER, fully qualified
                               directory-path name in DHCPOFFER.
   IsDhcp     isDhcp        4  Controls whether the packet is BOOTP or DHCP.
                               DHCP conatains the "magic cookie" of 4 bytes.
                               0x63 0x82 0x53 0x63.
   DHO_*code                   Optional parameters field.  See the options
                               documents for a list of defined options.
                               See Net::DHCP::Constants.
   Padding    padding       *  Optional padding at the end of the packet

See below methods for values and syntax descrption.

Note: DHCP options are created in the same order as key-value pairs.

=back

=head1 METHODS

=head2 ATTRIBUTE METHODS

=over 4

=item op( [BYTE] )

Sets/gets the I<BOOTP opcode>.

Normal values are:

  BOOTREQUEST()
  BOOTREPLY()

=item htype( [BYTE] )

Sets/gets the I<hardware address type>.

Common value is: C<HTYPE_ETHER()> (1) = ethernet

=item hlen ( [BYTE] )

Sets/gets the I<hardware address length>. Value must be between C<0> and C<16>.

For most NIC's, the MAC address has 6 bytes.

=item hops ( [BYTE] )

Sets/gets the I<number of hops>.

This field is incremented by each encountered DHCP relay agent. 

=item xid ( [INTEGER] )

Sets/gets the 32 bits I<transaction id>.

This field should be a random value set by the DHCP client.

=item secs ( [SHORT] )

Sets/gets the 16 bits I<elapsed boot time> in seconds.

=item flags ( [SHORT] )

Sets/gets the 16 bits I<flags>.

  0x8000 = Broadcast reply requested.

=item ciaddr ( [STRING])

Sets/gets the I<client IP address>.

IP address is only accepted as a string like '10.24.50.3'.

Note: IP address is internally stored as a 4 bytes binary string.
See L<Special methods> below.

=item yiaddr ( [STRING] )

Sets/gets the I<your IP address>.

IP address is only accepted as a string like '10.24.50.3'.

Note: IP address is internally stored as a 4 bytes binary string.
See L<Special methods> below.

=item siaddr ( [STRING] )

Sets/gets the I<next server IP address>.

IP address is only accepted as a string like '10.24.50.3'.

Note: IP address is internally stored as a 4 bytes binary string.
See L<Special methods> below.

=item giaddr ( [STRING] )

Sets/gets the I<relay agent IP address>.

IP address is only accepted as a string like '10.24.50.3'.

Note: IP address is internally stored as a 4 bytes binary string.
See L<Special methods> below.

=item chaddr ( [STRING] )

Sets/gets the I<client hardware address>. Its length is given by the C<hlen> attribute.

Valude is formatted as an Hexadecimal string representation.

  Example: "0010A706DFFF" for 6 bytes mac address.

Note : internal format is packed bytes string.
See L<Special methods> below.

=item sname ( [STRING] )

Sets/gets the "server host name". Maximum size is 63 bytes. If greater
a warning is issued.

=item file ( [STRING] )

Sets/gets the "boot file name". Maximum size is 127 bytes. If greater
a warning is issued.

=item isDhcp ( [BOOLEAN] )

Sets/gets the I<DHCP cookie>. Returns whether the cookie is valid or not,
hence whether the packet is DHCP or BOOTP.

Default value is C<1>, valid DHCP cookie.

=item padding ( [BYTES] )

Sets/gets the optional padding at the end of the DHCP packet, i.e. after
DHCP options.

=back

=head2 DHCP OPTIONS METHODS

This section describes how to read or set DHCP options. Methods are given
in two flavours : (i) text format with automatic type conversion,
(ii) raw binary format.

Standard way of accessing options is through automatic type conversion,
described in the L<DHCP OPTION TYPES> section. Only a subset of types
is supported, mainly those defined in rfc 2132.

Raw binary functions are provided for pure performance optimization,
and for unsupported types manipulation.

=over 4

=item addOptionValue ( CODE, VALUE )

Adds a DHCP option field. Common code values are listed in
C<Net::DHCP::Constants> C<DHO_>*.

Values are automatically converted according to their data types,
depending on their format as defined by RFC 2132.
Please see L<DHCP OPTION TYPES> for supported options and corresponding
formats.

If you nedd access to the raw binary values, please use C<addOptionRaw()>.

   $pac = Net::DHCP::Packet->new();
   $pac->addOption(DHO_DHCP_MESSAGE_TYPE(), DHCPINFORM());
   $pac->addOption(DHO_NAME_SERVERS(), "10.0.0.1", "10.0.0.2"));

=item getOptionValue ( CODE )

Returns the value of a DHCP option.

Automatic type conversion is done according to their data types,
as defined in RFC 2132.
Please see L<DHCP OPTION TYPES> for supported options and corresponding
formats.

If you nedd access to the raw binary values, please use C<getOptionRaw()>.

Return value is either a string or an array, depending on the context.

  $ip  = $pac->getOptionValue(DHO_SUBNET_MASK());
  $ips = $pac->getOptionValue(DHO_NAME_SERVERS());

=item addOptionRaw ( CODE, VALUE ) 

Adds a DHCP OPTION provided in packed binary format.
Please see corresponding RFC for manual type conversion.

=item getOptionRaw ( CODE )

Gets a DHCP OPTION provided in packed binary format.
Please see corresponding RFC for manual type conversion.

=item I<addOption ( CODE, VALUE )>

I<Removed as of version 0.60. Please use C<addOptionRaw()> instead.>

=item I<getOption ( CODE )>

I<Removed as of version 0.60. Please use C<getOptionRaw()> instead.>

=back

=item I<removeOption ( CODE )>

Remove option from option list.

=back

=head2 DHCP OPTIONS TYPES

This section describes supported option types (cf. rfc 2132).

For unsupported data types, please use C<getOptionRaw()> and
C<addOptionRaw> to manipulate binary format directly.

=over 4

=item dhcp message type

Only supported for DHO_DHCP_MESSAGE_TYPE (053) option.
Converts a integer to a single byte.

Option code for 'dhcp message' format:

  (053) DHO_DHCP_MESSAGE_TYPE

Example:

  $pac->addOptionValue(DHO_DHCP_MESSAGE_TYPE(), DHCPINFORM());

=item string

Pure string attribute, no type conversion.

Option codes for 'string' format:

  (012) DHO_HOST_NAME
  (014) DHO_MERIT_DUMP
  (015) DHO_DOMAIN_NAME
  (017) DHO_ROOT_PATH
  (018) DHO_EXTENSIONS_PATH
  (047) DHO_NETBIOS_SCOPE
  (056) DHO_DHCP_MESSAGE
  (060) DHO_VENDOR_CLASS_IDENTIFIER
  (062) DHO_NWIP_DOMAIN_NAME
  (064) DHO_NIS_DOMAIN
  (065) DHO_NIS_SERVER
  (066) DHO_TFTP_SERVER
  (067) DHO_BOOTFILE
  (086) DHO_NDS_TREE_NAME
  (098) DHO_USER_AUTHENTICATION_PROTOCOL

Example:

  $pac->addOptionValue(DHO_TFTP_SERVER(), "foobar");

=item single ip address

Exactly one IP address, in dotted numerical format '192.168.1.1'.

Option codes for 'single ip address' format:

  (001) DHO_SUBNET_MASK
  (016) DHO_SWAP_SERVER
  (028) DHO_BROADCAST_ADDRESS
  (032) DHO_ROUTER_SOLICITATION_ADDRESS
  (050) DHO_DHCP_REQUESTED_ADDRESS
  (054) DHO_DHCP_SERVER_IDENTIFIER
  (118) DHO_SUBNET_SELECTION

Example:

  $pac->addOptionValue(DHO_SUBNET_MASK(), "255.255.255.0");

=item multiple ip addresses

Any number of IP address, in dotted numerical format '192.168.1.1'.
Empty value allowed.

Option codes for 'multiple ip addresses' format:

  (003) DHO_ROUTERS
  (004) DHO_TIME_SERVERS
  (005) DHO_NAME_SERVERS
  (006) DHO_DOMAIN_NAME_SERVERS
  (007) DHO_LOG_SERVERS
  (008) DHO_COOKIE_SERVERS
  (009) DHO_LPR_SERVERS
  (010) DHO_IMPRESS_SERVERS
  (011) DHO_RESOURCE_LOCATION_SERVERS
  (041) DHO_NIS_SERVERS
  (042) DHO_NTP_SERVERS
  (044) DHO_NETBIOS_NAME_SERVERS
  (045) DHO_NETBIOS_DD_SERVER
  (048) DHO_FONT_SERVERS
  (049) DHO_X_DISPLAY_MANAGER
  (068) DHO_MOBILE_IP_HOME_AGENT
  (069) DHO_SMTP_SERVER
  (070) DHO_POP3_SERVER
  (071) DHO_NNTP_SERVER
  (072) DHO_WWW_SERVER
  (073) DHO_FINGER_SERVER
  (074) DHO_IRC_SERVER
  (075) DHO_STREETTALK_SERVER
  (076) DHO_STDA_SERVER
  (085) DHO_NDS_SERVERS

Example:

  $pac->addOptionValue(DHO_NAME_SERVERS(), "10.0.0.11 192.168.1.10");

=item pairs of ip addresses

Even number of IP address, in dotted numerical format '192.168.1.1'.
Empty value allowed.

Option codes for 'pairs of ip address' format:

  (021) DHO_POLICY_FILTER
  (033) DHO_STATIC_ROUTES

Example:

  $pac->addOptionValue(DHO_STATIC_ROUTES(), "10.0.0.1 192.168.1.254");

=item byte, short and integer

Numerical value in byte (8 bits), short (16 bits) or integer (32 bits)
format.

Option codes for 'byte (8)' format:

  (019) DHO_IP_FORWARDING
  (020) DHO_NON_LOCAL_SOURCE_ROUTING
  (023) DHO_DEFAULT_IP_TTL
  (027) DHO_ALL_SUBNETS_LOCAL
  (029) DHO_PERFORM_MASK_DISCOVERY
  (030) DHO_MASK_SUPPLIER
  (031) DHO_ROUTER_DISCOVERY
  (034) DHO_TRAILER_ENCAPSULATION
  (036) DHO_IEEE802_3_ENCAPSULATION
  (037) DHO_DEFAULT_TCP_TTL
  (039) DHO_TCP_KEEPALIVE_GARBAGE
  (046) DHO_NETBIOS_NODE_TYPE
  (052) DHO_DHCP_OPTION_OVERLOAD
  (116) DHO_AUTO_CONFIGURE

Option codes for 'short (16)' format:

  (013) DHO_BOOT_SIZE
  (022) DHO_MAX_DGRAM_REASSEMBLY
  (026) DHO_INTERFACE_MTU
  (057) DHO_DHCP_MAX_MESSAGE_SIZE

Option codes for 'integer (32)' format:

  (002) DHO_TIME_OFFSET
  (024) DHO_PATH_MTU_AGING_TIMEOUT
  (035) DHO_ARP_CACHE_TIMEOUT
  (038) DHO_TCP_KEEPALIVE_INTERVAL
  (051) DHO_DHCP_LEASE_TIME
  (058) DHO_DHCP_RENEWAL_TIME
  (059) DHO_DHCP_REBINDING_TIME

Examples:

  $pac->addOptionValue(DHO_DHCP_OPTION_OVERLOAD(), 3);
  $pac->addOptionValue(DHO_INTERFACE_MTU(), 1500);
  $pac->addOptionValue(DHO_DHCP_RENEWAL_TIME(), 24*60*60);

=item multiple bytes, shorts

A list a bytes or shorts.

Option codes for 'multiple bytes (8)' format:

  (055) DHO_DHCP_PARAMETER_REQUEST_LIST

Option codes for 'multiple shorts (16)' format:

  (025) DHO_PATH_MTU_PLATEAU_TABLE
  (117) DHO_NAME_SERVICE_SEARCH

Examples:

  $pac->addOptionValue(DHO_DHCP_PARAMETER_REQUEST_LIST(),  "1 3 6 12 15 28 42 72");

=back

=head2 SERIALIZATION METHODS

=over 4

=item serialize ()

Converts a Net::DHCP::Packet to a string, ready to put on the network.

=item marshall ( BYTES )

The inverse of serialize. Converts a string, presumably a 
received UDP packet, into a Net::DHCP::Packet.

If the packet is malformed, a fatal error is produced.

=back

=head2 HELPER METHODS

=over 4

=item toString ()

Returns a textual representation of the packet, for debugging.

=item packinet ( STRING )

Transforms a IP address "xx.xx.xx.xx" into a packed 4 bytes string.

These are simple never failing versions of inet_ntoa and inet_aton.

=item packinets ( STRING )

Transforms a list of space delimited IP addresses into a packed bytes string.

=item unpackinet ( STRING )

Transforms a packed bytes IP address into a "xx.xx.xx.xx" string.

=item unpackinets ( STRING )

Transforms a packed bytes liste of IP addresses into a list of
"xx.xx.xx.xx" space delimited string.

=back

=head2 SPECIAL METHODS

These methods are provided for performance tuning only. They give access
to internal data representation , thus avoiding unnecessary type conversion.

=over 4

=item ciaddrRaw ( [STRING])

Sets/gets the I<client IP address> in packed 4 characters binary strings.

=item yiaddrRaw ( [STRING] )

Sets/gets the I<your IP address> in packed 4 characters binary strings.

=item siaddrRaw ( [STRING] )

Sets/gets the I<next server IP address> in packed 4 characters binary strings.

=item giaddrRaw ( [STRING] )

Sets/gets the I<relay agent IP address> in packed 4 characters binary strings.

=item chaddrRaw ( [STRING] )

Sets/gets the I<client hardware address> in packed binary string.
Its length is given by the C<hlen> attribute.

=back

=head1 EXAMPLES

Sending a simple DHCP packet:

  #!/usr/bin/perl
  # Simple DHCP client - sending a broadcasted DHCP Discover request
  
  use IO::Socket::INET;
  use Net::DHCP::Packet;
  use Net::DHCP::Constants;
  
  # creat DHCP Packet
  $discover = Net::DHCP::Packet->new(
                        xid => int(rand(0xFFFFFFFF)), # random xid
                        Flags => 0x8000,              # ask for broadcast answer
                        DHO_DHCP_MESSAGE_TYPE() => DHCPDISCOVER()
                        );
  
  # send packet
  $handle = IO::Socket::INET->new(Proto => 'udp',
                                  Broadcast => 1,
                                  PeerPort => '67',
                                  LocalPort => '68',
                                  PeerAddr => '255.255.255.255')
                or die "socket: $@";     # yes, it uses $@ here
  $handle->send($discover->serialize())
                or die "Error sending broadcast inform:$!\n";

Sniffing DHCP packets.

  #!/usr/bin/perl
  # Simple DHCP server - listen to DHCP packets and print them
  
  use IO::Socket::INET;
  use Net::DHCP::Packet;
  $sock = IO::Socket::INET->new(LocalPort => 67, Proto => "udp", Broadcast => 1)
          or die "socket: $@";
  while ($sock->recv($newmsg, 1024)) {
          $packet = Net::DHCP::Packet->new($newmsg);
          print STDERR $packet->toString();
  }

Sending a LEASEQUERY (provided by John A. Murphy).

  #!/usr/bin/perl
  # Simple DHCP client - send a LeaseQuery (by IP) and receive the response
  
  use IO::Socket::INET;
  use Net::DHCP::Packet;
  use Net::DHCP::Constants;
  
  $usage = "usage: $0 DHCP_SERVER_IP DHCP_CLIENT_IP\n"; $ARGV[1] || die $usage;
  
  # create a socket
  $handle = IO::Socket::INET->new(Proto => 'udp',
                                  Broadcast => 1,
                                  PeerPort => '67',
                                  LocalPort => '67',
                                  PeerAddr => $ARGV[0])
                or die "socket: $@";     # yes, it uses $@ here
  
  # create DHCP Packet
  $inform = Net::DHCP::Packet->new(
                      op => BOOTREQUEST(),
                      Htype  => '0',
                      Hlen   => '0',
                      Ciaddr => $ARGV[1],
                      Giaddr => $handle->sockhost(),
                      Xid => int(rand(0xFFFFFFFF)),     # random xid
                      DHO_DHCP_MESSAGE_TYPE() => DHCPLEASEQUERY
                      );
  
  # send request
  $handle->send($inform->serialize()) or die "Error sending LeaseQuery: $!\n";
  
  #receive response
  $handle->recv($newmsg, 1024) or die;
  $packet = Net::DHCP::Packet->new($newmsg);
  print $packet->toString();

A simple DHCP Server is provided in the "examples" directory. It is composed of
"dhcpd.pl" a *very* simple server example, and "dhcpd_test.pl" a simple tester for
this server.

=head1 AUTHOR

Stephan Hadinger E<lt>shadinger@cpan.orgE<gt>.
Original version by F. van Dun.

=head1 BUGS

Fully tested on windows platforms (2000/XP). Not yet tested on Unix platform.

=head1 COPYRIGHT

This is free software. It can be distributed and/or modified under the same terms as
Perl itself.

=head1 SEE ALSO

L<Net::DHCP::Options>, L<Net::DHCP::Constants>.

Note: there is a Java version of this library: L<http://dhcp4java.sourceforge.net/>.

=cut
