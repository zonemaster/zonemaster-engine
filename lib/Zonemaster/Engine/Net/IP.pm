package Zonemaster::Engine::Net::IP;

use version; our $VERSION = version->declare("v0.0.6");

use strict;
use warnings;

my $p_class = eval {
    require Net::IP::XS;
    return q{Net::IP::XS};
} || eval {
    require Net::IP;
    return q{Net::IP};
};

if ( $p_class ) {
    $p_class->import;
}
else {
    die "Both Net::IP and Net::IP::XS missing?\n";
}

sub new {
    my ( $class, @args ) = @_;
    my $self = {};
    $self->{_inner} = $p_class->new( @args ) or die Error();
    bless( $self, $class );
    return $self;
}

sub ip {
    my $self = shift;
    return $self->{_inner}->ip();
}

sub short {
    my $self = shift;
    return $self->{_inner}->short();
}

sub overlaps {
    my $self = shift;
    my $other = shift;
    return $self->{_inner}->overlaps( $other->{_inner} );
}

sub prefix {
    my $self = shift;
    return $self->{_inner}->prefix();
}

sub prefixlen {
    my $self = shift;
    return $self->{_inner}->prefixlen();
}

sub print {
    my $self = shift;
    return $self->{_inner}->print();
}

sub reverse_ip {
    my $self = shift;
    return $self->{_inner}->reverse_ip();
}

sub version {
    my $self = shift;
    return $self->{_inner}->version();
}

sub ip_is_ipv6 {
    if ( $p_class eq 'Net::IP::XS' ) {
        return Net::IP::XS::ip_is_ipv6( @_ );
    }
    else {
        return Net::IP::ip_is_ipv6( @_ );
    }
}

sub Error {
    if ( $p_class eq 'Net::IP::XS' ) {
        return Net::IP::XS::Error();
    }
    else {
        return Net::IP::Error();
    }
}

1;

=head1 NAME

Zonemaster::Engine::Net::IP - Net::IP/Net::IP::XS Wrapper (STILL EXPERIMENTAL)

=head1 SYNOPSIS

    my $ip = Zonemaster::Engine::Net::IP->new( q{0.0.0.0/8} );

=head1 PROCEDURAL INTERFACE

=over

=item ip_is_ipv6

Check if an IP address is of type 6.

=over

=item Params

IP address

=item Returns

1 (yes) or 0 (no)

=back

    ip_is_ipv6($ip) and print "$ip is IPv6";

=item Error

Returns the error string corresponding to the last error generated in the
module.
This is also useful for the OO interface, as if the new() function fails, we
cannot call $ip->error() and so we have to use Error().

    warn Error();

=back

=head1 METHODS

=over

=item new

Constructor of object.

=item ip

Return the IP address (or first IP of the prefix or range) in quad format, as a string.

    print ($ip->ip());

=item overlaps

Check if two IP ranges/prefixes overlap each other. The value returned by the function should be one of: $IP_PARTIAL_OVERLAP (ranges overlap) $IP_NO_OVERLAP (no overlap) $IP_A_IN_B_OVERLAP (range2 contains range1) $IP_B_IN_A_OVERLAP (range1 contains range2) $IP_IDENTICAL (ranges are identical) undef (problem)

    if ($ip->overlaps($ip2)==$IP_A_IN_B_OVERLAP) {...};

=item prefix

Return the full prefix (ip+prefix length) in quad (standard) format.

    print ($ip->prefix());

=item prefixlen

Return the length in bits of the current prefix.

    print ($ip->prefixlen());

=item print

Print the IP object (IP/Prefix or First - Last)

    print ($ip->print());

=item reverse_ip

Return the reverse IP for a given IP address (in.addr. format).

    print ($ip->reserve_ip());

=item short

Return the IP in short format: IPv4 addresses: 194.5/16 IPv6 addresses: ab32:f000::

print ($ip->short());

=item version

Return the version of the current IP object (4 or 6).

    print ($ip->version());

=back

=cut
