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

Net::TFTP::Packet - Object methods to create a TFTP packet.

=head1 SYNOPSIS

   use Net::DHCP::Packet;

   my $p = new Net::TFTP::Packet(
     Op      => TFTP_DATA(),
     Block   => $session->{'block'},
     Data    => $data,
     DataLen => $bytes_read,
   );

=head1 DESCRIPTION

Represents a TFTP packet as specified in RFC 1350.

=head1 CONSTRUCTOR

=over 4

=item new( )

=item new( BUFFER )

=item new( ARG => VALUE, ARG => VALUE... )

Creates an C<Net::TFTO::Packet> object, which can be used to send or receive
TFTP network packets.

Without argument, a default empty packet is created.

  $packet = Net::TFTP::Packet();

A C<BUFFER> argument is interpreted as a binary buffer like one provided
by the socket C<recv()> function. If the packet is malformed, a fatal error
is issued.

   use IO::Socket::INET;
   use Net::TFTP::Packet;
   
   $sock = IO::Socket::INET->new(LocalPort => 69, Proto => "udp", Broadcast => 1)
           or die "socket: $@";
           
   while ($sock->recv($newmsg, 1024)) {
       $packet = Net::TFTP::Packet->new($newmsg);
       print $packet->toString();
   }

To create a fresh new packet C<new()> takes arguments as a key-value pairs :

   ARGUMENT   FIELD      OCTETS       DESCRIPTION
   --------   -----      ------       -----------
   
   Op         op            2  TFTP op code.
                               1 = RRQ
                               2 = WRQ
                               3 = DATA
                               4 = ACK
                               5 = ERROR

See below methods for values and syntax description.


=back

=head1 METHODS

=head2 ATTRIBUTE METHODS

=over 4

=item op( [BYTE] )

Sets/gets the I<DHCP opcode>.

Normal values are:

  TFTP_RRQ()
  TFTP_WRQ()
  TFTP_DATA()
  TFTP_ACK()
  TFTP_ERROR()

=back

=head2 SERIALIZATION METHODS

=over 4

=item serialize ()

Converts a Net::TFTP::Packet to a string, ready to put on the network.

=item marshall ( BYTES )

The inverse of serialize. Converts a string, presumably a 
received UDP packet, into a Net::TFTP::Packet.

If the packet is malformed, a fatal error is produced.

=back

=head2 HELPER METHODS

=over 4

=item toString ()

Returns a textual representation of the packet, for debugging.

=back

=head1 EXAMPLES

To be added.

=head1 AUTHOR

Jeremy Cole E<lt>jeremy@jcole.usE<gt>.

=head1 BUGS

Tested only on Linux platform.

=head1 COPYRIGHT

This is free software. It can be distributed and/or modified under the same terms as
Perl itself.

=head1 SEE ALSO

L<Net::TFTP::Constants>

=cut
