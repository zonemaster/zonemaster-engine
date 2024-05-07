package Zonemaster::Engine::TestMethods;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare("v1.0.3");

use List::MoreUtils qw[uniq];
use Zonemaster::Engine::Util;

sub method1 {
    my ( $class, $zone ) = @_;

    return $zone->parent;
}

sub method2 {
    my ( $class, $zone ) = @_;

    return $zone->glue_names;
}

sub method3 {
    my ( $class, $zone ) = @_;

    my @child_nsnames;
    my @nsnames;
    my $ns_aref = $zone->query_all( $zone->name, q{NS} );
    foreach my $p ( @{$ns_aref} ) {
        next if not $p;
        push @nsnames, $p->get_records_for_name( q{NS}, $zone->name );
    }
    @child_nsnames = uniq map { name( lc( $_->nsdname ) ) } @nsnames;

    return [@child_nsnames];
}

sub method4 {
    my ( $class, $zone ) = @_;

    return $zone->glue;
}

sub method5 {
    my ( $class, $zone ) = @_;

    return $zone->ns;
}

sub method2and3 {
    my ( $class, $zone ) = @_;

    my %union = map { $_->string => $_ } @{ $class->method2( $zone ) }, @{ $class->method3( $zone ) };
    return [ @union{ sort keys %union } ];
}

sub method4and5 {
    my ( $class, $zone ) = @_;

    my %union = map { $_->string => $_ } @{ $class->method4( $zone ) }, @{ $class->method5( $zone ) };
    return [ @union{ sort keys %union } ];
}

=head1 NAME

Zonemaster::Engine::TestMethods - Methods common to Test Specification used in test modules

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::TestMethods->method1($zone);

=head1 METHODS

For details on what these methods implement, see the test
specification documents.

=over

=item method1($zone)

Returns either a Zonemaster::Engine::Zone or undef.

=item method2($zone)

Returns an arrayref of Zonemaster::Engine::DNSName objects.

=item method3($zone)

Returns an arrayref of Zonemaster::Engine::DNSName objects.

=item method4($zone)

Returns something that behaves like an arrayref of Zonemaster::Engine::Nameserver objects.

=item method5($zone)

Returns something that behaves like an arrayref of Zonemaster::Engine::Nameserver objects.

=item method2and3($zone)

Returns the union of Zonemaster::Engine::DNSName objects returned by
method2($zone) and method3($zone) in a arrayref.
The elements are sorted according to their string representation.

=item method4and5($zone)

Returns the union of Zonemaster::Engine::Nameserver objects returned by
method4($zone) and method5($zone) in a arrayref.
The elements are sorted according to their string representation.

=back

=cut

1;
