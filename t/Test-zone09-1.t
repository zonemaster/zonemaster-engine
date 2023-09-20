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

# Test case specific hints file (test-zone-data/Zone-TP/zone09/hintfile-root-email-domain)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'ns1' => [ '127.19.9.43', 'fda1:b2:c3::127:19:9:43' ],
      'ns2' => [ '127.19.9.44', 'fda1:b2:c3::127:19:9:44' ],
    }
);

# Test zone scenarios
my %subtests = (
    'ROOT-EMAIL-DOMAIN' => {
        zone => q(.),
        mandatory => [ qw(Z09_ROOT_EMAIL_DOMAIN) ],
        forbidden => [ qw(Z09_INCONSISTENT_MX_DATA Z09_MX_DATA Z09_MISSING_MAIL_TARGET Z09_TLD_EMAIL_DOMAIN Z09_NULL_MX_WITH_OTHER_MX Z09_NULL_MX_NON_ZERO_PREF) ],
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
