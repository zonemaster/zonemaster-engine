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

# Root hints
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.', {'ibdns.root-servers.net' => ['10.1.72.23']} );

# Test zone scenarios
# - Documentation: L<TestUtil/perform_testcase_testing()>
# - Format: { SCENARIO_NAME => [ zone_name, [ MANDATORY_MESSAGE_TAGS ], [ FORBIDDEN_MESSAGE_TAGS ], testable ] }
my %subtests = (
    'NO-TXT' => [
        q(no-txt.zone11.xa),
        [ qw(Z11_NO_SPF_FOUND) ],
        [ qw(Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_SPF1_SYNTAX_OK Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'NO-SPF-TXT' => [
        q(no-spf-txt.zone11.xa),
        [ qw(Z11_NO_SPF_FOUND) ],
        [ qw(Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_SPF1_SYNTAX_OK Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'NON-AUTH-TXT' => [
        q(non-auth-txt.zone11.xa),
        [ qw(Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_SYNTAX_ERROR Z11_SPF1_SYNTAX_OK Z11_SPF1_TOO_COMPLEX) ],
        1
    ],
    'NONEXISTENT' => [
        q(nonexistent.zone11.xa),
        [ qw(Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_SYNTAX_ERROR Z11_SPF1_SYNTAX_OK Z11_SPF1_TOO_COMPLEX) ],
        1
    ],
    'INCONSISTENT-SPF' => [
        q(inconsistent-spf.zone11.xa),
        [ qw(Z11_INCONSISTENT_SPF_POLICIES Z11_DIFFERENT_SPF_POLICIES_FOUND) ],
        [ qw(Z11_NO_SPF_FOUND Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_SPF1_SYNTAX_OK Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'SPF-MISSING-ON-ONE' => [
        q(spf-missing-on-one.zone11.xa),
        [ qw(Z11_INCONSISTENT_SPF_POLICIES Z11_DIFFERENT_SPF_POLICIES_FOUND) ],
        [ qw(Z11_NO_SPF_FOUND Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_SPF1_SYNTAX_OK Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'ALL-DIFFERENT-SPF' => [
        q(all-different-spf.zone11.xa),
        [ qw(Z11_INCONSISTENT_SPF_POLICIES Z11_DIFFERENT_SPF_POLICIES_FOUND) ],
        [ qw(Z11_NO_SPF_FOUND Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_SPF1_SYNTAX_OK Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'MULTIPLE-SPF-RECORDS' => [
        q(multiple-spf-records.zone11.xa),
        [ qw(Z11_SPF1_MULTIPLE_RECORDS) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_SYNTAX_ERROR Z11_SPF1_SYNTAX_OK Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'INVALID-SYNTAX' => [
        q(invalid-syntax.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_ERROR) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_OK Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'RANDOM-BYTES' => [
        q(random-bytes.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_ERROR) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_OK Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'TWO-REDIRECTS' => [
        q(two-redirects.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_ERROR) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_OK Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'TWO-EXPS' => [
        q(two-exps.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_ERROR) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_OK Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'TRIVIAL-SPF' => [
        q(trivial-spf.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'VALID-SPF' => [
        q(valid-spf.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'REDIRECT-NON-FINAL' => [
        q(redirect-non-final.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'REDIRECT-AND-ALL' => [
        q(redirect-and-all.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'CONTAINS-PTR' => [
        q(contains-ptr.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'CONTAINS-P-MACRO' => [
        q(contains-p-macro.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'CONTAINS-PR-MACRO' => [
        q(contains-pr-macro.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'TOO-COMPLEX' => [
        q(too-complex.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'CONTAINS-INCLUDE' => [
        q(contains-include.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
    ],
    'CONTAINS-REDIRECT' => [
        q(contains-redirect.zone11.xa),
        [ qw(Z11_SPF1_SYNTAX_OK) ],
        [ qw(Z11_NO_SPF_FOUND Z11_INCONSISTENT_SPF_POLICIES Z11_SPF1_MULTIPLE_RECORDS Z11_SPF1_SYNTAX_ERROR Z11_UNABLE_TO_CHECK_FOR_SPF) ],
        1
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

perform_testcase_testing( $test_case, $test_module, %subtests );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
