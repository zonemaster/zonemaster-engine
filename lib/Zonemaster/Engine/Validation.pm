package Zonemaster::Engine::Validation;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.0.0");

use Exporter 'import';
BEGIN {
    our @EXPORT_OK = qw[
      validate_ip_for_version
    ];
    our %EXPORT_TAGS = ( all => \@EXPORT_OK );

    ## no critic (Modules::ProhibitAutomaticExportation)
    our @EXPORT = qw[ 
      validate_ip_for_version
    ];
}

use Readonly;
use Net::IP::XS;
use Scalar::Util qw( looks_like_number );

use Zonemaster::Engine::Constants qw[:ip];

Readonly our $IPV4_RE => qr/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/;
Readonly our $IPV6_RE => qr/^[0-9a-f:]*:[0-9a-f:]+(:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})?$/i;

sub validate_ip_for_version {
    my ( $ip, $ip_version ) = @_;

    if ( defined $ip and $ip ne '' and defined $ip_version and looks_like_number( $ip_version ) ) {
        if ( Net::IP::XS->new( $ip ) ) {
            if ( $ip_version == $IP_VERSION_4 and Net::IP::XS::ip_is_ipv4( $ip ) and $ip =~ /($IPV4_RE)/ ) {
                return 1;
            }

            if ( $ip_version == $IP_VERSION_6 and Net::IP::XS::ip_is_ipv6( $ip ) and $ip =~ /($IPV6_RE)/ ) {
                return 1;
            }
        }
    }

    return 0;
}

1;

=head1 NAME

Zonemaster::Engine::Validation - validation functions for other Zonemaster modules

=head1 SYNOPSIS

    use Zonemaster::Engine::Validation qw( validate_ip_for_version );
    my $ip_is_valid = validate_ip_for_version( $ip_address, $ip_version );

=head1 EXPORTED FUNCTIONS

=over

=item validate_ip_for_version

    my $ip_is_valid = validate_ip_for_version( $ip_address, $ip_version );

Checks if the given IP address is valid for the given IP version (4 or 6).

Takes a string (IP address) and an integer (IP version).

Returns a boolean.

=back
