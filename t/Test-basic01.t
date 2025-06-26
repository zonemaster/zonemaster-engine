use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Basic} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# basic01 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Basic-TP/basic01.md
my $test_module = 'Basic';
my $test_case = 'basic01';
my @all_tags = qw(B01_CHILD_IS_ALIAS
                  B01_CHILD_FOUND
                  B01_INCONSISTENT_ALIAS
                  B01_INCONSISTENT_DELEGATION
                  B01_NO_CHILD
                  B01_PARENT_DISREGARDED
                  B01_PARENT_FOUND
                  B01_PARENT_NOT_FOUND
                  B01_PARENT_UNDETERMINED
                  B01_ROOT_HAS_NO_PARENT
                  B01_SERVER_ZONE_ERROR);

# Common hint file (test-zone-data/COMMON/hintfile)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'ns1' => [ '127.1.0.1', 'fda1:b2:c3::127:1:0:1' ],
      'ns2' => [ '127.1.0.2', 'fda1:b2:c3::127:1:0:2' ],
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
    'GOOD-1' => [
        1,
        q(child.parent.good-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'GOOD-MIXED-1' => [
        1,
        q(child.parent.good-mixed-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'GOOD-MIXED-2' => [
        1,
        q(child.parent.good-mixed-2.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'GOOD-PARENT-HOST-1' => [
        1,
        q(child.parent.good-parent-host-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'GOOD-GRANDPARENT-HOST-1' => [
        1,
        q(child.parent.good-grandparent-host-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'GOOD-UNDEL-1' => [
        1,
        q(child.parent.good-undel-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_DISREGARDED) ],
        undef,
        [ qw(ns3-undelegated-child.basic01.xa ns4-undelegated-child.basic01.xa) ],
        [],
    ],
    'GOOD-MIXED-UNDEL-1' => [
        1,
        q(child.parent.good-mixed-undel-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_DISREGARDED) ],
        undef,
        [ qw(ns3-undelegated-child.basic01.xa ns4-undelegated-child.basic01.xa) ],
        [],
    ],
    'GOOD-MIXED-UNDEL-2' => [
        1,
        q(child.parent.good-mixed-undel-2.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_DISREGARDED) ],
        undef,
        [ qw(ns3-undelegated-child.basic01.xa ns4-undelegated-child.basic01.xa) ],
        [],
    ],
    'NO-DEL-UNDEL-1' => [
        1,
        q(child.parent.no-del-undel-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_DISREGARDED) ],
        undef,
        [ qw(ns3-undelegated-child.basic01.xa ns4-undelegated-child.basic01.xa) ],
        [],
    ],
    'NO-DEL-MIXED-UNDEL-1' => [
        1,
        q(child.parent.no-del-mixed-undel-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_DISREGARDED) ],
        undef,
        [ qw(ns3-undelegated-child.basic01.xa ns4-undelegated-child.basic01.xa) ],
        [],
    ],
    'NO-DEL-MIXED-UNDEL-2' => [
        1,
        q(child.w.x.parent.y.z.no-del-mixed-undel-2.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_DISREGARDED) ],
        undef,
        [ qw(ns3-undelegated-child.basic01.xa ns4-undelegated-child.basic01.xa) ],
        [],
    ],
    'NO-CHILD-1' => [
        1,
        q(child.parent.no-child-1.basic01.xa),
        [ qw(B01_NO_CHILD B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'NO-CHILD-2' => [
        1,
        q(child.parent.no-child-2.basic01.xa),
        [ qw(B01_NO_CHILD B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'NO-CHLD-PAR-UNDETER-1' => [
        1,
        q(child.parent.no-chld-par-undeter-1.basic01.xa),
        [ qw(B01_NO_CHILD B01_PARENT_FOUND B01_PARENT_UNDETERMINED) ],
        undef,
        [],
        [],
    ],
    'CHLD-FOUND-PAR-UNDET-1' => [
        1,
        q(child.parent.chld-found-par-undet-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_FOUND B01_PARENT_UNDETERMINED) ],
        undef,
        [],
        [],
    ],
    'CHLD-FOUND-INCONSIST-1' => [
        1,
        q(child.parent.chld-found-inconsist-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'CHLD-FOUND-INCONSIST-2' => [
        1,
        q(child.parent.chld-found-inconsist-2.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'CHLD-FOUND-INCONSIST-3' => [
        1,
        q(child.parent.chld-found-inconsist-3.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'CHLD-FOUND-INCONSIST-4' => [
        1,
        q(child.parent.chld-found-inconsist-4.basic01.xa),
        [ qw(B01_CHILD_IS_ALIAS B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'CHLD-FOUND-INCONSIST-5' => [
        1,
        q(child.parent.chld-found-inconsist-5.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'CHLD-FOUND-INCONSIST-6' => [
        1,
        q(child.parent.chld-found-inconsist-6.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'CHLD-FOUND-INCONSIST-7' => [
        1,
        q(child.parent.chld-found-inconsist-7.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'CHLD-FOUND-INCONSIST-8' => [
        1,
        q(child.parent.chld-found-inconsist-8.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'CHLD-FOUND-INCONSIST-9' => [
        1,
        q(child.parent.chld-found-inconsist-9.basic01.xa),
        [ qw(B01_CHILD_IS_ALIAS B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'CHLD-FOUND-INCONSIST-10' => [
        1,
        q(child.parent.chld-found-inconsist-10.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'NO-DEL-UNDEL-NO-PAR-1' => [
        1,
        q(child.parent.no-del-undel-no-par-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_DISREGARDED) ],
        undef,
        [ qw(ns3-undelegated-child.basic01.xa ns4-undelegated-child.basic01.xa) ],
        [],
    ],
    'NO-DEL-UNDEL-PAR-UND-1' => [
        1,
        q(child.parent.no-del-undel-par-und-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_DISREGARDED) ],
        undef,
        [ qw(ns3-undelegated-child.basic01.xa ns4-undelegated-child.basic01.xa) ],
        [],
    ],
    'NO-CHLD-NO-PAR-1' => [
        1,
        q(child.parent.no-chld-no-par-1.basic01.xa),
        [ qw(B01_NO_CHILD B01_PARENT_NOT_FOUND B01_SERVER_ZONE_ERROR) ],
        undef,
        [],
        [],
    ],
    'CHILD-ALIAS-1' => [
        1,
        q(child.parent.child-alias-1.basic01.xa),
        [ qw(B01_CHILD_IS_ALIAS B01_NO_CHILD B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'CHILD-ALIAS-2' => [
        1,
        q(child.parent.child-alias-2.basic01.xa),
        [ qw(B01_CHILD_IS_ALIAS B01_NO_CHILD B01_INCONSISTENT_ALIAS B01_PARENT_FOUND) ],
        undef,
        [],
        [],
    ],
    'ZONE-ERR-GRANDPARENT-1' => [
        1,
        q(child.parent.zone-err-grandparent-1.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_FOUND B01_SERVER_ZONE_ERROR) ],
        undef,
        [],
        [],
    ],
    'ZONE-ERR-GRANDPARENT-2' => [
        1,
        q(child.parent.zone-err-grandparent-2.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_FOUND B01_SERVER_ZONE_ERROR) ],
        undef,
        [],
        [],
    ],
    'ZONE-ERR-GRANDPARENT-3' => [
        1,
        q(child.parent.zone-err-grandparent-3.basic01.xa),
        [ qw(B01_CHILD_FOUND B01_PARENT_FOUND B01_SERVER_ZONE_ERROR) ],
        undef,
        [],
        [],
    ],
    'ROOT-ZONE' => [
        1,
        q(.),
        [ qw(B01_CHILD_FOUND B01_ROOT_HAS_NO_PARENT) ],
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
