package Zonemaster::Engine::Constants;

use version; our $VERSION = version->declare("v1.2.1");

use strict;
use warnings;

use Carp;

use English qw( -no_match_vars ) ;

use parent 'Exporter';
use Zonemaster::Engine::Net::IP;
use Text::CSV;
use File::ShareDir qw[dist_dir dist_file];

use Readonly;

our @EXPORT_OK = qw[
  $ALGO_STATUS_DEPRECATED
  $ALGO_STATUS_PRIVATE
  $ALGO_STATUS_RESERVED
  $ALGO_STATUS_UNASSIGNED
  $ALGO_STATUS_VALID
  $DURATION_12_HOURS_IN_SECONDS
  $DURATION_180_DAYS_IN_SECONDS
  $FQDN_MAX_LENGTH
  $LABEL_MAX_LENGTH
  $IP_VERSION_4
  $IP_VERSION_6
  $MAX_SERIAL_VARIATION
  $MINIMUM_NUMBER_OF_NAMESERVERS
  $SOA_DEFAULT_TTL_MAXIMUM_VALUE
  $SOA_DEFAULT_TTL_MINIMUM_VALUE
  $SOA_EXPIRE_MINIMUM_VALUE
  $SOA_REFRESH_MINIMUM_VALUE
  $SOA_RETRY_MINIMUM_VALUE
  $UDP_PAYLOAD_LIMIT
  $UDP_COMMON_EDNS_LIMIT
  @IPV4_SPECIAL_ADDRESSES
  @IPV6_SPECIAL_ADDRESSES
];

our %EXPORT_TAGS = (
    all  => \@EXPORT_OK,
    algo => [
        qw($ALGO_STATUS_DEPRECATED $ALGO_STATUS_PRIVATE $ALGO_STATUS_RESERVED $ALGO_STATUS_UNASSIGNED $ALGO_STATUS_VALID)
    ],
    name => [qw($FQDN_MAX_LENGTH $LABEL_MAX_LENGTH)],
    ip   => [qw($IP_VERSION_4 $IP_VERSION_6)],
    soa  => [
        qw($SOA_DEFAULT_TTL_MAXIMUM_VALUE $SOA_DEFAULT_TTL_MINIMUM_VALUE $SOA_EXPIRE_MINIMUM_VALUE $SOA_REFRESH_MINIMUM_VALUE $SOA_RETRY_MINIMUM_VALUE $DURATION_12_HOURS_IN_SECONDS $DURATION_180_DAYS_IN_SECONDS $MAX_SERIAL_VARIATION)
    ],
    misc      => [qw($UDP_PAYLOAD_LIMIT $UDP_COMMON_EDNS_LIMIT $MINIMUM_NUMBER_OF_NAMESERVERS)],
    addresses => [qw(@IPV4_SPECIAL_ADDRESSES @IPV6_SPECIAL_ADDRESSES)],
);

Readonly our $ALGO_STATUS_DEPRECATED => 1;
Readonly our $ALGO_STATUS_PRIVATE    => 4;
Readonly our $ALGO_STATUS_RESERVED   => 2;
Readonly our $ALGO_STATUS_UNASSIGNED => 3;
Readonly our $ALGO_STATUS_VALID      => 5;

Readonly our $DURATION_12_HOURS_IN_SECONDS => 12 * 60 * 60;
Readonly our $DURATION_180_DAYS_IN_SECONDS => 180 * 24 * 60 * 60;

# Maximum length of ASCII version of a domain name, with trailing dot.
Readonly our $FQDN_MAX_LENGTH  => 254;
Readonly our $LABEL_MAX_LENGTH => 63;

Readonly our $IP_VERSION_4 => 4;
Readonly our $IP_VERSION_6 => 6;

Readonly our $MAX_SERIAL_VARIATION => 0;

Readonly our $MINIMUM_NUMBER_OF_NAMESERVERS => 2;

Readonly our $SOA_DEFAULT_TTL_MAXIMUM_VALUE => 86_400;     # 1 day
Readonly our $SOA_DEFAULT_TTL_MINIMUM_VALUE => 300;        # 5 minutes
Readonly our $SOA_EXPIRE_MINIMUM_VALUE      => 604_800;    # 1 week
Readonly our $SOA_REFRESH_MINIMUM_VALUE     => 14_400;     # 4 hours
Readonly our $SOA_RETRY_MINIMUM_VALUE       => 3_600;      # 1 hour

