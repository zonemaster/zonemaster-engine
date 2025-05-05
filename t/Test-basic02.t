use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Basic} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# basic02 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Basic-TP/basic02.md
my $test_module = 'Basic';
my $test_case = 'basic02';
my @all_tags = qw(B02_AUTH_RESPONSE_SOA
                  B02_NO_DELEGATION
                  B02_NO_WORKING_NS
                  B02_NS_BROKEN
                  B02_NS_NOT_AUTH
                  B02_NS_NO_IP_ADDR
                  B02_NS_NO_RESPONSE
                  B02_UNEXPECTED_RCODE);

# Specific hint file (test-zone-data/Basic-TP/basic02/hintfile.zone)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'root-ns1.xa' => [ '127.12.2.23', 'fda1:b2:c3::127:12:2:23' ],
      'root-ns2.xa' => [ '127.12.2.24', 'fda1:b2:c3::127:12:2:24' ],
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
                'GOOD-1' =>
                [
                 1,
                 q(good-1.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [],
                 [],
                ],
                'GOOD-2' =>
                [
                 1,
                 q(good-1.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [],
                 [],
                ],
                'GOOD-UNDEL-1' =>
                [
                 1,
                 q(good-undel-1.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [ qw(ns1.good-undel-1.basic02.xa/127.12.2.31
                      ns1.good-undel-1.basic02.xa/fda1:b2:c3:0:127:12:2:31
                      ns2.good-undel-1.basic02.xa/127.12.2.32
                      ns2.good-undel-1.basic02.xa/fda1:b2:c3:0:127:12:2:32) ],
                 [],
                ],
                'GOOD-UNDEL-2' =>
                [
                 1,
                 q(good-undel-2.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [ qw(ns1.good-undel-2.basic02.xb
                      ns2.good-undel-2.basic02.xb) ],
                 [],
                ],
                'GOOD-UNDEL-3' =>
                [
                 1,
                 q(good-undel-3.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [ qw(ns3.good-undel-3.basic02.xb
                      ns4.good-undel-3.basic02.xb) ],
                 [],
                ],
                'GOOD-UNDEL-4' =>
                [
                 1,
                 q(good-undel-4.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [ qw(ns1.good-undel-4.basic02.xb
                      ns2.good-undel-4.basic02.xb) ],
                 [],
                ],
                'GOOD-UNDEL-5' =>
                [
                 1,
                 q(good-undel-5.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [ qw(ns1.good-undel-5.basic02.xa/127.12.2.31
                      ns1.good-undel-5.basic02.xa/fda1:b2:c3:0:127:12:2:31
                      ns2.good-undel-5.basic02.xa/127.12.2.32
                      ns2.good-undel-5.basic02.xa/fda1:b2:c3:0:127:12:2:32) ],
                 [],
                ],
                'GOOD-UNDEL-6' =>
                [
                 1,
                 q(good-undel-6.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [ qw(ns3.good-undel-6.basic02.xa/127.12.2.33
                      ns3.good-undel-6.basic02.xa/fda1:b2:c3:0:127:12:2:33
                      ns4.good-undel-6.basic02.xa/127.12.2.34
                      ns4.good-undel-6.basic02.xa/fda1:b2:c3:0:127:12:2:34) ],
                 [],
                ],
                'GOOD-UNDEL-7' =>
                [
                 1,
                 q(good-undel-7.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [ qw(ns3.good-undel-7.basic02.xb/127.12.2.33
                      ns3.good-undel-7.basic02.xb/fda1:b2:c3:0:127:12:2:33
                      ns4.good-undel-7.basic02.xb/127.12.2.34
                      ns5.good-undel-7.basic02.xb/fda1:b2:c3:0:127:12:2:34) ],
                 [],
                ],
                'GOOD-UNDEL-8' =>
                [
                 1,
                 q(good-undel-8.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [ qw(dns1.good-undel-8.basic02.xa/127.12.2.33
                      dns1.good-undel-8.basic02.xa/fda1:b2:c3:0:127:12:2:33
                      dns2.good-undel-8.basic02.xa/127.12.2.34
                      dns2.good-undel-8.basic02.xa/fda1:b2:c3:0:127:12:2:34) ],
                 [],
                ],
                'GOOD-UNDEL-9' =>
                [
                 1,
                 q(good-undel-9.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [ qw(dns1.good-undel-9.basic02.xb/127.12.2.33
                      dns1.good-undel-9.basic02.xb/fda1:b2:c3:0:127:12:2:33
                      dns2.good-undel-9.basic02.xb/127.12.2.34
                      dns2.good-undel-9.basic02.xb/fda1:b2:c3:0:127:12:2:34) ],
                 [],
                ],
                'GOOD-UNDEL-10' =>
                [
                 1,
                 q(good-undel-10.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [ qw(ns3.good-undel-10.basic02.xb/127.12.2.33
                      ns3.good-undel-10.basic02.xb/fda1:b2:c3:0:127:12:2:33
                      ns4.good-undel-10.basic02.xb/127.12.2.34
                      ns4.good-undel-10.basic02.xb/fda1:b2:c3:0:127:12:2:34) ],
                 [],
                ],
                'GOOD-UNDEL-11' =>
                [
                 1,
                 q(good-undel-11.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [ qw(ns3.good-undel-11.basic02.xb
                      ns4.good-undel-11.basic02.xb) ],
                 [],
                ],
                'MIXED-1' =>
                [
                 1,
                 q(mixed-1.basic02.xa),
                 [ qw(B02_AUTH_RESPONSE_SOA) ],
                 undef,
                 [],
                 [],
                ],
                'NO-DELEGATION-1' =>
                [
                 1,
                 q(no-delegation.basic02.xa),
                 [ qw(B02_NO_DELEGATION) ],
                 undef,
                 [],
                 [],
                ],
                'NS-BROKEN-1' =>
                [
                 1,
                 q(ns-broken-1.basic02.xa),
                 [ qw(B02_NS_BROKEN B02_NO_WORKING_NS) ],
                 undef,
                 [],
                 [],
                ],
                'NS-NOT-AUTH-1' =>
                [
                 1,
                 q(ns-not-auth-1.basic02.xa),
                 [ qw(B02_NS_NOT_AUTH B02_NO_WORKING_NS) ],
                 undef,
                 [],
                 [],
                ],
                'NS-NO-IP-1' =>
                [
                 1,
                 q(ns-no-ip-1.basic02.xa),
                 [ qw(B02_NS_NO_IP_ADDR B02_NO_WORKING_NS) ],
                 undef,
                 [],
                 [],
                ],
                'NS-NO-IP-2' =>
                [
                 1,
                 q(ns-no-ip-2.basic02.xa),
                 [ qw(B02_NS_NO_IP_ADDR B02_NO_WORKING_NS) ],
                 undef,
                 [],
                 [],
                ],
                'NS-NO-IP-3' =>
                [
                 1,
                 q(ns-no-ip-3.basic02.xa),
                 [ qw(B02_NS_NO_IP_ADDR B02_NO_WORKING_NS) ],
                 undef,
                 [],
                 [],
                ],
                'NS-NO-IP-UNDEL-1' =>
                [
                 1,
                 q(ns-no-ip-undel-1.basic02.xa),
                 [ qw(B02_NS_NO_IP_ADDR B02_NO_WORKING_NS) ],
                 undef,
                 [ qw(ns1.ns-no-ip-undel-1.basic02.xa
                      ns2.ns-no-ip-undel-1.basic02.xa) ],
                 [],
                ],
                'NS-NO-IP-UNDEL-2' =>
                [
                 1,
                 q(ns-no-ip-undel-2.basic02.xa),
                 [ qw(B02_NS_NO_IP_ADDR B02_NO_WORKING_NS) ],
                 undef,
                 [ qw(ns1.ns-no-ip-undel-2.basic02.xb
                      ns2.ns-no-ip-undel-2.basic02.xb) ],
                 [],
                ],
                'NS-NO-RESPONSE-1' =>
                [
                 1,
                 q(ns-no-response-1.basic02.xa),
                 [ qw(B02_NS_NO_RESPONSE B02_NO_WORKING_NS) ],
                 undef,
                 [],
                 [],
                ],
                'UNEXPECTED-RCODE-1' =>
                [
                 1,
                 q(unexpected-rcode-1.basic02.xa),
                 [ qw(B02_UNEXPECTED_RCODE B02_NO_WORKING_NS) ],
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
