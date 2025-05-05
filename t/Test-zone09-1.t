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

# Test case specific hints file (test-zone-data/Zone-TP/zone09/hintfile-root-email-domain)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'ns1' => [ '127.19.9.43', 'fda1:b2:c3::127:19:9:43' ],
      'ns2' => [ '127.19.9.44', 'fda1:b2:c3::127:19:9:44' ],
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
    'ROOT-EMAIL-DOMAIN' => [
        1,
        q(.),
        [ qw(Z09_ROOT_EMAIL_DOMAIN) ],
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
