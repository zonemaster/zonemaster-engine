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

# Specific hint file (test-zone-data/Zone-TP/zone11/no-spf.hintfile)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'ns1' => [ '127.19.11.41', 'fda1:b2:c3::127:19:11:41' ],
      'ns2' => [ '127.19.11.42', 'fda1:b2:c3::127:19:11:42' ],
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
    'NO-SPF-ROOT-ZONE' => [
        1,
        q(.),
        [ qw( Z11_NO_SPF_NON_MAIL_DOMAIN ) ],
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