Readonly our $UDP_PAYLOAD_LIMIT     => 512;
Readonly our $UDP_COMMON_EDNS_LIMIT => 4_096;

Readonly::Array our @IPV4_SPECIAL_ADDRESSES => _extract_iana_ip_blocks($IP_VERSION_4);

Readonly::Array our @IPV6_SPECIAL_ADDRESSES => _extract_iana_ip_blocks($IP_VERSION_6);

sub _extract_iana_ip_blocks {
    my $ip_version = shift;
    my @list = ();

    my $csv = Text::CSV->new ({
      binary    => 1,
      auto_diag => 1,
      sep_char  => q{,}
    });
    my @files_details = (
        { name => q{iana-ipv4-special-registry.csv}, ip_version => $IP_VERSION_4 },
        { name => q{iana-ipv6-special-registry.csv}, ip_version => $IP_VERSION_6 },
    );

    foreach my $file_details ( @files_details ) {
        my $first_line = 1;
        next if ${$file_details}{ip_version} != $ip_version;
        my $data_location = dist_file('Zonemaster-Engine', ${$file_details}{name});
        open(my $data, '<:encoding(utf8)', $data_location) or croak "Cannot open '${data_location}' : ${OS_ERROR}";
        while (my $fields = $csv->getline( $data )) {
            if ( $first_line ) {
                $first_line = 0;
                next;
            }
            my $address_data = $fields->[0];
            $address_data =~ s/[ ]+//smx;
            foreach my $address_item ( split /,/smx, $address_data ) {
                $address_item =~ s/(\A.+\/\d+).*\z/$1/smx;
                push @list, { ip => Zonemaster::Engine::Net::IP->new( $address_item ), name => $fields->[1], reference => $fields->[2] };
            }
        }
        close $data or croak "Cannot close '${data_location}' : ${OS_ERROR}";
    }

    return @list;
} ## end sub _extract_iana_ip_blocks

1;

=head1 NAME

Zonemaster::Engine::Constants - module holding constants used in test modules

=head1 SYNOPSIS

   use Zonemaster::Engine::Constants ':all';

=head1 EXPORTED GROUPS

=over

=item all

All exportable names.

=item algo

DNSSEC algorithms.

=item name

Label and name lengths.

=item ip

IP version constants.

=item soa

SOA value limits.

=item misc

UDP payload limit and minimum number of nameservers per zone.

=item addresses

Address classes for IPv4 and IPv6.

=item extract_iana_ip_blocks($ip_version)

Will extract IPs details from IANA files.

=back

=head1 EXPORTED NAMES

=over

=item *

C<$ALGO_STATUS_DEPRECATED>

=item *

C<$ALGO_STATUS_PRIVATE>

=item *

C<$ALGO_STATUS_RESERVED>

=item *

C<$ALGO_STATUS_UNASSIGNED>

=item *

C<$ALGO_STATUS_VALID>

=item *

C<$DURATION_12_HOURS_IN_SECONDS>

=item *

C<$DURATION_180_DAYS_IN_SECONDS>

=item *

C<$FQDN_MAX_LENGTH>

=item *

C<$LABEL_MAX_LENGTH>

=item *

C<$IP_VERSION_4>

=item *

C<$IP_VERSION_6>

=item *

C<$MAX_SERIAL_VARIATION>

=item *

C<$MINIMUM_NUMBER_OF_NAMESERVERS>

=item *

C<$SOA_DEFAULT_TTL_MAXIMUM_VALUE>

=item *

C<$SOA_DEFAULT_TTL_MINIMUM_VALUE>

=item *

C<$SOA_EXPIRE_MINIMUM_VALUE>

=item *

C<$SOA_REFRESH_MINIMUM_VALUE>

=item *

C<$SOA_RETRY_MINIMUM_VALUE>

=item *

C<$UDP_PAYLOAD_LIMIT>

=item *

C<UDP_COMMON_EDNS_LIMIT>

=item *

C<@IPV4_SPECIAL_ADDRESSES>

=item *

C<@IPV6_SPECIAL_ADDRESSES>

=back

=cut
