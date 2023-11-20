use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Nameserver} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# nameserver15 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Nameserver-TP/nameserver15.md
my $test_module = 'Nameserver';
my $test_case = 'nameserver15';

# Common hint file (test-zone-data/COMMON/hintfile)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'ns1' => [ '127.1.0.1', 'fda1:b2:c3::127:1:0:1' ],
      'ns2' => [ '127.1.0.2', 'fda1:b2:c3::127:1:0:2' ],
    }
);

# Test zone scenarios
# - Documentation: L<TestUtil/perform_testcase_testing()>
# - Format: { SCENARIO_NAME => [ zone_name, [ MANDATORY_MESSAGE_TAGS ], [ FORBIDDEN_MESSAGE_TAGS ], testable ] }
my %subtests = (
    'NO-VERSION-REVEALED-1' => [
        q(no-version-revealed-1.nameserver15.xa),
        [ qw(N15_NO_VERSION_REVEALED) ],
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_SOFTWARE_VERSION N15_WRONG_CLASS) ],
        1
    ],
    'NO-VERSION-REVEALED-2' => [
        q(no-version-revealed-2.nameserver15.xa),
        [ qw(N15_NO_VERSION_REVEALED) ],
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_SOFTWARE_VERSION N15_WRONG_CLASS) ],
        1
    ],
    'NO-VERSION-REVEALED-3' => [
        q(no-version-revealed-3.nameserver15.xa),
        [ qw(N15_NO_VERSION_REVEALED) ],
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_SOFTWARE_VERSION N15_WRONG_CLASS) ],
        1
    ],
    'NO-VERSION-REVEALED-4' => [
        q(no-version-revealed-4.nameserver15.xa),
        [ qw(N15_NO_VERSION_REVEALED) ],
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_SOFTWARE_VERSION N15_WRONG_CLASS) ],
        1
    ],
    'NO-VERSION-REVEALED-5' => [
        q(no-version-revealed-5.nameserver15.xa),
        [ qw(N15_NO_VERSION_REVEALED) ],
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_SOFTWARE_VERSION N15_WRONG_CLASS) ],
        1
    ],
    'NO-VERSION-REVEALED-6' => [
        q(no-version-revealed-6.nameserver15.xa),
        [ qw(N15_NO_VERSION_REVEALED) ],
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_SOFTWARE_VERSION N15_WRONG_CLASS) ],
        1
    ],
    'ERROR-ON-VERSION-QUERY-1' => [
        q(error-on-version-query-1.nameserver15.xa),
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_NO_VERSION_REVEALED) ],
        [ qw(N15_SOFTWARE_VERSION N15_WRONG_CLASS) ],
        1
    ],
    'ERROR-ON-VERSION-QUERY-2' => [
        q(error-on-version-query-2.nameserver15.xa),
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_NO_VERSION_REVEALED) ],
        [ qw(N15_SOFTWARE_VERSION N15_WRONG_CLASS) ],
        1
    ],
    'SOFTWARE-VERSION-1' => [
        q(software-version-1.nameserver15.xa),
        [ qw(N15_SOFTWARE_VERSION) ],
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_NO_VERSION_REVEALED N15_WRONG_CLASS) ],
        1
    ],
    'SOFTWARE-VERSION-2' => [
        q(software-version-2.nameserver15.xa),
        [ qw(N15_SOFTWARE_VERSION) ],
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_NO_VERSION_REVEALED N15_WRONG_CLASS) ],
        1
    ],
    'WRONG-CLASS-1' => [
        q(wrong-class-1.nameserver15.xa),
        [ qw(N15_SOFTWARE_VERSION N15_WRONG_CLASS) ],
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_NO_VERSION_REVEALED) ],
        1
    ],
    'WRONG-CLASS-2' => [
        q(wrong-class-2.nameserver15.xa),
        [ qw(N15_SOFTWARE_VERSION N15_WRONG_CLASS) ],
        [ qw(N15_ERROR_ON_VERSION_QUERY N15_NO_VERSION_REVEALED) ],
        1
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

perform_testcase_testing( $test_case, $test_module, %subtests );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
