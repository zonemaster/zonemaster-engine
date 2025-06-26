use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Zone} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# zone09 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Zone-TP/zone09.md
my $test_module = q{Zone};
my $test_case = 'zone09';
my @all_tags = qw(Z09_INCONSISTENT_MX
                  Z09_INCONSISTENT_MX_DATA
                  Z09_MISSING_MAIL_TARGET
                  Z09_MX_DATA
                  Z09_MX_FOUND
                  Z09_NON_AUTH_MX_RESPONSE
                  Z09_NO_MX_FOUND
                  Z09_NO_RESPONSE_MX_QUERY
                  Z09_NULL_MX_NON_ZERO_PREF
                  Z09_NULL_MX_WITH_OTHER_MX
                  Z09_ROOT_EMAIL_DOMAIN
                  Z09_TLD_EMAIL_DOMAIN
                  Z09_UNEXPECTED_RCODE_MX);

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
    'NO-RESPONSE-MX-QUERY' => [
        1,
        q(no-response-mx-query.zone09.xa),#
        [ qw(Z09_NO_RESPONSE_MX_QUERY) ],
        [],
        [],
        []
    ],
    'UNEXPECTED-RCODE-MX' => [
        1,
        q(unexpected-rcode-mx.zone09.xa),#
        [ qw(Z09_UNEXPECTED_RCODE_MX) ],
        [],
        [],
        []
    ],
    'NON-AUTH-MX-RESPONSE' => [
        0,
        q(non-auth-mx-response.zone09.xa),#
        [ qw(Z09_NON_AUTH_MX_RESPONSE) ],
        [],
        [],
        []
    ],
    'INCONSISTENT-MX' => [
        1,
        q(inconsistent-mx.zone09.xa),#
        [ qw(Z09_INCONSISTENT_MX Z09_MX_FOUND Z09_NO_MX_FOUND Z09_MX_DATA) ],
        [ qw(Z09_MISSING_MAIL_TARGET) ],
        [],
        []
    ],
    'INCONSISTENT-MX-DATA' => [
        1,
        q(inconsistent-mx-data.zone09.xa),
        [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA) ],
        undef,
        [],
        []
    ],
    'NULL-MX-WITH-OTHER-MX' => [
        1,
        q(null-mx-with-other-mx.zone09.xa),#
        [ qw(Z09_NULL_MX_WITH_OTHER_MX) ],
        [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA Z09_MISSING_MAIL_TARGET Z09_ROOT_EMAIL_DOMAIN Z09_TLD_EMAIL_DOMAIN) ],
        [],
        []
    ],
    'NULL-MX-NON-ZERO-PREF' => [
        1,
        q(null-mx-non-zero-pref.zone09.xa),#
        [ qw(Z09_NULL_MX_NON_ZERO_PREF) ],
        [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA Z09_MISSING_MAIL_TARGET Z09_ROOT_EMAIL_DOMAIN Z09_TLD_EMAIL_DOMAIN) ],
        [],
        []
    ],
    'TLD-EMAIL-DOMAIN' => [
        1,
        q(tld-email-domain-zone09),
        [ qw(Z09_TLD_EMAIL_DOMAIN) ],
        undef,
        [],
        []
    ],
    'MX-DATA' => [
        1,
        q(mx-data.zone09.xa),
        [ qw(Z09_MX_DATA) ],
        undef,
        [],
        []
    ],
    'NULL-MX' => [
        1,
        q(null-mx.zone09.xa),
        [],
        undef,
        [],
        []
    ],
    'NO-MX-SLD' => [
        1,
        q(no-mx-sld.zone09.xa),
        [ qw(Z09_MISSING_MAIL_TARGET) ],
        undef,
        [],
        []
    ],
    'NO-MX-TLD' => [
        1,
        q(no-mx-tld-zone09),
        [],
        undef,
        [],
        []
    ],
    'NO-MX-ARPA'  => [
        1,
        q(no-mx-arpa.zone09.arpa),
        [],
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
