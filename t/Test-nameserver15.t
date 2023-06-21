use strict;
use warnings;

use Test::More;
use File::Slurp;
use File::Basename;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Nameserver} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $checking_module = q{Nameserver};
my $testcase = 'nameserver15';
my $datafile = 't/' . basename ($0, '.t') . '.data';

sub zone_gives {
    my ( $test, $zone, $gives_ref ) = @_;
    Zonemaster::Engine->logger->clear_history();
    my @res = grep { $_->tag !~ /^TEST_CASE_(END|START)$/ } Zonemaster::Engine->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( ( grep { $_->tag eq $gives } @res ), $zone->name->string . " gives $gives" );
    }
    return scalar( @res );
}

sub zone_gives_not {
    my ( $test, $zone, $gives_ref ) = @_;

    Zonemaster::Engine->logger->clear_history();
    my @res = grep { $_->tag !~ /^TEST_CASE_(END|START)$/ } Zonemaster::Engine->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( !( grep { $_->tag eq $gives } @res ), $zone->name->string . " does not give $gives" );
    }
    return scalar( @res );
}

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

my ($json, $profile_test);
$json         = qq({ "test_cases": [ "$testcase" ] });
$profile_test = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

###
my $zone = Zonemaster::Engine->zone( q{} );

$zone = Zonemaster::Engine->zone( 'zonemaster.net' );
zone_gives( $testcase, $zone, [qw{N15_SOFTWARE_VERSION N15_NO_VERSION}] );

$zone = Zonemaster::Engine->zone( 'zonemaster.fr' );
zone_gives( $testcase, $zone, [qw{N15_SOFTWARE_VERSION}] );
zone_gives_not( $testcase, $zone, [qw{N15_NO_VERSION}] );

# TODO: {
#     my @missing = qw( );
#     local $TODO = "Need to find/create zones with those errors: ";
#     warn $TODO, "\n\t", join("\n\t", @missing), "\n";
# }
###

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;