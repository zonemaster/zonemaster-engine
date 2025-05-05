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
# Delegation01 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Delegation-TP/delegation01.md
my $test_module = 'Delegation';
my $test_case = 'delegation01';
my @all_tags = qw(ENOUGH_IPV4_NS_CHILD
                  ENOUGH_IPV4_NS_DEL
                  ENOUGH_IPV6_NS_CHILD
                  ENOUGH_IPV6_NS_DEL
                  ENOUGH_NS_CHILD
                  ENOUGH_NS_DEL
                  NOT_ENOUGH_IPV4_NS_CHILD
                  NOT_ENOUGH_IPV4_NS_DEL
                  NOT_ENOUGH_IPV6_NS_CHILD
                  NOT_ENOUGH_IPV6_NS_DEL
                  NOT_ENOUGH_NS_CHILD
                  NOT_ENOUGH_NS_DEL
                  NO_IPV4_NS_CHILD
                  NO_IPV4_NS_DEL
                  NO_IPV6_NS_CHILD
                  NO_IPV6_NS_DEL);

# Specific hint file (https://github.com/zonemaster/zonemaster/blob/master/test-zone-data/Delegation-TP/delegation01/hintfile.zone)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'root-ns1.xa' => [ '127.16.1.27', 'fda1:b2:c3::127:16:1:27' ],
      'root-ns2.xa' => [ '127.16.1.28', 'fda1:b2:c3::127:16:1:28' ],
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
                'ENOUGH-1' =>
                [
                 1,
                 q(enough-1.delegation01.xa),
                 [ qw(ENOUGH_IPV4_NS_CHILD ENOUGH_IPV4_NS_DEL ENOUGH_IPV6_NS_CHILD ENOUGH_IPV6_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL ) ],
                 undef,
                 [],
                 [],
                ],
                'ENOUGH-2' =>
                [
                 1,
                 q(enough-2.delegation01.xa),
                 [ qw(ENOUGH_IPV4_NS_CHILD ENOUGH_IPV4_NS_DEL ENOUGH_IPV6_NS_CHILD ENOUGH_IPV6_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL ) ],
                 undef,
                 [],
                 [],
                ],
                'ENOUGH-3' =>
                [
                 1,
                 q(enough-3.delegation01.xa),
                 [ qw(ENOUGH_IPV4_NS_CHILD ENOUGH_IPV4_NS_DEL ENOUGH_IPV6_NS_CHILD ENOUGH_IPV6_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL ) ],
                 undef,
                 [],
                 [],
                ],
                'ENOUGH-DEL-NOT-CHILD' =>
                [
                 0,
                 q(enough-del-not-child.delegation01.xa),
                 [ qw(ENOUGH_IPV4_NS_DEL ENOUGH_IPV6_NS_DEL ENOUGH_NS_DEL NOT_ENOUGH_IPV4_NS_CHILD NOT_ENOUGH_IPV6_NS_CHILD NOT_ENOUGH_NS_CHILD ) ],
                 undef,
                 [],
                 [],
                ],
                'ENOUGH-CHILD-NOT-DEL' =>
                [
                 1,
                 q(enough-child-not-del.delegation01.xa),
                 [ qw(ENOUGH_IPV4_NS_CHILD ENOUGH_IPV6_NS_CHILD ENOUGH_NS_CHILD NOT_ENOUGH_IPV4_NS_DEL NOT_ENOUGH_IPV6_NS_DEL NOT_ENOUGH_NS_DEL ) ],
                 undef,
                 [],
                 [],
                ],
                'IPV6-AND-DEL-OK-NO-IPV4-CHILD' =>
                [
                 0,
                 q(ipv6-and-del-ok-no-ipv4-child.delegation01.xa),
                 [ qw(ENOUGH_IPV4_NS_DEL ENOUGH_IPV6_NS_CHILD ENOUGH_IPV6_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL NO_IPV4_NS_CHILD ) ],
                 undef,
                 [],
                 [],
                ],
                'IPV4-AND-DEL-OK-NO-IPV6-CHILD' =>
                [
                 0,
                 q(ipv4-and-del-ok-no-ipv6-child.delegation01.xa),
                 [ qw(ENOUGH_IPV4_NS_DEL ENOUGH_IPV4_NS_CHILD ENOUGH_IPV6_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL NO_IPV6_NS_CHILD ) ],
                 undef,
                 [],
                 [],
                ],
                'NO-IPV4-1' =>
                [
                 1,
                 q(no-ipv4-1.delegation01.xa),
                 [ qw(ENOUGH_IPV6_NS_CHILD ENOUGH_IPV6_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL NO_IPV4_NS_CHILD NO_IPV4_NS_DEL ) ],
                                undef,
                 [],
                 [],
                ],
                'NO-IPV4-2' =>
                [
                 1,
                 q(no-ipv4-2.delegation01.xa),
                 [ qw(ENOUGH_IPV6_NS_CHILD ENOUGH_IPV6_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL NO_IPV4_NS_CHILD NO_IPV4_NS_DEL ) ],
                 undef,
                 [],
                 [],
                ],
                'NO-IPV4-3' =>
                [
                 1,
                 q(no-ipv4-3.delegation01.xa),
                 [ qw(ENOUGH_IPV6_NS_CHILD ENOUGH_IPV6_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL NO_IPV4_NS_CHILD NO_IPV4_NS_DEL ) ],
                 undef,
                 [],
                 [],
                ],
                'NO-IPV6-1' =>
                [
                 1,
                 q(no-ipv6-1.delegation01.xa),
                 [ qw(ENOUGH_IPV4_NS_CHILD ENOUGH_IPV4_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL NO_IPV6_NS_CHILD NO_IPV6_NS_DEL ) ],
                 undef,
                 [],
                 [],
                ],
                'NO-IPV6-2' =>
                [
                 1,
                 q(no-ipv6-2.delegation01.xa),
                 [ qw(ENOUGH_IPV4_NS_CHILD ENOUGH_IPV4_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL NO_IPV6_NS_CHILD NO_IPV6_NS_DEL ) ],
                 undef,
                 [],
                 [],
                ],
                'NO-IPV6-3' =>
                [
                 1,
                 q(no-ipv6-3.delegation01.xa),
                 [ qw(ENOUGH_IPV4_NS_CHILD ENOUGH_IPV4_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL NO_IPV6_NS_CHILD NO_IPV6_NS_DEL ) ],
                 undef,
                 [],
                 [],
                ],
                'MISMATCH-DELEGATION-CHILD-1' =>
                [
                 0,
                 q(mismatch-delegation-child-1.delegation01.xa),
                 [ qw(ENOUGH_IPV4_NS_CHILD NOT_ENOUGH_IPV4_NS_DEL ENOUGH_IPV6_NS_CHILD NOT_ENOUGH_IPV6_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL ) ],
                 undef,
                 [],
                 [],
                ],
                'MISMATCH-DELEGATION-CHILD-2' =>
                [
                 0,
                 q(mismatch-delegation-child-2.delegation01.xa),
                 [ qw(NOT_ENOUGH_IPV4_NS_CHILD ENOUGH_IPV4_NS_DEL NOT_ENOUGH_IPV6_NS_CHILD ENOUGH_IPV6_NS_DEL ENOUGH_NS_CHILD ENOUGH_NS_DEL ) ],
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
