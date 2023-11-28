use Test::More;
use File::Basename;

use 5.14.2;
use strict;
use warnings;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Recursor} );
    use_ok( q{Zonemaster::Engine::Util}, qw( name ) );
}

my $datafile = 't/' . basename ($0, '.t') . '.data';

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

# Common hint file (test-zone-data/COMMON/hintfile)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'ns1' => [ '127.1.0.1', 'fda1:b2:c3::127:1:0:1' ],
      'ns2' => [ '127.1.0.2', 'fda1:b2:c3::127:1:0:2' ],
    }
);

# Test zone scenarios
# GOOD-CNAME-1
my $p = Zonemaster::Engine->recurse( 'good-cname-1.cname.recursor.engine.xa' );
isa_ok( $p, 'Zonemaster::Engine::Packet' );
is( scalar( $p->answer ), 2, 'two records in answer section' );

isa_ok( ($p->answer)[0], 'Zonemaster::LDNS::RR::CNAME' );
is( name( ($p->answer)[0]->owner ), 'good-cname-1.cname.recursor.engine.xa', 'RR name ok' );
is( name( ($p->answer)[0]->cname ), 'good-cname-1-target.cname.recursor.engine.xa', 'RR cname ok' );

isa_ok( ($p->answer)[1], 'Zonemaster::LDNS::RR::A' );
is( name( ($p->answer)[1]->owner ), 'good-cname-1-target.cname.recursor.engine.xa', 'RR name ok' );
is( ($p->answer)[1]->address, '127.0.0.1', 'RR address ok' );

# GOOD-CNAME-2
$p = Zonemaster::Engine->recurse( 'good-cname-2.cname.recursor.engine.xa' );
isa_ok( $p, 'Zonemaster::Engine::Packet' );
is( scalar( $p->answer ), 3, 'three records in answer section' );

isa_ok( ($p->answer)[0], 'Zonemaster::LDNS::RR::CNAME' );
is( name( ($p->answer)[0]->owner ), 'good-cname-2.cname.recursor.engine.xa', 'RR name ok' );
is( name( ($p->answer)[0]->cname ), 'good-cname-2-target.cname.recursor.engine.xa', 'RR cname ok' );

isa_ok( ($p->answer)[1], 'Zonemaster::LDNS::RR::A' );
is( name( ($p->answer)[1]->owner ), 'good-cname-2-target.cname.recursor.engine.xa', 'RR name ok' );
is( ($p->answer)[1]->address, '127.0.0.1', 'RR address ok' );

isa_ok( ($p->answer)[2], 'Zonemaster::LDNS::RR::A' );
is( name( ($p->answer)[2]->owner ), 'good-cname-2-target.cname.recursor.engine.xa', 'RR name ok' );
is( ($p->answer)[2]->address, '127.0.0.2', 'RR address ok' );

# GOOD-CNAME-CHAIN
$p = Zonemaster::Engine->recurse( 'good-cname-chain.cname.recursor.engine.xa' );
isa_ok( $p, 'Zonemaster::Engine::Packet' );
is( scalar( $p->answer ), 4, 'four records in answer section' );

isa_ok( ($p->answer)[0], 'Zonemaster::LDNS::RR::CNAME' );
is( name( ($p->answer)[0]->owner ), 'good-cname-chain.cname.recursor.engine.xa', 'RR name ok' );
is( name( ($p->answer)[0]->cname ), 'good-cname-chain-two.cname.recursor.engine.xa', 'RR cname ok' );

isa_ok( ($p->answer)[1], 'Zonemaster::LDNS::RR::CNAME' );
is( name( ($p->answer)[1]->owner ), 'good-cname-chain-two.cname.recursor.engine.xa', 'RR name ok' );
is( name( ($p->answer)[1]->cname ), 'good-cname-chain-three.cname.recursor.engine.xa', 'RR cname ok' );

isa_ok( ($p->answer)[2], 'Zonemaster::LDNS::RR::CNAME' );
is( name( ($p->answer)[2]->owner ), 'good-cname-chain-three.cname.recursor.engine.xa', 'RR name ok' );
is( name( ($p->answer)[2]->cname ), 'good-cname-chain-target.cname.recursor.engine.xa', 'RR cname ok' );

