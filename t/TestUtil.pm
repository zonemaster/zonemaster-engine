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

This method loads unit test data (test case name, test module name and test scenarios), runs the specified test case, and checks for the presence
(or absence) of specific message tags for each specified test scenario.

Takes a string (test case name), a string (test module name) and a hash - the keys of which are: C<zone>, C<mandatory>, C<forbidden>, C<testable>,
and their corresponding values are a string (zone name), an array of strings (message tags), an array of strings (message tags) and a boolean.

=back

=cut

sub perform_testcase_testing {
    my ( $test_case, $test_module, %subtests ) = @_;

    my @mandatory_keys = ( 'zone', 'mandatory', 'forbidden', 'testable' );
    my @untested_scenarios = ();

    for my $scenario ( sort ( keys %subtests ) ) {
        for my $key ( @mandatory_keys ) {
            unless ( exists $subtests{$scenario}{$key} ) {
                diag("Key '$key' is missing in hash");
                fail("Subtests hash contains all mandatory keys");
                return;
            }
        }

        if ( not $subtests{$scenario}{testable} ) {
            push @untested_scenarios, $scenario;
            next;
        }

        subtest $scenario => sub {
            my @messages = Zonemaster::Engine->test_method( $test_module, $test_case, Zonemaster::Engine->zone( $subtests{$scenario}{zone} ) );
            my %res = map { $_->tag => 1 } @messages;

            if ( my ( $error ) = grep { $_->tag eq 'MODULE_ERROR' } @messages ) {
                diag("Module died with error: " . $error->args->{"msg"});
                fail("Test case executes properly");
            }
            else {
                for my $tag ( @{$subtests{$scenario}{mandatory}} ) {
                    ok( exists $res{$tag}, "Tag $tag is outputted" )
                        or diag "Tag '$tag' should have been outputted, but wasn't";
                }
                for my $tag ( @{$subtests{$scenario}{forbidden}} ) {
                    ok( !exists $res{$tag}, "Tag $tag is not outputted" )
                        or diag "Tag '$tag' was not supposed to be outputted, but it was";
                }

                # Call function callback for extra tests if such a function is defined
                if ( exists $subtests{$scenario}{extra} ) {
                    $subtests{$scenario}{extra}->(\@messages);
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
