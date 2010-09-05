# Net::TFTP::Constants.pm
# Author: Jeremy Cole

package Net::TFTP::Constants;

# standard module declaration
use 5.8.0;
use strict;
our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);
use Exporter;
$VERSION = 0.01;
@ISA = qw(Exporter);

# Constants
our (%TFTP_OPS,    %REV_TFTP_OPS);
our (%TFTP_ERRORS, %REV_TFTP_ERRORS);
our (%TFTP_PACKET_FORMATS);
our (%TFTP_ERROR_MESSAGES);

%EXPORT_TAGS = (
  tftp_ops => [keys %TFTP_OPS],
  tftp_errors => [keys %TFTP_ERRORS],
  tftp_hashes => [ qw(
            %TFTP_OPS    %REV_TFTP_OPS
            %TFTP_ERRORS %REV_TFTP_ERRORS
            %TFTP_PACKET_FORMATS
            %TFTP_ERROR_MESSAGES
            )],
  );

@EXPORT_OK = qw(
            %TFTP_OPS    %REV_TFTP_OPS
            %TFTP_ERRORS %REV_TFTP_ERRORS
            %TFTP_PACKET_FORMATS
            %TFTP_ERROR_MESSAGES
            );
Exporter::export_tags('tftp_ops');
Exporter::export_tags('tftp_errors');
Exporter::export_tags('tftp_hashes');

BEGIN {
  %TFTP_OPS = (
    'TFTP_RRQ'    => 1,
    'TFTP_WRQ'    => 2,
    'TFTP_DATA'   => 3,
    'TFTP_ACK'    => 4,
    'TFTP_ERROR'  => 5,
  );
    
  %TFTP_ERRORS = (
    'TFTP_UNDEFINED'           => 0,
    'TFTP_FILE_NOT_FOUND'      => 1,
    'TFTP_ACCESS_VIOLATION'    => 2,
    'TFTP_DISK_FULL'           => 3,
    'TFTP_ILLEGAL_OPERATION'   => 4,
    'TFTP_UNKNOWN_TID'         => 5,
    'TFTP_FILE_EXISTS'         => 6,
    'TFTP_NO_USER'             => 7,
  );
  
  %TFTP_PACKET_FORMATS = (
    'TFTP_RRQ'    => 'n Z* Z*',
    'TFTP_RRQ'    => 'n Z* Z*',
    'TFTP_DATA'   => 'n n a',
    'TFTP_ACK'    => 'n n',
    'TFTP_ERROR'  => 'n n Z*',
  );

  %TFTP_ERROR_MESSAGES = (
    'TFTP_UNDEFINED'           => "Undefined error",
    'TFTP_FILE_NOT_FOUND'      => "File not found",
    'TFTP_ACCESS_VIOLATION'    => "Access violation",
    'TFTP_DISK_FULL'           => "Disk full",
    'TFTP_ILLEGAL_OPERATION'   => "Illegal operation",
    'TFTP_UNKNOWN_TID'         => "Unknown transfer ID",
    'TFTP_FILE_EXISTS'         => "File already exists",
    'TFTP_NO_USER'             => "No such user",
  );
}

  use constant \%TFTP_OPS;
  %REV_TFTP_OPS = reverse %TFTP_OPS;
  
  use constant \%TFTP_ERRORS;
  %REV_TFTP_ERRORS = reverse %TFTP_ERRORS;
  
1;

=pod

=head1 NAME

Net::TFTP::Constants - Constants for TFTP codes and options

=head1 SYNOPSIS

  use Net::TFTP::Constants;
  print "TFTP operation RRQ is ", TFTP_RRQ();

=head1 DESCRIPTION

Represents constants used in TFTP protocol, defined in RFC 1350.

=head1 TAGS

Constants can either be imported individually or in sets grouped by tag names.
The tag names are:

=over 4

=item * tftp_ops

Imports all of the I<TFTP> operations constants:

  (01) TFTP_RRQ
  (02) TFTP_WRQ
  (03) TFTP_DATA
  (04) TFTP_ACK
  (05) TFTP_ERROR

=item * tftp_errors

Imports all of the I<TFTP> operations constants:

  (00) TFTP_UNDEFINED
  (01) TFTP_FILE_NOT_FOUND
  (02) TFTP_ACCESS_VIOLATION
  (03) TFTP_DISK_FULL
  (04) TFTP_ILLEGAL_OPERATION
  (05) TFTP_UNKNOWN_TID
  (06) TFTP_FILE_EXISTS
  (07) TFTP_NO_USER

=back

=head1 SEE ALSO

L<Net::TFTP::Packet>

=head1 AUTHOR

Jeremy Cole E<lt>jeremy@jcole.usE<gt>.

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
