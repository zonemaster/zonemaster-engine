package TestUtil::DSL::Compiler;

use warnings;
use strict;
use v5.24;

use Carp qw(croak confess);
use Test::More ();

=encoding utf8

=head1 NAME

TestUtil::DSL::Compiler - compiler for the language defined in TestUtil::DSL

=cut

=head1 FUNCTIONS

=head2 compile

Compiles the AST, obtained as a result of parsing an instance of the DSL, into
a coderef that executes the tests defined in that DSL.

Set C<$TestUtil::DSL::Compiler::DEBUG> to a non-zero value in order to obtain
debugging output. If running the corresponding C<.t> file in a harness, you
may need to enable verbose output in order to see it (e.g. by passing C<-v>
to C<prove>).

=cut

our $DEBUG = 0;


sub compile {
    my ($ast) = @_;

    confess unless exists $ast->{test_module};
    confess unless exists $ast->{test_case};

    my $test_module = $ast->{test_module};
    my $test_case = $ast->{test_case};

    my $test_method = sub {
        my ( $zone_name ) = @_;
        return Zonemaster::Engine->test_method(
            $test_module, $test_case, Zonemaster::Engine->zone( $zone_name ));
    };

    my $func_preamble = _compile_preamble($ast);
    my $func_set_root_hints = _compile_root_hints($ast);
    my $func_select_subtests = _compile_select_subtests($ast);
    my $subtests = _compile_scenarios($ast->{scenarios}, $test_case, $test_method);

    my $datafile = 't/' . File::Basename::basename( $0, '.t' ) . '.data';

    return sub {
        if ($DEBUG) {
            Test::More::note("Dumping AST read after parsing DSL:");
            Test::More::note(Test::More::explain($ast));
        }

        $func_preamble->();

        $func_set_root_hints->();

        my $selected_subtests = $func_select_subtests->(
            $ENV{ZONEMASTER_SELECTED_SCENARIOS},
            $ENV{ZONEMASTER_DISABLED_SCENARIOS});

        if ( not $ENV{ZONEMASTER_RECORD} ) {
            Test::More::note "Loading data file: $datafile";
            die q{Stored data file missing} if not -r $datafile;
            Zonemaster::Engine::Nameserver->restore( $datafile );
            Test::More::note "Done loading data file.";
            Zonemaster::Engine::Profile->effective->set( q{no_network} => 1 );
        }

        Zonemaster::Engine::Profile->effective->merge(
            Zonemaster::Engine::Profile->from_json( qq({ "test_cases": ["$test_case"] }) ));

        my @disabled_tests;
        my @todo_tests;
        foreach my $name (sort keys %$subtests) {
            my ( $status, $reason ) = @{$selected_subtests->{$name}};
            my $callback  = $subtests->{$name}{callback};
            my $zone_name = $subtests->{$name}{zone_name};
            my $caller    = $subtests->{$name}{caller};

            if ( $status eq 'todo' ) {
                my $orig_callback = $callback;
                $callback = sub {
                    Test::More->builder->todo_start( $reason );
                    &$orig_callback;
                    Test::More->builder->todo_end();
                };
                push @todo_tests, [ $name, $reason ];
            }
            elsif ( $status eq 'not_testable' ) {
                $callback = sub {
                    Test::More->builder->todo_skip( $reason );
                };
                push @disabled_tests, [ $name, $reason ];
            }
            elsif ( $status eq 'skip' ) {
                $callback = sub {
                    Test::More::plan( skip_all => $reason );
                };
                push @disabled_tests, [ $name, $reason ];
            }
            # Test::More->builder->no_diag(1) - called inside the callback
            my $ret = Test::More::subtest($name, $callback, $zone_name);
            Test::More->builder->no_diag(0);
            unless ( $ret ) {
                my ( $file, $line ) = @$caller;
                Test::More::diag(<<DIAG);
  Failed scenario '$name'
  at $file line $line.
DIAG
            }
        }

        Test::More::done_testing();

        if (scalar @todo_tests) {
            Test::More::diag("The following scenarios are marked as TODO:\n");
            Test::More::diag("  $_") foreach @todo_tests;
        }
        if (scalar @disabled_tests) {
            Test::More::diag("The following scenarios were not run:\n");
            Test::More::diag("  $_") foreach @disabled_tests;
        }

        if ( $ENV{ZONEMASTER_RECORD} ) {
            Test::More::note "Saving data file: $datafile";
            Zonemaster::Engine::Nameserver->save( $datafile );
            Test::More::note "Done saving data file.";
        }
    };
}

