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
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41
              127.40.1.42
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.good-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.good-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.good-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.good-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.good-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.good-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.good-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.good-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        []
    ],
    'GOOD-2' => [
        1,
        q(child.parent.good-2.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41
              127.40.1.42
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns5.good-2.methodsv2.xa/127.40.1.35
              ns5.good-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:35
              ns6.good-2.methodsv2.xa/127.40.1.36
              ns6.good-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:36 ) ],
        [ qw( ns5.good-2.methodsv2.xa/127.40.1.35
              ns5.good-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:35
              ns6.good-2.methodsv2.xa/127.40.1.36
              ns6.good-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:36 ) ],
        []
    ],
    'GOOD-3' => [
        1,
        q(child.parent.good-3.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41
              127.40.1.42
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.good-3.methodsv2.xa/127.40.1.51
              ns1.child.parent.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns3.parent.good-3.methodsv2.xa/127.40.1.43
              ns3.parent.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:43
              ns5.good-3.methodsv2.xa/127.40.1.35
              ns5.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:35 ) ],
        [ qw( ns1.child.parent.good-3.methodsv2.xa/127.40.1.51
              ns1.child.parent.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns3.parent.good-3.methodsv2.xa/127.40.1.43
              ns3.parent.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:43
              ns5.good-3.methodsv2.xa/127.40.1.35
              ns5.good-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:35 )  ],
        []
    ],
    'GOOD-4' => [
        1,
        q(child.parent.good-4.methodsv2.xa),
        [ qw( 127.40.1.31
              fda1:b2:c3:0:127:40:1:31
              127.40.1.41
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.good-4.methodsv2.xa/127.40.1.51 
              ns1.child.parent.good-4.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.good-4.methodsv2.xa/127.40.1.52 
              ns2.child.parent.good-4.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.good-4.methodsv2.xa/127.40.1.51 
              ns1.child.parent.good-4.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.good-4.methodsv2.xa/127.40.1.52 
              ns2.child.parent.good-4.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        []
    ],
    'GOOD-5' => [
        1,
        q(child.parent.good-5.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.good-5.methodsv2.xa/127.40.1.51 
              ns1.child.parent.good-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.good-5.methodsv2.xa/127.40.1.52 
              ns2.child.parent.good-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 
              ns1.good-5.methodsv2.xa/127.40.1.31 
              ns1.good-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:31 
              ns1.parent.good-5.methodsv2.xa/127.40.1.41 
              ns1.parent.good-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.good-5.methodsv2.xa/127.40.1.51 
              ns1.child.parent.good-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.good-5.methodsv2.xa/127.40.1.52 
              ns2.child.parent.good-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 
              ns1.good-5.methodsv2.xa/127.40.1.31 
              ns1.good-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:31 
              ns1.parent.good-5.methodsv2.xa/127.40.1.41 
              ns1.parent.good-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        []
    ],
    'GOOD-6' => [
        1,
        q(child.parent.good-6.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.good-6.methodsv2.xa/127.40.1.31 
              ns1.good-6.methodsv2.xa/fda1:b2:c3:0:127:40:1:31 
              ns2.good-6.methodsv2.xa/127.40.1.32 
              ns2.good-6.methodsv2.xa/fda1:b2:c3:0:127:40:1:32 ) ],
        [ qw( ns1.good-6.methodsv2.xa/127.40.1.31 
              ns1.good-6.methodsv2.xa/fda1:b2:c3:0:127:40:1:31 
              ns2.good-6.methodsv2.xa/127.40.1.32 
              ns2.good-6.methodsv2.xa/fda1:b2:c3:0:127:40:1:32 ) ],
        []
    ],
    'GOOD-7' => [
        1,
        q(child.parent.good-7.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.parent.good-7.methodsv2.xa/127.40.1.41 
              ns1.parent.good-7.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 
              ns2.parent.good-7.methodsv2.xa/127.40.1.42 
              ns2.parent.good-7.methodsv2.xa/fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.parent.good-7.methodsv2.xa/127.40.1.41 
              ns1.parent.good-7.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 
              ns2.parent.good-7.methodsv2.xa/127.40.1.42 
              ns2.parent.good-7.methodsv2.xa/fda1:b2:c3:0:127:40:1:42 ) ],
        []
    ],
    'GOOD-UNDEL-1' => [
        1,
        q(child.parent.good-undel-1.methodsv2.xa),
        [], # No parent data
        [ qw( ns1-2.child.parent.good-undel-1.methodsv2.xa/127.40.1.52
              ns1-2.child.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns3.parent.good-undel-1.methodsv2.xa/127.40.1.43
              ns3.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:43
              ns6.good-undel-1.methodsv2.xa/127.40.1.36
              ns6.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:36 ) ],
        [ qw( ns1-2.child.parent.good-undel-1.methodsv2.xa/127.40.1.52
              ns1-2.child.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns3.parent.good-undel-1.methodsv2.xa/127.40.1.43
              ns3.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:43
              ns6.good-undel-1.methodsv2.xa/127.40.1.36
              ns6.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:36 ) ],
        [ qw( ns1-2.child.parent.good-undel-1.methodsv2.xa/127.40.1.52
              ns1-2.child.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns3.parent.good-undel-1.methodsv2.xa/127.40.1.43
              ns3.parent.good-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:43
              ns6.good-undel-1.methodsv2.xa ) ]
    ],
    'GOOD-UNDEL-2' => [
        1,
        q(child.parent.good-undel-2.methodsv2.xa),
        [], # No parent data
        [ qw( ns1.child.parent.good-undel-2.methodsv2.xa/127.40.1.51
              ns1.child.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns3.parent.good-undel-2.methodsv2.xa/127.40.1.43
              ns3.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:43
              ns6.good-undel-2.methodsv2.xa/127.40.1.36
              ns6.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:36 ) ],
        [ qw( ns1.child.parent.good-undel-2.methodsv2.xa/127.40.1.51
              ns1.child.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns3.parent.good-undel-2.methodsv2.xa/127.40.1.43
              ns3.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:43
              ns6.good-undel-2.methodsv2.xa/127.40.1.36
              ns6.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:36 ) ],
        [ qw( ns1.child.parent.good-undel-2.methodsv2.xa/127.40.1.51
              ns1.child.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns3.parent.good-undel-2.methodsv2.xa/127.40.1.43
              ns3.parent.good-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:43
              ns6.good-undel-2.methodsv2.xa ) ]
    ],
    'DIFF-NS-1' => [
        1,
        q(child.parent.diff-ns-1.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.diff-ns-1.methodsv2.xa/127.40.1.51 
              ns1.child.parent.diff-ns-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.diff-ns-1.methodsv2.xa/127.40.1.52 
              ns2.child.parent.diff-ns-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1-2.child.parent.diff-ns-1.methodsv2.xa/127.40.1.51 
              ns1-2.child.parent.diff-ns-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2-2.child.parent.diff-ns-1.methodsv2.xa/127.40.1.52 
              ns2-2.child.parent.diff-ns-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        []
    ],
    'DIFF-NS-2' => [
        1,
        q(child.parent.diff-ns-2.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.diff-ns-2.methodsv2.xa/127.40.1.51 
              ns1.child.parent.diff-ns-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.diff-ns-2.methodsv2.xa/127.40.1.52 
              ns2.child.parent.diff-ns-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1-2.child.parent.diff-ns-2.methodsv2.xa/127.40.1.51 
              ns1-2.child.parent.diff-ns-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns3.child.parent.diff-ns-2.methodsv2.xa/127.40.1.53 
              ns3.child.parent.diff-ns-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:53 ) ],
        []
    ],
    'IB-NOT-IN-ZONE-1' => [
        1,
        q(child.parent.ib-not-in-zone-1.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.ib-not-in-zone-1.methodsv2.xa/127.40.1.51 
              ns1.child.parent.ib-not-in-zone-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.ib-not-in-zone-1.methodsv2.xa/127.40.1.52 
              ns2.child.parent.ib-not-in-zone-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.ib-not-in-zone-1.methodsv2.xa 
              ns2.child.parent.ib-not-in-zone-1.methodsv2.xa ) ],
        []
    ],
    'CHILD-NO-ZONE-1' => [
        1,
        q(child.parent.child-no-zone-1.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.child-no-zone-1.methodsv2.xa/127.40.1.51 
              ns1.child.parent.child-no-zone-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.child-no-zone-1.methodsv2.xa/127.40.1.52 
              ns2.child.parent.child-no-zone-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [], # No child data
        []
    ],
    'CHILD-NO-ZONE-2' => [
        1,
        q(child.parent.child-no-zone-2.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.child-no-zone-2.methodsv2.xa/127.40.1.51 
              ns1.child.parent.child-no-zone-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.child-no-zone-2.methodsv2.xa/127.40.1.52 
              ns2.child.parent.child-no-zone-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [], # No child data
        []
    ],
    'GOOD-MIXED-UNDEL-1' => [
        1,
        q(child.parent.good-mixed-undel-1.methodsv2.xa),
        [], # No parent data
        [ qw( ns3.child.parent.good-mixed-undel-1.methodsv2.xa/127.40.1.53 
              ns3.child.parent.good-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:53 
              ns4.child.parent.good-mixed-undel-1.methodsv2.xa/127.40.1.54 
              ns4.child.parent.good-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:54 ) ],
        [ qw( ns3.child.parent.good-mixed-undel-1.methodsv2.xa/127.40.1.53 
              ns3.child.parent.good-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:53 
              ns4.child.parent.good-mixed-undel-1.methodsv2.xa/127.40.1.54 
              ns4.child.parent.good-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:54 ) ],
        [ qw( ns3.child.parent.good-mixed-undel-1.methodsv2.xa/127.40.1.53 
              ns3.child.parent.good-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:53 
              ns4.child.parent.good-mixed-undel-1.methodsv2.xa/127.40.1.54 
              ns4.child.parent.good-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:54 ) ],
    ],
    'GOOD-MIXED-UNDEL-2' => [
        1,
        q(child.parent.good-mixed-undel-2.methodsv2.xa),
        [], # No parent data
        [ qw( ns3.child.parent.good-mixed-undel-2.methodsv2.xa/127.40.1.53 
              ns3.child.parent.good-mixed-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:53 
              ns4.child.parent.good-mixed-undel-2.methodsv2.xa/127.40.1.54 
              ns4.child.parent.good-mixed-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:54 ) ],
        [ qw( ns3.child.parent.good-mixed-undel-2.methodsv2.xa/127.40.1.53 
              ns3.child.parent.good-mixed-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:53 
              ns4.child.parent.good-mixed-undel-2.methodsv2.xa/127.40.1.54 
              ns4.child.parent.good-mixed-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:54 ) ],
        [ qw( ns3.child.parent.good-mixed-undel-2.methodsv2.xa/127.40.1.53 
              ns3.child.parent.good-mixed-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:53 
              ns4.child.parent.good-mixed-undel-2.methodsv2.xa/127.40.1.54 
              ns4.child.parent.good-mixed-undel-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:54 ) ],
    ],
    'NO-DEL-MIXED-UNDEL-1' => [
        1,
        q(child.parent.no-del-mixed-undel-1.methodsv2.xa),
        [], # No parent data
        [ qw( ns1.child.parent.no-del-mixed-undel-1.methodsv2.xa/127.40.1.51 
              ns1.child.parent.no-del-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.no-del-mixed-undel-1.methodsv2.xa/127.40.1.52 
              ns2.child.parent.no-del-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.no-del-mixed-undel-1.methodsv2.xa/127.40.1.51 
              ns1.child.parent.no-del-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.no-del-mixed-undel-1.methodsv2.xa/127.40.1.52 
              ns2.child.parent.no-del-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.no-del-mixed-undel-1.methodsv2.xa/127.40.1.51 
              ns1.child.parent.no-del-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.no-del-mixed-undel-1.methodsv2.xa/127.40.1.52 
              ns2.child.parent.no-del-mixed-undel-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
    ],
    'NO-CHILD-1' => [
        1,
        q(child.parent.no-child-1.methodsv2.xa),
        undef, # Undef
        undef, # Undef
        undef, # Undef
        [ ],
    ],
    'NO-CHILD-2' => [
        1,
        q(child.parent.no-child-2.methodsv2.xa),
        undef, # Undef
        undef, # Undef
        undef, # Undef
        [],
    ],
    'NO-CHLD-PAR-UNDETER-1' => [
        1,
        q(child.parent.no-chld-par-undeter-1.methodsv2.xa),
        undef, # Undef
        undef, # Undef
        undef, # Undef
        [ ],
    ],
    'CHLD-FOUND-PAR-UNDET-1' => [
        1,
        q(child.parent.chld-found-par-undet-1.methodsv2.xa),
        [ qw( 127.40.1.31
              fda1:b2:c3:0:127:40:1:31
              127.40.1.41
              fda1:b2:c3:0:127:40:1:41
              127.40.1.42
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.chld-found-par-undet-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-par-undet-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-par-undet-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-par-undet-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.chld-found-par-undet-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-par-undet-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-par-undet-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-par-undet-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [],
    ],
    'CHLD-FOUND-INCONSIST-1' => [
        1,
        q(child.parent.chld-found-inconsist-1.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [],
    ],
    'CHLD-FOUND-INCONSIST-2' => [
        1,
        q(child.parent.chld-found-inconsist-2.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-2.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-2.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-2.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-2.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [  ],
    ],
    'CHLD-FOUND-INCONSIST-3' => [
        1,
        q(child.parent.chld-found-inconsist-3.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-3.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-3.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-3.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-3.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ ],
    ],
    'CHLD-FOUND-INCONSIST-4' => [
        1,
        q(child.parent.chld-found-inconsist-4.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-4.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-4.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-4.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-4.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-4.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-4.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-4.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-4.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ ],
    ],
    'CHLD-FOUND-INCONSIST-5' => [
        1,
        q(child.parent.chld-found-inconsist-5.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-5.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-5.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-5.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-5.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-5.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ ],
    ],
    'CHLD-FOUND-INCONSIST-6' => [
        1,
        q(child.parent.chld-found-inconsist-6.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-6.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-6.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-6.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-6.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns1.parent.chld-found-inconsist-6.methodsv2.xa/127.40.1.41
              ns1.parent.chld-found-inconsist-6.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-6.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-6.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-6.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-6.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns1.parent.chld-found-inconsist-6.methodsv2.xa/127.40.1.41
              ns1.parent.chld-found-inconsist-6.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        [ ],
    ],
    'CHLD-FOUND-INCONSIST-7' => [
        1,
        q(child.parent.chld-found-inconsist-7.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-7.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-7.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-7.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-7.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns1.parent.chld-found-inconsist-7.methodsv2.xa/127.40.1.41
              ns1.parent.chld-found-inconsist-7.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-7.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-7.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-7.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-7.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns1.parent.chld-found-inconsist-7.methodsv2.xa/127.40.1.41
              ns1.parent.chld-found-inconsist-7.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        [ ],
    ],
    'CHLD-FOUND-INCONSIST-8' => [
        1,
        q(child.parent.chld-found-inconsist-8.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-8.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-8.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-8.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-8.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns1.parent.chld-found-inconsist-8.methodsv2.xa/127.40.1.41
              ns1.parent.chld-found-inconsist-8.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-8.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-8.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-8.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-8.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns1.parent.chld-found-inconsist-8.methodsv2.xa/127.40.1.41
              ns1.parent.chld-found-inconsist-8.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        [ ],
    ],
    'CHLD-FOUND-INCONSIST-9' => [
        1,
        q(child.parent.chld-found-inconsist-9.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-9.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-9.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-9.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-9.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns1.parent.chld-found-inconsist-9.methodsv2.xa/127.40.1.41
              ns1.parent.chld-found-inconsist-9.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-9.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-9.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-9.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-9.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns1.parent.chld-found-inconsist-9.methodsv2.xa/127.40.1.41
              ns1.parent.chld-found-inconsist-9.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        [ ],
    ],
    'CHLD-FOUND-INCONSIST-10' => [
        1,
        q(child.parent.chld-found-inconsist-10.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-10.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-10.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-10.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-10.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns1.parent.chld-found-inconsist-10.methodsv2.xa/127.40.1.41
              ns1.parent.chld-found-inconsist-10.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        [ qw( ns1.child.parent.chld-found-inconsist-10.methodsv2.xa/127.40.1.51
              ns1.child.parent.chld-found-inconsist-10.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.chld-found-inconsist-10.methodsv2.xa/127.40.1.52
              ns2.child.parent.chld-found-inconsist-10.methodsv2.xa/fda1:b2:c3:0:127:40:1:52
              ns1.parent.chld-found-inconsist-10.methodsv2.xa/127.40.1.41
              ns1.parent.chld-found-inconsist-10.methodsv2.xa/fda1:b2:c3:0:127:40:1:41 ) ],
        [ ],
    ],
    'NO-DEL-UNDEL-NO-PAR-1' => [
        1,
        q(child.parent.no-del-undel-no-par-1.methodsv2.xa),
        [ ], # No parent data
        [ qw( ns1.child.parent.no-del-undel-no-par-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.no-del-undel-no-par-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.no-del-undel-no-par-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.no-del-undel-no-par-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.no-del-undel-no-par-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.no-del-undel-no-par-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.no-del-undel-no-par-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.no-del-undel-no-par-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.no-del-undel-no-par-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.no-del-undel-no-par-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.no-del-undel-no-par-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.no-del-undel-no-par-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
    ],
    'NO-DEL-UNDEL-PAR-UND-1' => [
        1,
        q(child.parent.no-del-undel-par-und-1.methodsv2.xa),
        [ ], # No parent data
        [ qw( ns1.child.parent.no-del-undel-par-und-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.no-del-undel-par-und-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.no-del-undel-par-und-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.no-del-undel-par-und-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.no-del-undel-par-und-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.no-del-undel-par-und-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.no-del-undel-par-und-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.no-del-undel-par-und-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.no-del-undel-par-und-1.methodsv2.xa/127.40.1.51
              ns1.child.parent.no-del-undel-par-und-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51
              ns2.child.parent.no-del-undel-par-und-1.methodsv2.xa/127.40.1.52
              ns2.child.parent.no-del-undel-par-und-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
    ],
    'NO-CHLD-NO-PAR-1' => [
        1,
        q(child.parent.no-chld-no-par-1.methodsv2.xa),
        undef, # Undef
        undef, # Undef
        undef, # Undef
        [ ],
    ],
    'CHILD-ALIAS-1' => [
        1,
        q(child.parent.child-alias-1.methodsv2.xa),
        undef, # Undef
        undef, # Undef
        undef, # Undef
        [ ],
    ],
    'ZONE-ERR-GRANDPARENT-1' => [
        1,
        q(child.parent.zone-err-grandparent-1.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.zone-err-grandparent-1.methodsv2.xa/127.40.1.51 
              ns1.child.parent.zone-err-grandparent-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.zone-err-grandparent-1.methodsv2.xa/127.40.1.52 
              ns2.child.parent.zone-err-grandparent-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.zone-err-grandparent-1.methodsv2.xa/127.40.1.51 
              ns1.child.parent.zone-err-grandparent-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.zone-err-grandparent-1.methodsv2.xa/127.40.1.52 
              ns2.child.parent.zone-err-grandparent-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ ],
    ],
    'ZONE-ERR-GRANDPARENT-2' => [
        1,
        q(child.parent.zone-err-grandparent-2.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.zone-err-grandparent-2.methodsv2.xa/127.40.1.51 
              ns1.child.parent.zone-err-grandparent-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.zone-err-grandparent-2.methodsv2.xa/127.40.1.52 
              ns2.child.parent.zone-err-grandparent-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.zone-err-grandparent-2.methodsv2.xa/127.40.1.51 
              ns1.child.parent.zone-err-grandparent-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.zone-err-grandparent-2.methodsv2.xa/127.40.1.52 
              ns2.child.parent.zone-err-grandparent-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ ],
    ],
    'ZONE-ERR-GRANDPARENT-3' => [
        1,
        q(child.parent.zone-err-grandparent-3.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.zone-err-grandparent-3.methodsv2.xa/127.40.1.51 
              ns1.child.parent.zone-err-grandparent-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.zone-err-grandparent-3.methodsv2.xa/127.40.1.52 
              ns2.child.parent.zone-err-grandparent-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.zone-err-grandparent-3.methodsv2.xa/127.40.1.51 
              ns1.child.parent.zone-err-grandparent-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.zone-err-grandparent-3.methodsv2.xa/127.40.1.52 
              ns2.child.parent.zone-err-grandparent-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ ],
    ],
    'DELEG-OOB-W-ERROR-1' => [
        1,
        q(child.parent.deleg-oob-w-error-1.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns3.deleg-oob-w-error-1.methodsv2.xa/127.40.1.33
              ns3.deleg-oob-w-error-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:33
              ns4-nodata.deleg-oob-w-error-1.methodsv2.xa ) ],
        [ qw( ns3.deleg-oob-w-error-1.methodsv2.xa/127.40.1.33
              ns3.deleg-oob-w-error-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:33
              ns4-nodata.deleg-oob-w-error-1.methodsv2.xa ) ],
        [ ],
    ],
    'DELEG-OOB-W-ERROR-2' => [
        1,
        q(child.parent.deleg-oob-w-error-2.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns3.deleg-oob-w-error-2.methodsv2.xa/127.40.1.33
              ns3.deleg-oob-w-error-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:33
              ns4-nxdomain.deleg-oob-w-error-2.methodsv2.xa ) ],
        [ qw( ns3.deleg-oob-w-error-2.methodsv2.xa/127.40.1.33
              ns3.deleg-oob-w-error-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:33
              ns4-nxdomain.deleg-oob-w-error-2.methodsv2.xa ) ],
        [ ],
    ],
    'DELEG-OOB-W-ERROR-3' => [
        1,
        q(child.parent.deleg-oob-w-error-3.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns3-nodata.deleg-oob-w-error-3.methodsv2.xa
              ns4-nodata.deleg-oob-w-error-3.methodsv2.xa ) ],
        [ ], # Empty
        [ ],
    ],
    'DELEG-OOB-W-ERROR-4' => [
        1,
        q(child.parent.deleg-oob-w-error-4.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns3-nxdomain.deleg-oob-w-error-4.methodsv2.xa
              ns4-nxdomain.deleg-oob-w-error-4.methodsv2.xa ) ],
        [ ], # Empty
        [ ],
    ],
    'CHILD-NS-CNAME-1' => [
        1,
        q(child.parent.child-ns-cname-1.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1-cname.child.parent.child-ns-cname-1.methodsv2.xa/127.40.1.51 
              ns1-cname.child.parent.child-ns-cname-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2-cname.child.parent.child-ns-cname-1.methodsv2.xa/127.40.1.52 
              ns2-cname.child.parent.child-ns-cname-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1-cname.child.parent.child-ns-cname-1.methodsv2.xa/127.40.1.51 
              ns1-cname.child.parent.child-ns-cname-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2-cname.child.parent.child-ns-cname-1.methodsv2.xa/127.40.1.52 
              ns2-cname.child.parent.child-ns-cname-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ ],
    ],
    'CHILD-NS-CNAME-2' => [
        1,
        q(child.parent.child-ns-cname-2.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1-cname.child.parent.child-ns-cname-2.methodsv2.xa/127.40.1.51 
              ns1-cname.child.parent.child-ns-cname-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2-cname.child.parent.child-ns-cname-2.methodsv2.xa/127.40.1.52 
              ns2-cname.child.parent.child-ns-cname-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1-cname.child.parent.child-ns-cname-2.methodsv2.xa/127.40.1.51 
              ns1-cname.child.parent.child-ns-cname-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2-cname.child.parent.child-ns-cname-2.methodsv2.xa/127.40.1.52 
              ns2-cname.child.parent.child-ns-cname-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ ],
    ],
    'CHILD-NS-CNAME-3' => [
        1,
        q(child.parent.child-ns-cname-3.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns3-cname.child-ns-cname-3.methodsv2.xa/127.40.1.33
              ns3-cname.child-ns-cname-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:33
              ns4-cname.child-ns-cname-3.methodsv2.xa/127.40.1.34
              ns4-cname.child-ns-cname-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:34 ) ],
        [ qw( ns3-cname.child-ns-cname-3.methodsv2.xa/127.40.1.33
              ns3-cname.child-ns-cname-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:33
              ns4-cname.child-ns-cname-3.methodsv2.xa/127.40.1.34
              ns4-cname.child-ns-cname-3.methodsv2.xa/fda1:b2:c3:0:127:40:1:34 ) ],
        [ ],
    ],
    'CHILD-NS-CNAME-4' => [
        1,
        q(child.parent.child-ns-cname-4.methodsv2.xa),
        [ qw( 127.40.1.41
              fda1:b2:c3:0:127:40:1:41
              127.40.1.42
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1-cname.child.parent.child-ns-cname-4.methodsv2.xa/127.40.1.51 ) ],
        [ qw( ns1-cname.child.parent.child-ns-cname-4.methodsv2.xa/127.40.1.51
              ns2-cname.child.parent.child-ns-cname-4.methodsv2.xa/127.40.1.52 ) ],
        [ ],
    ],
    'PARENT-NS-CNAME-1' => [
        1,
        q(child.parent.parent-ns-cname-1.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.parent-ns-cname-1.methodsv2.xa/127.40.1.51 
              ns1.child.parent.parent-ns-cname-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.parent-ns-cname-1.methodsv2.xa/127.40.1.52 
              ns2.child.parent.parent-ns-cname-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.parent-ns-cname-1.methodsv2.xa/127.40.1.51 
              ns1.child.parent.parent-ns-cname-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.parent-ns-cname-1.methodsv2.xa/127.40.1.52 
              ns2.child.parent.parent-ns-cname-1.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ ],
    ],
    'PARENT-NS-CNAME-2' => [
        1,
        q(child.parent.parent-ns-cname-2.methodsv2.xa),
        [ qw( 127.40.1.41 
              fda1:b2:c3:0:127:40:1:41 
              127.40.1.42 
              fda1:b2:c3:0:127:40:1:42 ) ],
        [ qw( ns1.child.parent.parent-ns-cname-2.methodsv2.xa/127.40.1.51 
              ns1.child.parent.parent-ns-cname-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.parent-ns-cname-2.methodsv2.xa/127.40.1.52 
              ns2.child.parent.parent-ns-cname-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ qw( ns1.child.parent.parent-ns-cname-2.methodsv2.xa/127.40.1.51 
              ns1.child.parent.parent-ns-cname-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:51 
              ns2.child.parent.parent-ns-cname-2.methodsv2.xa/127.40.1.52 
              ns2.child.parent.parent-ns-cname-2.methodsv2.xa/fda1:b2:c3:0:127:40:1:52 ) ],
        [ ],
    ],
);


###########

my $datafile = 't/' . basename ($0, '.t') . '.data';

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

=head1 Optional features

=over

=item Selected scenarios

Provide one scenario name or a comma-separated list of scenario names in
environment variable "ZONEMASTER_SELECTED_SCENARIOS" to test only that or those
scenarios, even if they have been set as not testable. Example:

ZONEMASTER_SELECTED_SCENARIOS="GOOD-1" perl methodsv2.t

=item Disabled scenarios

Provide one scenario name or a comma-separated list of scenario names in
environment variable "ZONEMASTER_DISABLED_SCENARIOS" to disable that or those
scenarios for this run only. Example:

ZONEMASTER_DISABLED_SCENARIOS="GOOD-1,GOOD-2" perl methodsv2.t

=back

=cut

perform_methodsv2_testing( \%subtests, $ENV{ZONEMASTER_SELECTED_SCENARIOS}, $ENV{ZONEMASTER_DISABLED_SCENARIOS} );


if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
