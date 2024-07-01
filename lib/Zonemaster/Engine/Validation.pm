package Zonemaster::Engine::Validation;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.0.0");

use Exporter 'import';
BEGIN {
    our @EXPORT_OK = qw[
      validate_ipv4
      validate_ipv6
    ];
    our %EXPORT_TAGS = ( all => \@EXPORT_OK );

    ## no critic (Modules::ProhibitAutomaticExportation)
    our @EXPORT = qw[ 
      validate_ipv4
      validate_ipv6
    ];
}

use Readonly;
use Net::IP::XS;

use Zonemaster::Engine::Constants qw[:ip];

Readonly our $IPV4_RE => qr/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/;
Readonly our $IPV6_RE => qr/^[0-9a-f:]*:[0-9a-f:]+(:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})?$/i;

sub validate_ipv4 {
    my ( $ip ) = @_;

    if ( defined $ip and $ip ne '') {
        if ( Net::IP::XS->new( $ip ) ) {
            if ( Net::IP::XS::ip_is_ipv4( $ip ) and $ip =~ /($IPV4_RE)/ ) {
                return 1;
            }
        }
    }

    return 0;
}

sub validate_ipv6 {
    my ( $ip ) = @_;

    if ( defined $ip and $ip ne '' ) {
        if ( Net::IP::XS->new( $ip ) ) {
            if ( Net::IP::XS::ip_is_ipv6( $ip ) and $ip =~ /($IPV6_RE)/ ) {
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

    use Zonemaster::Engine::Validation qw( validate_ipv4 validate_ipv6 );
    my $ip_is_valid = validate_ipv4( $ip_address );

=head1 EXPORTED FUNCTIONS

=over

=item validate_ipv4

    my $ip_is_valid = validate_ipv4( $ip_address );

Checks if the given IP address is a valid IPv4 address.

Takes a string (IP address).

Returns a boolean.

=item validate_ipv6

    my $ip_is_valid = validate_ipv6( $ip_address );

Checks if the given IP address is a valid IPv6 address.

Takes a string (IP address).

Returns a boolean.

=back
