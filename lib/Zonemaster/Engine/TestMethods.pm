package Zonemaster::Engine::TestMethods;

use version; our $VERSION = version->declare("v1.0.3");

use 5.014002;
use strict;
use warnings;

use List::MoreUtils qw[uniq];

use Zonemaster::Engine;
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

=back

=cut

1;
