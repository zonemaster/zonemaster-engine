#!perl
use v5.26.3;
use warnings;
use Test::More;

require Test::NoWarnings;
use Zonemaster::Engine;
use Zonemaster::Engine::Nameserver;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Test;
use Zonemaster::Engine::Util qw( zone );
use Test::Differences;
use Test::Exception;

my $datafile = q{t/Test.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

subtest 'Enabling single test cases in profile' => sub {
    my %all_methods = Zonemaster::Engine->all_methods;
    my @testcases =
      map { fc $_ }
      map { @{ $all_methods{$_} } } Zonemaster::Engine->modules;
    my $zone = zone( 'se' );

    my $effective_profile = Zonemaster::Engine::Profile->effective;
    $effective_profile->merge( Zonemaster::Engine::Profile->default );
    $effective_profile->set( 'net.ipv6', 0 );

    for my $testcase ( @testcases ) {
        subtest "Testcase '$testcase'" => sub {
            $effective_profile->set( 'test_cases', [$testcase] );

            my @logentries;
            lives_ok { @logentries = Zonemaster::Engine::Test->run_all_for( $zone ) }
            "Test suite does not crash when running only this test case";

            my $actual = {
                'A) started testcases' => [
                      grep { $_ ne 'unspecified' }
                      map  { fc $_->args->{testcase} }
                      grep { $_->tag eq 'TEST_CASE_START' } @logentries
                ],
                'B) ended testcases' => [
                      grep { $_ ne 'unspecified' }
                      map  { fc $_->args->{testcase} }
                      grep { $_->tag eq 'TEST_CASE_END' } @logentries
                ],
                'C) internal errors' => [
                    map  { $_->args->{msg} =~ s/\n$//r }
                    grep { $_->tag eq 'MODULE_ERROR' } @logentries
                ],
            };
            my $expected = {
                'A) started testcases' => [$testcase],
                'B) ended testcases'   => [$testcase],
                'C) internal errors'   => [],
            };
            eq_or_diff $actual, $expected, "Test suite emits expected messages from this testcase and no others";
        };
    } ## end for my $testcase ( @testcases)
};

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

Test::NoWarnings::had_no_warnings();
done_testing;
