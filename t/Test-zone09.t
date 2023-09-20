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
# zone09
my $test_module = q{Zone};
my $test_case = 'zone09';

# Common hint file (test-zone-data/COMMON/hintfile)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'ns1' => [ '127.1.0.1', 'fda1:b2:c3::127:1:0:1' ],
      'ns2' => [ '127.1.0.2', 'fda1:b2:c3::127:1:0:2' ],
    }
);

# Test zone scenarios
my %subtests = (
    'NO-RESPONSE-MX-QUERY' => {
        zone => q(no-response-mx-query.zone09.xa),
        mandatory => [ qw(Z09_NO_RESPONSE_MX_QUERY) ],
        forbidden => [],
        testable => 1
    },
    'UNEXPECTED-RCODE-MX' => {
        zone => q(unexpected-rcode-mx.zone09.xa),
        mandatory => [ qw(Z09_UNEXPECTED_RCODE_MX) ],
        forbidden => [],
        testable => 1
    },
    'NON-AUTH-MX-RESPONSE' => {
        zone => q(non-auth-mx-response.zone09.xa),
        mandatory => [ qw(Z09_NON_AUTH_MX_RESPONSE) ],
        forbidden => [],
        testable => 0
    },
    'INCONSISTENT-MX' => {
        zone => q(inconsistent-mx.zone09.xa),
        mandatory => [ qw(Z09_INCONSISTENT_MX Z09_MX_FOUND Z09_NO_MX_FOUND Z09_MX_DATA) ],
        forbidden => [ qw(Z09_MISSING_MAIL_TARGET) ],
        testable => 1
    },
    'INCONSISTENT-MX-DATA' => {
        zone => q(inconsistent-mx-data.zone09.xa),
        mandatory => [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA) ],
        forbidden => [ qw(Z09_MISSING_MAIL_TARGET Z09_NULL_MX_NON_ZERO_PREF Z09_NULL_MX_WITH_OTHER_MX Z09_ROOT_EMAIL_DOMAIN Z09_TLD_EMAIL_DOMAIN) ],
        testable => 1
    },
    'NULL-MX-WITH-OTHER-MX' => {
        zone => q(null-mx-with-other-mx.zone09.xa),
        mandatory => [ qw(Z09_NULL_MX_WITH_OTHER_MX) ],
        forbidden => [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA Z09_MISSING_MAIL_TARGET Z09_ROOT_EMAIL_DOMAIN Z09_TLD_EMAIL_DOMAIN) ],
        testable => 1
    },
    'NULL-MX-NON-ZERO-PREF' => {
        zone => q(null-mx-non-zero-pref.zone09.xa),
        mandatory => [ qw(Z09_NULL_MX_NON_ZERO_PREF) ],
        forbidden => [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA Z09_MISSING_MAIL_TARGET Z09_ROOT_EMAIL_DOMAIN Z09_TLD_EMAIL_DOMAIN) ],
        testable => 1
    },
    'TLD-EMAIL-DOMAIN' => {
        zone => q(tld-email-domain-zone09),
        mandatory => [ qw(Z09_TLD_EMAIL_DOMAIN) ],
        forbidden => [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA Z09_MISSING_MAIL_TARGET Z09_ROOT_EMAIL_DOMAIN Z09_NULL_MX_WITH_OTHER_MX Z09_NULL_MX_NON_ZERO_PREF) ],
        testable => 1
    },
    'MX-DATA' => {
        zone => q(mx-data.zone09.xa),
        mandatory => [ qw(Z09_MX_DATA) ],
        forbidden => [ qw(Z09_INCONSISTENT_MX_DATA Z09_MISSING_MAIL_TARGET Z09_TLD_EMAIL_DOMAIN Z09_ROOT_EMAIL_DOMAIN Z09_NULL_MX_WITH_OTHER_MX Z09_NULL_MX_NON_ZERO_PREF) ],
        testable => 1
    },
    'NULL-MX' => {
        zone => q(null-mx.zone09.xa),
        mandatory => [],
        forbidden => [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA Z09_MISSING_MAIL_TARGET Z09_TLD_EMAIL_DOMAIN Z09_ROOT_EMAIL_DOMAIN Z09_NULL_MX_WITH_OTHER_MX Z09_NULL_MX_NON_ZERO_PREF) ],
        testable => 1
    },
    'NO-MX-SLD' => {
        zone => q(no-mx-sld.zone09.xa),
        mandatory => [ qw(Z09_MISSING_MAIL_TARGET) ],
        forbidden => [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA Z09_TLD_EMAIL_DOMAIN Z09_ROOT_EMAIL_DOMAIN Z09_NULL_MX_WITH_OTHER_MX Z09_NULL_MX_NON_ZERO_PREF) ],
        testable => 1
    },
    'NO-MX-TLD' => {
        zone => q(no-mx-tld-zone09),
        mandatory => [],
        forbidden => [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA Z09_MISSING_MAIL_TARGET Z09_TLD_EMAIL_DOMAIN Z09_ROOT_EMAIL_DOMAIN Z09_NULL_MX_WITH_OTHER_MX Z09_NULL_MX_NON_ZERO_PREF) ],
        testable => 1
    },
    'NO-MX-ARPA'  => {
        zone => q(no-mx-arpa.zone09.arpa),
        mandatory => [],
        forbidden => [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA Z09_MISSING_MAIL_TARGET Z09_TLD_EMAIL_DOMAIN Z09_ROOT_EMAIL_DOMAIN Z09_NULL_MX_WITH_OTHER_MX Z09_NULL_MX_NON_ZERO_PREF) ],
        testable => 1
    }
);
###########

my $datafile = 't/' . basename ($0, '.t') . '.data';

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

Zonemaster::Engine::Profile->effective->merge( Zonemaster::Engine::Profile->from_json( qq({ "test_cases": [ "$test_case" ] }) ) );

perform_testcase_testing( $test_case, $test_module, %subtests );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
