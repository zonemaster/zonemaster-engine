use strict;
use warnings;
use utf8;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::TestMethodsV2} );
    use_ok( q{TestUtil}, qw( perform_methodsv2_testing ) );
}

# Common hint file (test-zone-data/COMMON/hintfile)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'ns1' => [ '127.1.0.1', 'fda1:b2:c3::127:1:0:1' ],
      'ns2' => [ '127.1.0.2', 'fda1:b2:c3::127:1:0:2' ],
    }
);

# Test zone scenarios
# - Documentation: L<TestUtil/perform_methodsv2_testing()>
# - Format: { SCENARIO_NAME => [
#     testable,
#     zone_name,
#     [ EXPECTED_PARENT_IP ],
#     [ EXPECTED_DEL_NS ],
#     [ EXPECTED_ZONE_NS ],
#     [ UNDELEGATED_NS ]
#   ] }
#

my %subtests = (
    'GOOD-1' => [
        1,
        q(child.parent.good-1.methodsv2.xa),
        [ qw( 127.40.3.21 fda1:b2:c3:0:127:40:3:21 127.40.3.22 fda1:b2:c3:0:127:40:3:22 ) ],
        [ qw( ns1.child.parent.good-1.methodsv2.xa/127.40.4.21 ns1.child.parent.good-1.methodsv2.xa/fda1:b2:c3:0:127:40:4:21 ns2.child.parent.good-1.methodsv2.xa/127.40.4.22 ns2.child.parent.good-1.methodsv2.xa/fda1:b2:c3:0:127:40:4:22 ) ],
        [ qw( ns1.child.parent.good-1.methodsv2.xa/127.40.4.21 ns1.child.parent.good-1.methodsv2.xa/fda1:b2:c3:0:127:40:4:21 ns2.child.parent.good-1.methodsv2.xa/127.40.4.22 ns2.child.parent.good-1.methodsv2.xa/fda1:b2:c3:0:127:40:4:22 ) ],
        []
    ],
    'GOOD-2' => [
        1,
        q(child.parent.good-2.methodsv2.xa),
        [ qw( 127.40.3.21 fda1:b2:c3:0:127:40:3:21 127.40.3.22 fda1:b2:c3:0:127:40:3:22 ) ],
        [ qw( ns5.good-2.methodsv2.xa/127.40.2.25 ns5.good-2.methodsv2.xa/fda1:b2:c3:0:127:40:2:25 ns6.good-2.methodsv2.xa/127.40.2.26 ns6.good-2.methodsv2.xa/fda1:b2:c3:0:127:40:2:26 ) ],
        [ qw( ns5.good-2.methodsv2.xa/127.40.2.25 ns5.good-2.methodsv2.xa/fda1:b2:c3:0:127:40:2:25  ns6.good-2.methodsv2.xa/127.40.2.26 ns6.good-2.methodsv2.xa/fda1:b2:c3:0:127:40:2:26 ) ],
        []
    ],
    'GOOD-3' => [
        1,
        q(child.parent.good-3.methodsv2.xa),
        [ qw( 127.40.3.21 fda1:b2:c3:0:127:40:3:21 127.40.3.22 fda1:b2:c3:0:127:40:3:22 ) ],
        [ qw( ns1.child.parent.good-3.methodsv2.xa/127.40.4.21 ns1.child.parent.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:4:21 ns3.parent.good-3.methodsv2.xa/127.40.3.23 ns3.parent.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:3:23 ns5.good-3.methodsv2.xa/127.40.2.25 ns5.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:2:25 ) ],
        [ qw( ns1.child.parent.good-3.methodsv2.xa/127.40.4.21 ns1.child.parent.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:4:21 ns3.parent.good-3.methodsv2.xa/127.40.3.23 ns3.parent.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:3:23 ns5.good-3.methodsv2.xa/127.40.2.25 ns5.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:2:25 ) ],
        []
    ],
    'GOOD-UNDEL-1' => [
        1,
        q(child.parent.good-undel-1.methodsv2.xa),
        [],
        [ qw( ns1-2.child.parent.good-undel-1.methodsv2.xa/127.40.3.22 ns1-2.child.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:3:22 ns3.parent.good-undel-1.methodsv2.xa/127.40.3.23 ns3.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:3:23 ns6.good-undel-1.methodsv2.xa/127.40.2.26 ns6.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:2:26 ) ],
        [ qw( ns1-2.child.parent.good-undel-1.methodsv2.xa/127.40.3.22 ns1-2.child.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:3:22 ns3.parent.good-undel-1.methodsv2.xa/127.40.3.23 ns3.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:3:23 ns6.good-undel-1.methodsv2.xa/127.40.2.26 ns6.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:2:26 ) ],
        [ qw( ns1-2.child.parent.good-undel-1.methodsv2.xa/127.40.3.22 ns1-2.child.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:3:22 ns3.parent.good-undel-1.methodsv2.xa/127.40.3.23 ns3.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:3:23 ns6.good-undel-1.methodsv2.xa ) ]
    ],
    'GOOD-UNDEL-2' => [
        1,
        q(child.parent.good-undel-2.methodsv2.xa),
        [],
        [ qw( ns1.child.parent.good-undel-2.methodsv2.xa/127.40.4.21 ns1.child.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:4:21 ns3.parent.good-undel-2.methodsv2.xa/127.40.3.23 ns3.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:3:23 ns6.good-undel-2.methodsv2.xa/127.40.2.26 ns6.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:2:26 ) ],
        [ qw( ns1.child.parent.good-undel-2.methodsv2.xa/127.40.4.21 ns1.child.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:4:21 ns3.parent.good-undel-2.methodsv2.xa/127.40.3.23 ns3.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:3:23 ns6.good-undel-2.methodsv2.xa/127.40.2.26 ns6.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:2:26) ],
        [ qw( ns1.child.parent.good-undel-2.methodsv2.xa/127.40.4.21 ns1.child.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:4:21 ns3.parent.good-undel-2.methodsv2.xa/127.40.3.23 ns3.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:3:23 ns6.good-undel-2.methodsv2.xa ) ]
    ],
);

###########

my $datafile = 't/' . basename ($0, '.t') . '.data';

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

perform_methodsv2_testing( %subtests );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
