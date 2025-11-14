use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::DNSSEC} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# DNSSEC07 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/DNSSEC-TP/dnssec07.md
my $test_module = 'DNSSEC';
my $test_case = 'dnssec07';
my @all_tags = qw(
                    DS07_DS_FOR_SIGNED_ZONE
                    DS07_DS_ON_PARENT_SERVER
                    DS07_INCONSISTENT_DS
                    DS07_INCONSISTENT_SIGNED
                    DS07_NON_AUTH_RESPONSE_DNSKEY
                    DS07_NOT_SIGNED
                    DS07_NOT_SIGNED_ON_SERVER
                    DS07_NO_DS_ON_PARENT_SERVER
                    DS07_NO_DS_FOR_SIGNED_ZONE
                    DS07_NO_RESPONSE_DNSKEY
                    DS07_SIGNED
                    DS07_SIGNED_ON_SERVER
                    DS07_UNEXP_RCODE_RESP_DNSKEY
                 );

# Specific hint file (https://github.com/zonemaster/zonemaster/blob/master/test-zone-data/DNSSEC-TP/dnssec07/hintfile.zone)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'root-ns1.xa' => [ '127.15.7.27', 'fda1:b2:c3::127:15:7:27' ],
      'root-ns2.xa' => [ '127.15.7.28', 'fda1:b2:c3::127:15:7:28' ],
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
    'SIGNED-AND-DS-1' => [
        1,
        q(signed-and-ds-1.dnssec07.xa),
        [ qw( DS07_DS_FOR_SIGNED_ZONE DS07_DS_ON_PARENT_SERVER DS07_SIGNED DS07_SIGNED_ON_SERVER ) ],
        undef,
        [],
        [],
    ],
    'SIGNED-NO-DS-1' => [
        1,
        q(signed-no-ds-1.dnssec07.xa),
        [ qw( DS07_NO_DS_ON_PARENT_SERVER DS07_NO_DS_FOR_SIGNED_ZONE DS07_SIGNED DS07_SIGNED_ON_SERVER ) ],
        undef,
        [],
        [],
    ],
    'INCONSIST-SIGNED-AND-DS-1' => [
        1,
        q(inconsist-signed-and-ds-1.dnssec07.xa),
        [ qw( DS07_DS_ON_PARENT_SERVER DS07_INCONSISTENT_SIGNED DS07_NOT_SIGNED_ON_SERVER DS07_SIGNED_ON_SERVER ) ],
        undef,
        [],
        [],
    ],
    'INCONSIST-SIGNED-NO-DS-1' => [
        1,
        q(inconsist-signed-no-ds-1.dnssec07.xa),
        [ qw( DS07_INCONSISTENT_SIGNED DS07_NOT_SIGNED_ON_SERVER DS07_NO_DS_ON_PARENT_SERVER DS07_SIGNED_ON_SERVER ) ],
        undef,
        [],
        [],
    ],
    'SIGNED-AND-INCONSIST-DS-1' => [
        1,
        q(child.signed-and-inconsist-ds-1.dnssec07.xa),
        [ qw( DS07_DS_ON_PARENT_SERVER DS07_INCONSISTENT_DS DS07_NO_DS_ON_PARENT_SERVER DS07_SIGNED DS07_SIGNED_ON_SERVER ) ],
        undef,
        [],
        [],
    ],
    'UNSIGNED-AND-DS-1' => [
        1,
        q(unsigned-and-ds-1.dnssec07.xa),
        [ qw( DS07_NOT_SIGNED DS07_NOT_SIGNED_ON_SERVER ) ],
        undef,
        [],
        [],
    ],
    'UNSIGNED-NO-DS-1' => [
        1,
        q(unsigned-no-ds-1.dnssec07.xa),
        [ qw( DS07_NOT_SIGNED DS07_NOT_SIGNED_ON_SERVER ) ],
        undef,
        [],
        [],
    ],
    'NON-AUTH-RESPONSE-DNSKEY-1' => [
        1,
        q(non-auth-response-dnskey-1.dnssec07.xa),
        [ qw( DS07_NON_AUTH_RESPONSE_DNSKEY DS07_SIGNED DS07_SIGNED_ON_SERVER DS07_DS_ON_PARENT_SERVER DS07_DS_FOR_SIGNED_ZONE ) ],
        undef,
        [],
        [],
    ],
    'NO-RESPONSE-DNSKEY-1' => [
        1,
        q(no-response-dnskey-1.dnssec07.xa),
        [ qw( DS07_SIGNED DS07_SIGNED_ON_SERVER DS07_NO_RESPONSE_DNSKEY DS07_DS_ON_PARENT_SERVER DS07_DS_FOR_SIGNED_ZONE ) ],
        undef,
        [],
        [],
    ],
    'UNEXP-RCODE-RESP-DNSKEY-1' => [
        1,
        q(unexp-rcode-resp-dnskey-1.dnssec07.xa),
        [ qw( DS07_SIGNED DS07_SIGNED_ON_SERVER DS07_UNEXP_RCODE_RESP_DNSKEY DS07_DS_ON_PARENT_SERVER DS07_DS_FOR_SIGNED_ZONE ) ],
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
