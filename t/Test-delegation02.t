use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Delegation} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# Delegation02 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Delegation-TP/delegation02.md
my $test_module = 'Delegation';
my $test_case = 'delegation02';
my @all_tags = qw(
                  DEL_DISTINCT_NS_IP
                  CHILD_DISTINCT_NS_IP
                  DEL_NS_SAME_IP
                  CHILD_NS_SAME_IP
                 );

# Specific hint file (https://github.com/zonemaster/zonemaster/blob/master/test-zone-data/Delegation-TP/delegation02/hintfile.zone)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'root-ns1.xa' => [ '127.16.2.27', 'fda1:b2:c3::127:16:2:27' ],
      'root-ns2.xa' => [ '127.16.2.28', 'fda1:b2:c3::127:16:2:28' ],
    }
);

# Test zone scenarios
# - Documentation: L<TestUtil/perform_testcase_testing()>
# - Format: { SCENARIO_NAME => [
#     testable,
#     zone_name,
#     [ MANDATORY_MESSAGE_TAGS ],
#     [ FORBIDDEN_MESSAGE_TAGS ],
#     [ UNDELEGATED_NS ],
#     [ UNDELEGATED_DS ],
#   ] }
#
# - One of MANDATORY_MESSAGE_TAGS and FORBIDDEN_MESSAGE_TAGS may be undefined.
#   See documentation for the meaning of that.

my %subtests = (
                'ALL-DISTINCT-1' =>
                [
                 1,
                 q(all-distinct-1.delegation02.xa),
                 [ qw( DEL_DISTINCT_NS_IP CHILD_DISTINCT_NS_IP ) ],
                 undef,
                 [],
                 [],
                ],
                'ALL-DISTINCT-2' =>
                [
                 1,
                 q(all-distinct-2.delegation02.xa),
                 [ qw( DEL_DISTINCT_NS_IP CHILD_DISTINCT_NS_IP ) ],
                 undef,
                 [],
                 [],
                ],
                'ALL-DISTINCT-3' =>
                [
                 1,
                 q(all-distinct-3.delegation02.xa),
                 [ qw( DEL_DISTINCT_NS_IP CHILD_DISTINCT_NS_IP ) ],
                 undef,
                 [],
                 [],
                ],
                'DEL-NON-DISTINCT' =>
                [
                 0,
                 q(del-non-distinct.delegation02.xa),
                 [ qw( DEL_NS_SAME_IP CHILD_DISTINCT_NS_IP ) ],
                 undef,
                 [],
                 [],
                ],
                'DEL-NON-DISTINCT-UND' =>
                [
                 1,
                 q(del-non-distinct.delegation02.xa),
                 [ qw( DEL_NS_SAME_IP CHILD_DISTINCT_NS_IP ) ],
                 undef,
                 [ qw(
                       ns1a.del-non-distinct-und.delegation02.xa/127.16.2.31
                       ns1a.del-non-distinct-und.delegation02.xa/fda1:b2:c3:0:127:16:2:31
                       ns1b.del-non-distinct-und.delegation02.xa/127.16.2.31
                       ns1b.del-non-distinct-und.delegation02.xa/fda1:b2:c3:0:127:16:2:31
                       )
                 ],
                 [],
                ],
                'CHILD-NON-DISTINCT' =>
                [
                 0,
                 q(child-non-distinct.delegation02.xa),
                 [ qw( DEL_DISTINCT_NS_IP CHILD_NS_SAME_IP ) ],
                 undef,
                 [],
                 [],
                ],
                'CHILD-NON-DISTINCT-UND' =>
                [
                 1,
                 q(child-non-distinct.delegation02.xa),
                 [ qw( DEL_DISTINCT_NS_IP CHILD_NS_SAME_IP ) ],
                 undef,
                 [ qw(
                       ns1a.child-non-distinct-und.delegation02.xa/127.16.2.31
                       ns1a.child-non-distinct-und.delegation02.xa/fda1:b2:c3:0:127:16:2:31
                       ns1b.child-non-distinct-und.delegation02.xa/127.16.2.32
                       ns1b.child-non-distinct-und.delegation02.xa/fda1:b2:c3:0:127:16:2:32
                       )
                 ],
                 [],
                ],
                'NON-DISTINCT-1' =>
                [
                 1,
                 q(non-distinct-1.delegation02.xa),
                 [ qw( DEL_NS_SAME_IP CHILD_NS_SAME_IP ) ],
                 undef,
                 [],
                 [],
                ],
                'NON-DISTINCT-2' =>
                [
                 1,
                 q(non-distinct-2.delegation02.xa),
                 [ qw( DEL_NS_SAME_IP CHILD_NS_SAME_IP ) ],
                 undef,
                 [],
                 [],
                ],
                'NON-DISTINCT-3' =>
                [
                 1,
                 q(non-distinct-3.delegation02.xa),
                 [ qw( DEL_NS_SAME_IP CHILD_NS_SAME_IP ) ],
                 undef,
                 [],
                 [],
                ],
               );
###########

my $datafile = 't/' . basename ($0, '.t') . '.data';

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

Zonemaster::Engine::Profile->effective->merge( Zonemaster::Engine::Profile->from_json( qq({ "test_cases": [ "$test_case" ] }) ) );

perform_testcase_testing( $test_case, $test_module, \@all_tags, \%subtests, $ENV{ZONEMASTER_SELECTED_SCENARIOS}, $ENV{ZONEMASTER_DISABLED_SCENARIOS} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
