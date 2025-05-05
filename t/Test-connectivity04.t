use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Connectivity} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# connectivity04 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Connectivity-TP/connectivity04.md
my $test_module = 'Connectivity';
my $test_case = 'connectivity04';
my @all_tags = qw(CN04_EMPTY_PREFIX_SET
                  CN04_ERROR_PREFIX_DATABASE
                  CN04_IPV4_DIFFERENT_PREFIX
                  CN04_IPV4_SAME_PREFIX
                  CN04_IPV4_SINGLE_PREFIX
                  CN04_IPV6_DIFFERENT_PREFIX
                  CN04_IPV6_SAME_PREFIX
                  CN04_IPV6_SINGLE_PREFIX);

# Specific hint file (https://github.com/zonemaster/zonemaster/blob/master/test-zone-data/Connectivity-TP/connectivity04/hintfile.zone)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'root-ns1.xa' => [ '127.13.4.23', 'fda1:b2:c3::127:13:4:23' ],
      'root-ns2.xa' => [ '127.13.4.24', 'fda1:b2:c3::127:13:4:24' ],
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
        q(good-1.connectivity04.xa),
        [ qw(CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX) ],
        undef,
        [],
        [],
    ],
    'GOOD-2' => [
        1,
        q(good-2.connectivity04.xa),
        [ qw(CN04_IPV4_DIFFERENT_PREFIX) ],
        undef,
        [],
        [],
    ],
    'GOOD-3' => [
        1,
        q(good-3.connectivity04.xa),
        [ qw(CN04_IPV6_DIFFERENT_PREFIX) ],
        undef,
        [],
        [],
    ],
    'EMPTY-PREFIX-SET-1' => [
        1,
        q(empty-prefix-set-1.connectivity04.xa),
        [ qw(CN04_EMPTY_PREFIX_SET) ],
        undef,
        [],
        [],
    ],
    'EMPTY-PREFIX-SET-2' => [
        1,
        q(empty-prefix-set-2.connectivity04.xa),
        [ qw(CN04_EMPTY_PREFIX_SET) ],
        undef,
        [],
        [],
    ],
    'ERROR-PREFIX-DATABASE-1' => [
        1,
        q(error-prefix-database-1.connectivity04.xa),
        [ qw(CN04_ERROR_PREFIX_DATABASE) ],
        undef,
        [],
        [],
    ],
    'ERROR-PREFIX-DATABASE-2' => [
        1,
        q(error-prefix-database-2.connectivity04.xa),
        [ qw(CN04_ERROR_PREFIX_DATABASE) ],
        undef,
        [],
        [],
    ],
    #
    # 'ERROR-PREFIX-DATABASE-3' defined in Test-connectivity04-A.t
    #
    'ERROR-PREFIX-DATABASE-6' => [
        1,
        q(error-prefix-database-6.connectivity04.xa),
        [ qw(CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX CN04_ERROR_PREFIX_DATABASE) ],
        undef,
        [],
        [],
    ],
    'ERROR-PREFIX-DATABASE-7' => [
        1,
        q(error-prefix-database-7.connectivity04.xa),
        [ qw(CN04_ERROR_PREFIX_DATABASE) ],
        undef,
        [],
        [],
    ],
    'ERROR-PREFIX-DATABASE-8' => [
        1,
        q(error-prefix-database-8.connectivity04.xa),
        [ qw(CN04_ERROR_PREFIX_DATABASE) ],
        undef,
        [],
        [],
    ],
    'HAS-NON-ASN-TXT-1' => [
        1,
        q(has-non-asn-txt-1.connectivity04.xa),
        [ qw(CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX) ],
        undef,
        [],
        [],
    ],
    'HAS-NON-ASN-TXT-2' => [
        1,
        q(has-non-asn-txt-2.connectivity04.xa),
        [ qw(CN04_EMPTY_PREFIX_SET) ],
        undef,
        [],
        [],
    ],
    'IPV4-ONE-PREFIX-1' => [
        1,
        q(ipv4-one-prefix-1.connectivity04.xa),
        [ qw(CN04_IPV4_SAME_PREFIX CN04_IPV4_SINGLE_PREFIX) ],
        undef,
        [],
        [],
    ],
    'IPV4-TWO-PREFIXES-1' => [
        1,
        q(ipv4-two-prefixes-1.connectivity04.xa),
        [ qw(CN04_IPV4_SAME_PREFIX CN04_IPV4_DIFFERENT_PREFIX) ],
        undef,
        [],
        [],
    ],
    'IPV6-ONE-PREFIX-1' => [
        1,
        q(ipv6-one-prefix-1.connectivity04.xa),
        [ qw(CN04_IPV6_SAME_PREFIX CN04_IPV6_SINGLE_PREFIX) ],
        undef,
        [],
        [],
    ],
    'IPV6-TWO-PREFIXES-1' => [
        1,
        q(ipv6-two-prefixes-1.connectivity04.xa),
        [ qw(CN04_IPV6_SAME_PREFIX CN04_IPV6_DIFFERENT_PREFIX) ],
        undef,
        [],
        [],
    ],
    'IPV4-SINGLE-NS-1' => [
        1,
        q(ipv4-single-ns-1.connectivity04.xa),
        [ qw(CN04_IPV4_SINGLE_PREFIX CN04_IPV4_DIFFERENT_PREFIX) ],
        undef,
        [],
        [],
    ],
    'IPV6-SINGLE-NS-1' => [
        1,
        q(ipv6-single-ns-1.connectivity04.xa),
        [ qw(CN04_IPV6_SINGLE_PREFIX CN04_IPV6_DIFFERENT_PREFIX) ],
        undef,
        [],
        [],
    ],
    'DOUBLE-PREFIX-1' => [
        1,
        q(double-prefix-1.connectivity04.xa),
        [ qw(CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX) ],
        undef,
        [],
        [],
    ],
    'DOUBLE-PREFIX-2' => [
        1,
        q(double-prefix-2.connectivity04.xa),
        [ qw(CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX) ],
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
