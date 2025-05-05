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
# Delegation03 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Delegation-TP/delegation03.md
my $test_module = 'Delegation';
my $test_case = 'delegation03';
my @all_tags = qw(
                   REFERRAL_SIZE_OK
                   REFERRAL_SIZE_TOO_LARGE
                 );

# Specific hint file (https://github.com/zonemaster/zonemaster/blob/master/test-zone-data/Delegation-TP/delegation03/hintfile.zone)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'root-ns1.xa' => [ '127.16.3.27', 'fda1:b2:c3::127:16:3:27' ],
      'root-ns2.xa' => [ '127.16.3.28', 'fda1:b2:c3::127:16:3:28' ],
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
                'REFERRAL-SIZE-OK-1' =>
                [
                 1,
                 q(referral-size-ok-1.delegation03.xa.),
                 [ qw( REFERRAL_SIZE_OK ) ],
                 undef,
                 [],
                 [],
                ],
                'REFERRAL-SIZE-OK-2' =>
                [
                 1,
                 q(referral-size-ok-2.delegation03.xa.),
                 [ qw( REFERRAL_SIZE_OK ) ],
                 undef,
                 [],
                 [],
                ],
                'REFERRAL-SIZE-TOO-LARGE-1' =>
                [
                 1,
                 q(referral-size-too-large-1.delegation03.xa),
                 [ qw( REFERRAL_SIZE_TOO_LARGE ) ],
                 undef,
                 [],
                 [],
                ],
                'REFERRAL-SIZE-TOO-LARGE-2' =>
                [
                 1,
                 q(referral-size-too-large-2.delegation03.xa),
                 [ qw( REFERRAL_SIZE_TOO_LARGE ) ],
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

