use strict;
use warnings;
use utf8;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Zone} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# Zone11 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Zone-TP/zone11.md
my $test_module = q{Zone};
my $test_case = 'zone11';
my @all_tags = qw(Z11_DIFFERENT_SPF_POLICIES_FOUND
                  Z11_INCONSISTENT_SPF_POLICIES
                  Z11_NO_SPF_FOUND
                  Z11_NO_SPF_NON_MAIL_DOMAIN
                  Z11_NON_NULL_SPF_NON_MAIL_DOMAIN
                  Z11_NULL_SPF_NON_MAIL_DOMAIN
                  Z11_SPF_MULTIPLE_RECORDS
                  Z11_SPF_SYNTAX_ERROR
                  Z11_SPF_SYNTAX_OK
                  Z11_UNABLE_TO_CHECK_FOR_SPF);

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
    'GOOD-SPF-1' => [
        1,
        q(good-spf-1.zone11.xa),
        [ qw( Z11_SPF_SYNTAX_OK ) ],
        undef,
        [],
        []
    ],
    'GOOD-SPF-2' => [
        1,
        q(good-spf-2.zone11.xa),
        [ qw( Z11_SPF_SYNTAX_OK ) ],
        undef,
        [],
        []
    ],
    'SAME-SPF-DIFFERENT-TXT' => [
        1,
        q(same-spf-different-txt.zone11.xa),
        [ qw( Z11_SPF_SYNTAX_OK ) ],
        undef,
        [],
        []
    ],
    'NO-TXT' => [
        1,
        q(no-txt.zone11.xa),
        [ qw( Z11_NO_SPF_FOUND ) ],
        undef,
        [],
        []
    ],
    'NO-SPF-TXT' => [
        1,
        q(no-spf-txt.zone11.xa),
        [ qw( Z11_NO_SPF_FOUND ) ],
        undef,
        [],
        []
    ],
    #
    # NO-SPF-ROOT-ZONE - Tested separately, see Test-zone11-1.t
    #
    'NO-SPF-TLD-ZONE' => [
        1,
        q(no-spf-zone11),
        [ qw( Z11_NO_SPF_NON_MAIL_DOMAIN ) ],
        undef,
        [],
        []
    ],
    'NO-SPF-ARPA-ZONE' => [
        1,
        q(no-spf-arpa-zone.zone11.arpa),
        [ qw( Z11_NO_SPF_NON_MAIL_DOMAIN ) ],
        undef,
        [],
        []
    ],
    #
    # NULL-SPF-ROOT-ZONE - Tested separately, see Test-zone11-2.t
    #
    'NULL-SPF-TLD-ZONE' => [
        1,
        q(null-spf-zone11),
        [ qw( Z11_NULL_SPF_NON_MAIL_DOMAIN ) ],
        undef,
        [],
        []
    ],
    'NULL-SPF-ARPA-ZONE' => [
        1,
        q(null-spf-arpa-zone.zone11.arpa),
        [ qw( Z11_NULL_SPF_NON_MAIL_DOMAIN ) ],
        undef,
        [],
        []
    ],
    #
    # NON-NULL-SPF-ROOT-ZONE - Tested separately, see Test-zone11-3.t
    #
    'NON-NULL-SPF-TLD-ZONE' => [
        1,
        q(non-null-spf-zone11),
        [ qw( Z11_NON_NULL_SPF_NON_MAIL_DOMAIN ) ],
        undef,
        [],
        []
    ],
    'NON-NULL-SPF-ARPA-ZONE' => [
        1,
        q(non-null-spf-arpa-zone.zone11.arpa),
        [ qw( Z11_NON_NULL_SPF_NON_MAIL_DOMAIN ) ],
        undef,
        [],
        []
    ],
    'INVALID-SYNTAX-1' => [
        1,
        q(invalid-syntax-1.zone11.xa),
        [ qw( Z11_SPF_SYNTAX_ERROR ) ],
        undef,
        [],
        []
    ],
    'INVALID-SYNTAX-2' => [
        1,
        q(invalid-syntax-2.zone11.xa),
        [ qw( Z11_SPF_SYNTAX_ERROR ) ],
        undef,
        [],
        []
    ],
    'INVALID-SYNTAX-3' => [
        1,
        q(invalid-syntax-3.zone11.xa),
        [ qw( Z11_SPF_SYNTAX_ERROR ) ],
        undef,
        [],
        []
    ],
    'NON-AUTH-TXT' => [
        1,
        q(non-auth-txt.zone11.xa),
        [ qw( Z11_UNABLE_TO_CHECK_FOR_SPF ) ],
        undef,
        [],
        []
    ],
    'SERVFAIL' => [
        1,
        q(servfail.zone11.xa),
        [ qw( Z11_UNABLE_TO_CHECK_FOR_SPF ) ],
        undef,
        [],
        []
    ],
    'INCONSISTENT-SPF' => [
        1,
        q(INCONSISTENT-SPF.zone11.xa),
        [ qw( Z11_INCONSISTENT_SPF_POLICIES Z11_DIFFERENT_SPF_POLICIES_FOUND ) ],
        undef,
        [],
        []
    ],
    'SPF-MISSING-ON-ONE' => [
        1,
        q(spf-missing-on-one.zone11.xa),
        [ qw( Z11_INCONSISTENT_SPF_POLICIES Z11_DIFFERENT_SPF_POLICIES_FOUND ) ],
        undef,
        [],
        []
    ],
    'ALL-DIFFERENT-SPF' => [
        1,
        q(all-different-spf.zone11.xa),
        [ qw( Z11_INCONSISTENT_SPF_POLICIES Z11_DIFFERENT_SPF_POLICIES_FOUND ) ],
        undef,
        [],
        []
    ],
    'MULTIPLE-SPF-RECORDS' => [
        1,
        q(multiple-spf-records.zone11.xa),
        [ qw( Z11_SPF_MULTIPLE_RECORDS ) ],
        undef,
        [],
        []
    ]
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