# Top-level compilation helper functions

sub _compile_preamble {
    my ($ast) = @_;

    confess unless exists $ast->{test_module};

    my $testmod = q{Zonemaster::Engine::Test::} . $ast->{test_module};

    return sub {
        Test::More::use_ok( q{Zonemaster::Engine::Nameserver} );
        Test::More::use_ok( $testmod );
    };
}

sub _compile_root_hints {
    my ($ast) = @_;

    confess unless exists $ast->{root_hints};

    return sub {
        Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
        Zonemaster::Engine::Recursor->add_fake_addresses( '.', $ast->{root_hints} );
        Zonemaster::Engine::Recursor::clear_cache();
    }
}

sub _compile_select_subtests {
    my ($ast) = @_;

    my %scenario_status;
    foreach my $block ( @{$ast->{scenarios}} ) {
        my $status = $block->{body}{status};
        foreach my $name (@{$block->{names}}) {
            $scenario_status{$name} = $status;
        }
    }

    return sub {
        my ( $selected_scenarios, $disabled_scenarios ) = @_;

        # Make a copy so this sub doesn’t clobber the variable defined just before
        my %scenario_status = ( %scenario_status );

        # Force the listed tests in $selected_scenarios to run as if their
        # status was testable.
        if ( defined $selected_scenarios ) {
            my %selected = map { $_ => 1 } split(/, */, $selected_scenarios);
            foreach my $name (keys %scenario_status) {
                $scenario_status{$name} = do {
                    if ( exists $selected{$name} ) {
                        [ 'testable' ];
                    }
                    else {
                        [ 'skip', 'not selected by environment variable'];
                    }
                };
            }
        }

        # Skip the tests explicitly listed in $disabled_scenarios
        foreach my $to_disable ( split(/, */, $disabled_scenarios // "") ) {
            $scenario_status{$to_disable} =
                [ 'skip', 'disabled by environment variable' ];
        }

        return \%scenario_status;
    };
}

sub _compile_scenarios {
    my ( $scenario_blocks, $test_case, $test_method ) = @_;

    my %compiled_scenarios = ();

    foreach my $scenario (@$scenario_blocks) {
        # The same subtest can be reused across all scenarios defined by the same block;
        # the only thing that changes is the zone name.
        my $subtest_callback = _compile_scenario_subtest( $scenario, $test_method );

        foreach my $name (@{$scenario->{names}}) {
            my $zone_name = lc _expand_template(
                $scenario->{body}{zone},
                SCENARIO => $name, TESTCASE => $test_case );

            $compiled_scenarios{$name} = {
                callback => $subtest_callback,
                zone_name => $zone_name,
                caller => $scenario->{caller},
            };
        }
    }

    return \%compiled_scenarios;
}

# Scenario compilation helper functions

sub _compile_scenario_subtest {
    my ( $scenario_declaration, $test_method ) = @_;

    my $func_add_fake_delegation = _compile_fake_ns( $scenario_declaration );
    my $func_add_fake_ds = _compile_fake_ds( $scenario_declaration );
    my @func_test_messages = _compile_test_messages( $scenario_declaration );

    return sub {
        my ( $zone_name ) = @_;
        Test::More::plan(tests => scalar @func_test_messages + 1);

        Test::More::note("Zone: $zone_name");
        $func_add_fake_delegation->($zone_name) if defined $func_add_fake_delegation;
        $func_add_fake_ds->($zone_name) if defined $func_add_fake_ds;

        my @messages = $test_method->( $zone_name );

        if ( my ( $error ) = grep { $_->tag eq 'MODULE_ERROR' } @messages ) {
            Test::More::fail("Test case executes without errors");
            Test::More::diag("Module died with the following error:\n  " . $error->args->{"msg"});
        }
        else {
            Test::More::pass("Test case executes without errors");
            $_->( @messages ) foreach ( @func_test_messages );
        }

        # At the end of a subtest, if there is at least one failure,
        # Test::More automatically generates a comment containing the location
        # of the failing test. This location is wrong, so we squelch any
        # diag() output. There is no other way than to call no_diag() here.
        Test::More->builder->no_diag(1);
    };
}

sub _compile_fake_ns {
    my ( $scenario_declaration ) = @_;

    if ( exists $scenario_declaration->{body}{fake_ns} ) {
        my $undel_ns = $scenario_declaration->{body}{fake_ns};
        return sub {
            my ( $zone_name ) = @_;
            # Use default value of "fill_in_empty_oob_glue".
            Zonemaster::Engine->add_fake_delegation(
                $zone_name => $undel_ns, fill_in_empty_oob_glue => 1 );
        }
    }
    return undef;
}

sub _compile_fake_ds {
    my ( $scenario_declaration ) = @_;

    if ( exists $scenario_declaration->{body}{fake_ds} ) {
        my @undel_ds = @{$scenario_declaration->{body}{fake_ds}};
        return sub {
            my ( $zone_name ) = @_;
            Zonemaster::Engine->add_fake_ds( $zone_name => $_ ) foreach @undel_ds;
        }
    }
    return undef;
}

sub _compile_test_messages {
    my ( $scenario_declaration ) = @_;

    return
        ( map { _compile_expect($_) } @{$scenario_declaration->{body}{expect}} ),
        ( map { _compile_forbid($_) } @{$scenario_declaration->{body}{forbid}} );
}

sub _compile_expect {
    my ( $expect ) = @_;

    my $tag = $expect->{tag};
    my $caller = $expect->{caller};

    if ( exists $expect->{code} ) {
        my $callback = $expect->{code};
        return sub {
            my @messages_of_tag = grep { $_->{tag} eq $tag } @_;
            _ok(
                $callback->( @messages_of_tag ),
                "Messages of tag '$tag' satisfy custom callback",
                $caller );
        };
    }
    elsif ( exists $expect->{args} ) {
        # This case intentionally left unimplemented for now
        ...;
    }
    else {
        return sub {
            _ok(
                scalar ( grep { $_->{tag} eq $tag } @_ ),
                "Tag '$tag' is outputted",
                $caller )
                or Test::More::diag("Tag '$tag' should have been outputted, but wasn't");
        };
    }
}

sub _compile_forbid {
    my ( $forbid ) = @_;

    my $tag    = $forbid->{tag};
    my $caller = $forbid->{caller};

    return sub {
        _ok(
            ! scalar ( grep { $_->{tag} eq $tag } @_ ),
            "Tag '$tag' is not outputted",
            $caller )
            or Test::More::diag("Tag '$tag' shouldn't have been outputted, but it was");
    };
}


# Miscellaneous utilities

sub _expand_template {
    my ($template, %variables) = @_;

    confess unless defined $template;

    my $result = $template;
    for my $k (keys %variables) {
        $result =~ s/\{$k\}/$variables{$k}/g;
    }

    return $result;
}

# A version of Test::More::ok that prints the correct location when a test fails.

sub _ok {
    my ( $ok, $test_name, $caller ) = @_;
    my ( $file, $line ) = @$caller;

    # This is the only way to squelch the automatic diagnostics that are printed
    # on the TAP output when ok() fails. The TAP output erroneously points to
    # a line in t/TestUtil/DSL/Compiler.pm when an error occurs.
    Test::More->builder->no_diag(1);
    my $ret = Test::More::ok( $ok, $test_name );
    Test::More->builder->no_diag(0);

    unless ( $ok ) {
        Test::More::diag(<<DIAG);
  Failed test '$test_name'
  at $file line $line.
DIAG
    }
    return $ret;
}


1;
