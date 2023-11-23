package TestUtil;

use 5.014002;

use strict;
use warnings;

use Test::More;
use Zonemaster::Engine;
use Exporter 'import';

BEGIN {
    our @EXPORT_OK = qw[ perform_testcase_testing ];
    our %EXPORT_TAGS = ( all => \@EXPORT_OK );

    ## no critic (Modules::ProhibitAutomaticExportation)
    our @EXPORT = qw[ perform_testcase_testing ];
}

=head1 NAME

TestUtil - a set of methods to ease Zonemaster::Engine unit testing

=head1 SYNOPSIS

Because this package lies in the testing folder C<t/> and that folder is
unknown to the include path @INC, it can be including using the following code:

    use File::Basename qw( dirname );
    use File::Spec::Functions qw( rel2abs );
    use lib dirname( rel2abs( $0 ) );
    use TestUtil;

=head1 METHODS

=over

=item perform_testcase_testing()

    perform_testcase_testing( $test_case, $test_module, %subtests );

This method loads unit test data (test case name, test module name and test scenarios) and, after some data checks
and if the test scenario is testable, it runs the specified test case and checks for the presence (or absence) of
specific message tags for each specified test scenario.

Takes a string (test case name), a string (test module name) and a hash - the keys of which are scenario names
(in all uppercase), and their corresponding values are an array of: a string (zone name), an array of strings
(mandatory message tags), an array of strings (forbidden message tags) and a boolean (testable).

=back

=cut

sub perform_testcase_testing {
    my ( $test_case, $test_module, %subtests ) = @_;

    my @untested_scenarios = ();

    for my $scenario ( sort ( keys %subtests ) ) {
        if ( ref( $scenario ) ne '' or $scenario ne uc($scenario) ) {
            diag("Scenario $scenario: Key must (i) not be a reference and (ii) be in all uppercase");
            fail("Hash contains valid keys");
            next;
        }

        if ( scalar @{ $subtests{$scenario} } != 4 ) {
            diag("Scenario $scenario: Incorrect number of values. " .
                 "Correct format is: { SCENARIO_NAME => [ zone_name, [ MANDATORY_MESSAGE_TAGS ], [ FORBIDDEN_MESSAGE_TAGS ], testable ] }"
            );
            fail("Hash contains valid values");
            next;
        }

        my ( $zone_name, $mandatory_message_tags, $forbidden_message_tags, $testable ) = @{ $subtests{$scenario} };

        if ( ref( $zone_name ) ne '' ) {
            diag("Scenario $scenario: Type of zone name must not be a reference");
            fail("Zone name is of the correct type");
            next;
        }

        if ( ref( $mandatory_message_tags ) ne 'ARRAY' ) {
            diag("Scenario $scenario: Incorrect reference type of mandatory message tags. Expected: ARRAY");
            fail("Mandatory message tags are of the correct type");
            next;
        }

        if ( ref( $forbidden_message_tags ) ne 'ARRAY' ) {
            diag("Scenario $scenario: Incorrect reference type of forbidden message tags. Expected: ARRAY");
            fail("Forbidden message tags are of the correct type");
            next;
        }

        if ( ref( $testable ) ne '' ) {
            diag("Scenario $scenario: Type of testable must not be a reference");
            fail("Testable is of the correct type");
            next;
        }

        if ( not $testable ) {
            push @untested_scenarios, $scenario;
            next;
        }

        subtest $scenario => sub {
            my @messages = Zonemaster::Engine->test_method( $test_module, $test_case, Zonemaster::Engine->zone( $zone_name ) );
            my %res = map { $_->tag => 1 } @messages;

            if ( my ( $error ) = grep { $_->tag eq 'MODULE_ERROR' } @messages ) {
                diag("Module died with error: " . $error->args->{"msg"});
                fail("Test case executes properly");
            }
            else {
                for my $tag ( @{ $mandatory_message_tags } ) {
                    ok( exists $res{$tag}, "Tag $tag is outputted" )
                        or diag "Tag '$tag' should have been outputted, but wasn't";
                }
                for my $tag ( @{ $forbidden_message_tags } ) {
                    ok( !exists $res{$tag}, "Tag $tag is not outputted" )
                        or diag "Tag '$tag' was not supposed to be outputted, but it was";
                }
            }
        };
    }

    if ( @untested_scenarios ) {
        warn "Untested scenarios:\n";
        warn "\tScenario $_ cannot be tested.\n" for @untested_scenarios;
    }
}

1;
