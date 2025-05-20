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

my $test_module = q{ZONE};
my $test_case = 'zone11';
my @all_tags = qw(Z11_INCONSISTENT_SPF_POLICIES
                  Z11_DIFFERENT_SPF_POLICIES_FOUND
                  Z11_NO_SPF_FOUND
                  Z11_SPF1_MULTIPLE_RECORDS
                  Z11_SPF1_SYNTAX_ERROR
                  Z11_SPF1_SYNTAX_OK
                  Z11_UNABLE_TO_CHECK_FOR_SPF);

# Root hints
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.', {'ibdns.root-servers.net' => ['10.1.72.23']} );

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
    'NO-TXT' => [
        1,
        q(no-txt.zone11.xa),
        [ qw(Z11_NO_SPF_FOUND) ],
        undef,
        [],
        []
    ],
    'NO-SPF-TXT' => [
        1,
        q(no-spf-txt.zone11.xa),
        [ qw(Z11_NO_SPF_FOUND) ],
        undef,
        [],
        []
    ],
    'NON-AUTH-TXT' => [
        1,
        q(non-auth-txt.zone11.xa),
        [ qw(Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        undef,
        [],
        []
    ],
    'NONEXISTENT' => [
        1,
        q(nonexistent.zone11.xa),
        [ qw(Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        undef,
        [],
        []
    ],
    'INCONSISTENT-SPF' => [
        1,
        q(inconsistent-spf.zone11.xa),
        [ qw(Z11_INCONSISTENT_SPF_POLICIES Z11_DIFFERENT_SPF_POLICIES_FOUND) ],
        undef,
        [],
        []
    ],
    'SPF-MISSING-ON-ONE' => [
        1,
        q(spf-missing-on-one.zone11.xa),
        [ qw(Z11_INCONSISTENT_SPF_POLICIES Z11_DIFFERENT_SPF_POLICIES_FOUND) ],
        undef,
        [],
        []
    ],
    'ALL-DIFFERENT-SPF' => [
        1,
        q(all-different-spf.zone11.xa),
        [ qw(Z11_INCONSISTENT_SPF_POLICIES Z11_DIFFERENT_SPF_POLICIES_FOUND) ],
        undef,
        [],
        []
    ],
    'MULTIPLE-SPF-RECORDS' => [
        1,
        q(multiple-spf-records.zone11.xa),
        [ qw(Z11_SPF1_MULTIPLE_RECORDS) ],
        undef,
        [],
        []
    ],
    'INVALID-SYNTAX' => [
        1,
        q(invalid-syntax.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_ERROR) ],
        undef,
        [],
        []
    ],
    'RANDOM-BYTES' => [
        1,
        q(random-bytes.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_ERROR) ],
        undef,
        [],
        []
    ],
    'TWO-REDIRECTS' => [
        1,
        q(two-redirects.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_ERROR) ],
        undef,
        [],
        []
    ],
    'TWO-EXPS' => [
        1,
        q(two-exps.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_ERROR) ],
        undef,
        [],
        []
    ],
    'TRIVIAL-SPF' => [
        1,
        q(trivial-spf.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        undef,
        [],
        []
    ],
    'VALID-SPF' => [
        1,
        q(valid-spf.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        undef,
        [],
        []
    ],
    'REDIRECT-NON-FINAL' => [
        1,
        q(redirect-non-final.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        undef,
        [],
        []
    ],
    'REDIRECT-AND-ALL' => [
        1,
        q(redirect-and-all.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        undef,
        [],
        []
    ],
    'CONTAINS-PTR' => [
        1,
        q(contains-ptr.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        undef,
        [],
        []
    ],
    'CONTAINS-P-MACRO' => [
        1,
        q(contains-p-macro.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        undef,
        [],
        []
    ],
    'CONTAINS-PR-MACRO' => [
        1,
        q(contains-pr-macro.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        undef,
        [],
        []
    ],
    'TOO-COMPLEX' => [
        1,
        q(too-complex.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        undef,
        [],
        []
    ],
    'CONTAINS-INCLUDE' => [
        1,
        q(contains-include.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        undef,
        [],
        []
    ],
    'CONTAINS-REDIRECT' => [
        1,
        q(contains-redirect.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        undef,
        [],
        []
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
