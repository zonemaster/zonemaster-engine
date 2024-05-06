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
(in all uppercase), and their corresponding values are an array of:

=over

=item *
a boolean (testable), 1 or 0

=item *
a string (zone name)

=item *
an array of strings (all test case message tags)

=item *
an array of strings (mandatory message tags)

=item *
an array of strings (forbidden message tags)

=item *
an array of name server expressions for undelegated name servers

=item *
an array of DS expressions for "undelegated" DS

=back

The array of mandatory message tags or the array of forbidden message tags, but not both, could be
undefined. If the mandatory message tag array is undefined, then it will be generated to contain
all message tags not included in the forbidden message tag array. The same mechanism is used if the
forbidden message tag array is undefined.

The name server expression has the format "name-server-name/IP" or only "name-server-name". The DS expression
has the format "keytag,algorithm,type,digest". Those two expressions have the same format as the data for
--ns and --ds options, repectively, for I<zonemaster-cli>.

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

        if ( scalar @{ $subtests{$scenario} } != 7 ) {
            diag("Scenario $scenario: Incorrect number of values. " .
                 "Correct format is: { SCENARIO_NAME => [" .
                 "testable " .
                 "zone_name, " .
                 "[ ALL_TEST_CASE_TAGS ], " .
                 "[ MANDATORY_MESSAGE_TAGS ], " .
                 "[ FORBIDDEN_MESSAGE_TAGS ], " .
                 "[ UNDELEGATED_NS ], " .
                 "[ UNDELEGATED_DS ], " .
                 " ] }"
            );
            fail("Hash contains valid values");
            next;
        }

        my ( $testable,
             $zone_name,
             $all_test_case_tags,
             $mandatory_message_tags,
             $forbidden_message_tags,
             $undelegated_ns,
             $undelegated_ds
            ) = @{ $subtests{$scenario} };

        if ( ref( $testable ) ne '' ) {
            diag("Scenario $scenario: Type of testable must not be a reference");
            fail("Testable is of the correct type");
            next;
        }

        if ( ref( $zone_name ) ne '' ) {
            diag("Scenario $scenario: Type of zone name must not be a reference");
            fail("Zone name is of the correct type");
            next;
        }

        if ( ref( $all_test_case_tags ) ne 'ARRAY' ) {
            diag("Scenario $scenario: Incorrect reference type of all test case tags. Expected: ARRAY");
            fail("Mandatory message tags are of the correct type");
            next;
        }

        if ( ! defined( $mandatory_message_tags ) and !defined( $forbidden_message_tags ) ) {
            diag("Scenario $scenario: Not both array of mandatory tags and array of forbidden tags can be undefined");
            fail("Mandatory message tags or forbidden message tags or both are defined");
            next;
        }

        if ( defined( $mandatory_message_tags ) and ref( $mandatory_message_tags ) ne 'ARRAY' ) {
            diag("Scenario $scenario: Incorrect reference type of mandatory message tags. Expected: ARRAY");
            fail("Mandatory message tags are of the correct type");
            next;
        }

        if ( defined( $forbidden_message_tags ) and ref( $forbidden_message_tags ) ne 'ARRAY' ) {
            diag("Scenario $scenario: Incorrect reference type of forbidden message tags. Expected: ARRAY");
            fail("Forbidden message tags are of the correct type");
            next;
        }

        foreach my $tag ( @$mandatory_message_tags ) {
            unless ( grep( /^$tag$/, @$all_test_case_tags ) ) {
                diag("Scenario $scenario: Message tag $tag i 'mandatory message tags' is missing in 'all tags'");
                fail("List of all test case tags is complete");
            }
        }

        foreach my $tag ( @$forbidden_message_tags ) {
            unless ( grep( /^$tag$/, @$all_test_case_tags ) ) {
                diag("Scenario $scenario: Message tag $tag i 'forbidden message tags' is missing in 'all tags'");
                fail("List of all test case tags is complete");
            }
        }

        if ( ! defined( $mandatory_message_tags ) ) {
            my @tags;
            foreach my $t ( @$all_test_case_tags ) {
                push @tags, $t unless grep( /^$t$/, @$forbidden_message_tags );
            }
            $mandatory_message_tags = \@tags;
        }

        if ( ! defined( $forbidden_message_tags ) ) {
            my @tags;
            foreach my $t ( @$all_test_case_tags ) {
                push @tags, $t unless grep( /^$t$/, @$mandatory_message_tags );
            }
            $forbidden_message_tags = \@tags;
        }

        if ( ref( $undelegated_ns ) ne 'ARRAY' ) {
            diag("Scenario $scenario: Incorrect reference type of undelegated name servers expressions. Expected: ARRAY");
            fail("Undelegated name server expressions are of the correct type");
            next;
        }

        if ( ref( $undelegated_ds ) ne 'ARRAY' ) {
            diag("Scenario $scenario: Incorrect reference type of undelegated name servers expressions. Expected: ARRAY");
            fail("Undelegated name server expressions are of the correct type");
            next;
        }

        if ( not $testable ) {
            push @untested_scenarios, $scenario;
            next;
        }

        subtest $scenario => sub {

            if ( @$undelegated_ns ) {
                my %hash;
                foreach my $nsexp ( @$undelegated_ns ) {
                    my ($ns, $ip) = split m(/), $nsexp;
                    $hash{$ns} //= [];
                    push @{ $hash{$ns} }, $ip if $ip;
                }
                Zonemaster::Engine::Recursor->remove_fake_addresses( $zone_name );
                Zonemaster::Engine::Recursor->add_fake_addresses( $zone_name, \%hash );
            }

            if ( @$undelegated_ds ) {
                my @data;
                foreach my $str ( @$undelegated_ds ) {
                    my ( $tag, $algo, $type, $digest ) = split( /,/, $str );
                    push @data, { keytag => $tag, algorithm => $algo, type => $type, digest => $digest };
                }
                Zonemaster::Engine->add_fake_ds( $zone_name => \@data );
            }

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
