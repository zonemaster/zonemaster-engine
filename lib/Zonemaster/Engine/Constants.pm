package Zonemaster::Engine::Constants;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.2.5");

use Carp;
use English qw( -no_match_vars ) ;
use parent 'Exporter';
use Net::IP::XS;
use Text::CSV;
use File::ShareDir qw[dist_dir dist_file];

use Readonly;

=head1 NAME

Zonemaster::Engine::Constants - module holding constants used in Test modules

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

SOA values limits.

=item misc

Other, uncategorized export names, e.g. UDP payload limit and minimum number of name servers per zone.

=item addresses

Address classes for IPv4 and IPv6.

=back

=cut

our @EXPORT_OK = qw[
  $ALGO_STATUS_DEPRECATED
  $ALGO_STATUS_PRIVATE
  $ALGO_STATUS_RESERVED
  $ALGO_STATUS_UNASSIGNED
  $ALGO_STATUS_OTHER
  $ALGO_STATUS_NOT_RECOMMENDED
  $ALGO_STATUS_NOT_ZONE_SIGN
  $BLACKLISTING_ENABLED
  $DURATION_5_MINUTES_IN_SECONDS
  $DURATION_1_HOUR_IN_SECONDS
  $DURATION_4_HOURS_IN_SECONDS
  $DURATION_12_HOURS_IN_SECONDS
  $DURATION_1_DAY_IN_SECONDS
  $DURATION_1_WEEK_IN_SECONDS
  $DURATION_180_DAYS_IN_SECONDS
  $FQDN_MAX_LENGTH
  $IP_VERSION_4
  $IP_VERSION_6
  $LABEL_MAX_LENGTH
  $SERIAL_BITS
  $SERIAL_MAX_VARIATION
  $MINIMUM_NUMBER_OF_NAMESERVERS
  $UDP_PAYLOAD_LIMIT
  $UDP_EDNS_QUERY_DEFAULT
  $UDP_COMMON_EDNS_LIMIT
  @IPV4_SPECIAL_ADDRESSES
  @IPV6_SPECIAL_ADDRESSES
];

our %EXPORT_TAGS = (
    all  => \@EXPORT_OK,
    algo => [
        qw($ALGO_STATUS_DEPRECATED $ALGO_STATUS_PRIVATE $ALGO_STATUS_RESERVED $ALGO_STATUS_UNASSIGNED $ALGO_STATUS_OTHER $ALGO_STATUS_NOT_ZONE_SIGN $ALGO_STATUS_NOT_RECOMMENDED)
    ],
    name => [qw($FQDN_MAX_LENGTH $LABEL_MAX_LENGTH)],
    ip   => [qw($IP_VERSION_4 $IP_VERSION_6)],
    soa  => [
        qw($DURATION_5_MINUTES_IN_SECONDS $DURATION_1_HOUR_IN_SECONDS $DURATION_4_HOURS_IN_SECONDS $DURATION_12_HOURS_IN_SECONDS $DURATION_1_DAY_IN_SECONDS $DURATION_1_WEEK_IN_SECONDS $DURATION_180_DAYS_IN_SECONDS $SERIAL_BITS $SERIAL_MAX_VARIATION)
    ],
    misc => [qw($UDP_PAYLOAD_LIMIT $UDP_EDNS_QUERY_DEFAULT $UDP_COMMON_EDNS_LIMIT $MINIMUM_NUMBER_OF_NAMESERVERS $BLACKLISTING_ENABLED)]
    ,    # everything in %EXPORT_OK that isn't included in any of the other tags
    addresses => [qw(@IPV4_SPECIAL_ADDRESSES @IPV6_SPECIAL_ADDRESSES)],
);

=head1 EXPORTED NAMES

=over

=item * C<$ALGO_STATUS_DEPRECATED>

=item * C<$ALGO_STATUS_PRIVATE>

=item * C<$ALGO_STATUS_RESERVED>

=item * C<$ALGO_STATUS_UNASSIGNED>

=item * C<$ALGO_STATUS_OTHER>

=item * C<$ALGO_STATUS_NOT_RECOMMENDED>

=item * C<$ALGO_STATUS_NOT_ZONE_SIGN>

=item * C<$DURATION_5_MINUTES_IN_SECONDS>

=item * C<$DURATION_1_HOUR_IN_SECONDS>

=item * C<$DURATION_4_HOURS_IN_SECONDS>