isa_ok( ($p->answer)[3], 'Zonemaster::LDNS::RR::A' );
is( name( ($p->answer)[3]->owner ), 'good-cname-chain-target.cname.recursor.engine.xa', 'RR name ok' );
is( ($p->answer)[3]->address, '127.0.0.1', 'RR address ok' );

# GOOD-CNAME-OUT-OF-ZONE
$p = Zonemaster::Engine->recurse( 'good-cname-out-of-zone.cname.recursor.engine.xa' );
isa_ok( $p, 'Zonemaster::Engine::Packet' );
is( scalar( $p->answer ), 1, 'one record in answer section' );

isa_ok( ($p->answer)[0], 'Zonemaster::LDNS::RR::A' );
is( name( ($p->answer)[0]->owner ), 'target.goodsub.cname.recursor.engine.xa', 'RR name ok' );
is( ($p->answer)[0]->address, '127.0.0.1', 'RR address ok' );

# NXDOMAIN-VIA-CNAME
$p = Zonemaster::Engine->recurse( 'nxdomain-via-cname.cname.recursor.engine.xa' );
isa_ok( $p, 'Zonemaster::Engine::Packet' );
is( $p->rcode, 'NXDOMAIN', 'NXDOMAIN in response' );
is( scalar( $p->answer ), 0, 'no records in answer section' );
is( scalar( $p->authority ), 1, 'one record in authority section' );

isa_ok( ($p->authority)[0], 'Zonemaster::LDNS::RR::SOA' );
is( name( ($p->authority)[0]->owner ), 'cname.recursor.engine.xa', 'RR name ok' );

# NODATA-VIA-CNAME
$p = Zonemaster::Engine->recurse( 'nodata-via-cname.cname.recursor.engine.xa' );
isa_ok( $p, 'Zonemaster::Engine::Packet' );
is( $p->rcode, 'NOERROR', 'NOERROR in response' );
is( scalar( $p->answer ), 0, 'no records in answer section' );
is( scalar( $p->authority ), 1, 'one record in authority section' );

isa_ok( ($p->authority)[0], 'Zonemaster::LDNS::RR::SOA' );
is( name( ($p->authority)[0]->owner ), 'cname.recursor.engine.xa', 'RR name ok' );

# MULT-CNAME
$p = Zonemaster::Engine->recurse( 'mult-cname.cname.recursor.engine.xa' );
is( $p, undef, "undefined as expected");
my %res = map { $_->tag => $_ } @{ Zonemaster::Engine->logger->entries };
ok( $res{CNAME_MULTIPLE_FOR_NAME}, q{should emit CNAME_MULTIPLE_FOR_NAME} );

# LOOPED-CNAME-IN-ZONE-1
$p = Zonemaster::Engine->recurse( 'looped-cname-in-zone-1.cname.recursor.engine.xa' );
is( $p, undef, "undefined as expected");
%res = map { $_->tag => $_ } @{ Zonemaster::Engine->logger->entries };
ok( $res{CNAME_LOOP_INNER}, q{should emit CNAME_LOOP_INNER} );

# LOOPED-CNAME-IN-ZONE-2
$p = Zonemaster::Engine->recurse( 'looped-cname-in-zone-2.cname.recursor.engine.xa' );
is( $p, undef, "undefined as expected");
%res = map { $_->tag => $_ } @{ Zonemaster::Engine->logger->entries };
ok( $res{CNAME_LOOP_INNER}, q{should emit CNAME_LOOP_INNER} );

# LOOPED-CNAME-OUT-OF-ZONE
$p = Zonemaster::Engine->recurse( 'looped-cname-out-of-zone.sub2.cname.recursor.engine.xa' );
is( $p, undef, "undefined as expected");
%res = map { $_->tag => $_ } @{ Zonemaster::Engine->logger->entries };
ok( $res{CNAME_LOOP_OUTER}, q{should emit CNAME_LOOP_OUTER} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