=item * C<$DURATION_12_HOURS_IN_SECONDS>

=item * C<$DURATION_1_DAY_IN_SECONDS>

=item * C<$DURATION_1_WEEK_IN_SECONDS>

=item * C<$DURATION_180_DAYS_IN_SECONDS>

=item * C<$FQDN_MAX_LENGTH>

=item * C<$LABEL_MAX_LENGTH>

=item * C<$IP_VERSION_4>

=item * C<$IP_VERSION_6>

=item * C<$SERIAL_BITS>

An integer, used to define the size of the serial number space, as defined in RFC1982, section 2.

=item * C<$SERIAL_MAX_VARIATION>

=item * C<$MINIMUM_NUMBER_OF_NAMESERVERS>

=item * C<$UDP_PAYLOAD_LIMIT>

=item * C<$UDP_EDNS_QUERY_DEFAULT>

An integer, used to define the EDNS0 UDP packet size in EDNS queries.

=item * C<$UDP_COMMON_EDNS_LIMIT>

=item * C<@IPV4_SPECIAL_ADDRESSES>

=item * C<@IPV6_SPECIAL_ADDRESSES>

=back

=cut

Readonly our $ALGO_STATUS_DEPRECATED      => 1;
Readonly our $ALGO_STATUS_PRIVATE         => 4;
Readonly our $ALGO_STATUS_RESERVED        => 2;
Readonly our $ALGO_STATUS_UNASSIGNED      => 3;
Readonly our $ALGO_STATUS_OTHER           => 5;
Readonly our $ALGO_STATUS_NOT_ZONE_SIGN   => 8;
Readonly our $ALGO_STATUS_NOT_RECOMMENDED => 9;

Readonly our $BLACKLISTING_ENABLED     => 1;

Readonly our $DURATION_5_MINUTES_IN_SECONDS  =>             5 * 60;
Readonly our $DURATION_1_HOUR_IN_SECONDS     =>            60 * 60;
Readonly our $DURATION_4_HOURS_IN_SECONDS    =>        4 * 60 * 60;
Readonly our $DURATION_12_HOURS_IN_SECONDS   =>       12 * 60 * 60;
Readonly our $DURATION_1_DAY_IN_SECONDS      =>       24 * 60 * 60;
Readonly our $DURATION_1_WEEK_IN_SECONDS     =>   7 * 24 * 60 * 60;
Readonly our $DURATION_180_DAYS_IN_SECONDS   => 180 * 24 * 60 * 60;

# Maximum length of ASCII version of a domain name, with trailing dot.
Readonly our $FQDN_MAX_LENGTH  => 254;
Readonly our $LABEL_MAX_LENGTH => 63;

Readonly our $IP_VERSION_4 => 4;
Readonly our $IP_VERSION_6 => 6;

Readonly our $MINIMUM_NUMBER_OF_NAMESERVERS => 2;

Readonly our $SERIAL_BITS => 32;
Readonly our $SERIAL_MAX_VARIATION => 0;

Readonly our $UDP_PAYLOAD_LIMIT      => 512;
Readonly our $UDP_EDNS_QUERY_DEFAULT => 512;
Readonly our $UDP_COMMON_EDNS_LIMIT  => 4_096;

Readonly::Array our @IPV4_SPECIAL_ADDRESSES => _extract_iana_ip_blocks($IP_VERSION_4);

Readonly::Array our @IPV6_SPECIAL_ADDRESSES => _extract_iana_ip_blocks($IP_VERSION_6);

=head1 METHODS

=over

=item _extract_iana_ip_blocks()

    my @array = _extract_iana_ip_blocks( $ip_version );

Internal method that is used to extract IP blocks details from IANA files for a given IP version (i.e. 4 or 6).

Takes an integer (IP version).

Returns a list of hashes - the keys of which are C<ip> (L<Net::IP::XS> object), C<name> (string) and C<reference> (string).

=back

=cut

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
        my $makefile_name = 'Zonemaster-Engine'; # This must be the same name as "name" in Makefile.PL
        my $data_location = dist_file($makefile_name, ${$file_details}{name});
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
                push @list, { ip => Net::IP::XS->new( $address_item ), name => $fields->[1], reference => $fields->[2] };
            }
        }
        close $data or croak "Cannot close '${data_location}' : ${OS_ERROR}";
    }

    return @list;
} ## end sub _extract_iana_ip_blocks

1;
