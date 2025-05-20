package TestUtil;

use 5.014002;

use strict;
use warnings;

use Test::More;
use Zonemaster::Engine;
use Exporter 'import';
use List::MoreUtils qw[ uniq ];
use Zonemaster::Engine::Validation qw( validate_ipv4 validate_ipv6 );

use Carp qw( croak );

BEGIN {
    our @EXPORT_OK = qw[ perform_testcase_testing perform_methodsv2_testing ];
    our %EXPORT_TAGS = ( all => \@EXPORT_OK );

    ## no critic (Modules::ProhibitAutomaticExportation)
    our @EXPORT = qw[ perform_testcase_testing perform_methodsv2_testing ];
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

=item perform_methodsv2_testing()

    perform_methodsv2_testing( $href_subtests, $selected_scenarios, $disabled_scenarios );

This method loads unit test data (test scenarios) and, after some data checks and if the test scenario is testable,
it runs all external L<MethodsV2|Zonemaster::Engine::Test::TestMethodsV2> methods and checks for the presence (or absence) of
specific nameservers data for each specified test scenario.

If C<$selected_scenarios> has been set in the call to a comma separated list of names (or a single name), then only those
scenarios will be run, and they will always be run even if they has been set as not testable.

If C<$disabled_scenarios> has been set in the call to the name of a scenario or to a
comma separated list of scenarios then that or those scenarios will be
temporarily disabled.

Takes a reference to a hash - the keys of which are scenario names (in all uppercase), and their corresponding values are an array of:

=over

=item *
a boolean (testable), 1 or 0

=item *
a string (zone name)

=item *
an array of strings (expected parent nameserver IPs), which could be empty, or undef

=item *
an array of strings (expected delegation nameserver expressions), which could be empty, or undef

=item *
an array of strings (expected zone nameserver expressions), which could be empty, or undef

=item *
an array of name server expressions for undelegated name servers

=back

The name server expression has the format "name-server-name/IP" or only "name-server-name". This is the same format
as the data for the --ns option in I<zonemaster-cli>.

=item perform_testcase_testing()

    perform_testcase_testing( $test_case, $test_module, $aref_alltags, $href_subtests, $selected_scenarios, $disabled_scenarios );

This method loads unit test data (test case name, test module name, array of all message tags and test scenarios) and,
after some data checks and if the test scenario is testable, it runs the specified test case and checks for the presence
(or absence) of specific message tags for each specified test scenario.

If C<$selected_scenarios> has been set in the call to a comma separated list of names of scenarios (or a single name) then only those
scenarios will be run, and they will always be run even if they have been set as not testable.

If C<$disabled_scenarios> has been set in the call to the name of a scenario or to a
comma separated list of scenarios then that or those scenarios will be
temporarily disabled.

Takes a string (test case name), a string (test module name) and a reference to a hash - the keys of which are scenario names
(in all uppercase), and their corresponding values are an array of:

=over

=item *
a boolean (testable), 1 or 0

=item *
a string (zone name)

=item *
an array of strings (mandatory message tags), which could be empty, or undef

=item *
an array of strings (forbidden message tags), which could be empty, or undef

=item *
an array of name server expressions for undelegated name servers

=item *
an array of DS expressions for "undelegated" DS

=back

If the array of mandatory message tags is C<undef>, it means that any message tag
in "alltags" not explicitly forbidden must be emitted.

If the array of forbidden message tags is C<undef>, it means that any message tag
in "alltags" not explicitly allowed must not be emitted.

Both of the above arrayrefs cannot be simultaneously C<undef>.

The arrays of mandatory message tags and forbidden message tags, respectively, can be empty, but not
both. At least one of the arrays must be non-empty.

The name server expression has the format "name-server-name/IP" or only "name-server-name". The DS expression
has the format "keytag,algorithm,type,digest". Those two expressions have the same format as the data for the
--ns and --ds options, respectively, in I<zonemaster-cli>.

=back

=head1 INTERNAL METHODS

=over

=item _check_ip_addresses()

    _check_ip_addresses( $scenario_name, @ip_addresses );

Helper method that checks if the given ip address(es) are valid.

Takes a string (scenario name) and a reference to an array of strings (IP addresses).

=item _check_ns_expressions()

    _check_ns_expressions( $scenario_name, @ns_expressions );

Helper method that checks if the given nameserver expression(s) are valid.

Takes a string (scenario name) and a reference to an array of strings (nameserver expressions).

=item _check_ds_expressions()

    _check_ds_expressions( $scenario_name, @ds_expressions );

Helper method that checks if the given delegation signer (DS) expression(s) are valid.

Takes a string (scenario name) and a reference to an array of strings (delegation signer expressions).

=back

=cut

sub _check_ip_addresses {
    my ( $scenario, $ip_addresses ) = @_;

    return if ! defined $ip_addresses;

    foreach my $ip ( @{ $ip_addresses } ) {
        croak "Scenario $scenario: IP address '$ip' is not valid"
            unless validate_ipv4( $ip ) or validate_ipv6( $ip );
    }
}
    
sub _check_ns_expressions {
    my ( $scenario, $ns_expressions ) = @_;

    return if ! defined $ns_expressions;

    foreach my $nsexp ( @{ $ns_expressions } ) {
        my ( $ns, $ip ) = split m(/), $nsexp;
        croak "Scenario $scenario: Name server name '$ns' in '$nsexp' is not valid" if $ns !~ /^[0-9A-Za-z-.]+$/;

        if ( $ip ) {
            croak "Scenario $scenario: IP address '$ip' in '$nsexp' is not valid"
                unless validate_ipv4( $ip ) or validate_ipv6( $ip );                
        }
    }
}

sub _check_ds_expressions {
    my ( $scenario, $ds_expressions ) = @_;

    return if ! defined $ds_expressions;

    foreach my $str ( @{ $ds_expressions } ) {
        my ( $tag, $algo, $type, $digest ) = split( /,/, $str );
        croak "Scenario $scenario: DS expression '$str' is not valid" if
            $tag !~ /^[0-9]+$/ or $algo !~ /^[0-9]+$/ or $type !~ /^[0-9]+$/ or $digest !~ /^[0-9a-fA-F]{4,}/;
    }
}

sub perform_methodsv2_testing {
    my ( $href_subtests, $selected_scenarios, $disabled_scenarios ) = @_;
    my %subtests = %$href_subtests;

    my @selected_scenarios = map {uc} split(/, */, $selected_scenarios) if $selected_scenarios;
    my @disabled_scenarios = map {uc} split(/, */, $disabled_scenarios) if $disabled_scenarios;
    
    my @untested_scenarios = ();

    if ( $selected_scenarios ) {
        foreach my $scen (@selected_scenarios) {
            unless ( exists $subtests{$scen} ) {
                croak "Scenario $scen does not exist";
            }
        }
    }

    for my $scenario ( sort ( keys %subtests ) ) {
        next if $selected_scenarios and not grep /^$scenario$/, @selected_scenarios;
        if ( @disabled_scenarios and grep /^$scenario$/, @disabled_scenarios ) {
            push @untested_scenarios, $scenario;
            next;
        }
        
        if ( ref( $scenario ) ne '' or $scenario ne uc($scenario) ) {
            croak "Scenario $scenario: Key must (i) not be a reference and (ii) be in all uppercase";
        }

        if ( scalar @{ $subtests{$scenario} } != 6 ) {
            croak "Scenario $scenario: Incorrect number of values. " .
                "Correct format is: { SCENARIO_NAME => [" .
                "testable " .
                "zone_name, " .
                "[ EXPECTED_PARENT_IP ], " .
                "[ EXPECTED_DEL_NS ], " .
                "[ EXPECTED_ZONE_NS ], " .
                "[ UNDELEGATED_NS ], " .
                " ] }";
        }

        my ( $testable,
             $zone_name,
             $expected_parent_ip,
             $expected_del_ns,
             $expected_zone_ns,
             $undelegated_ns,
            ) = @{ $subtests{$scenario} };

        if ( ref( $testable ) ne '' ) {
            croak "Scenario $scenario: Type of testable must not be a reference";
        }

        if ( $testable != 1 and $testable != 0 ) {
            croak "Scenario $scenario: Value of testable must be 0 or 1";
        }

        $testable = 1 if $selected_scenarios and grep /^$scenario$/, @selected_scenarios;

        if ( ref( $zone_name ) ne '' ) {
            croak "Scenario $scenario: Type of zone name must not be a reference";
        }

        if ( $zone_name !~ m(^[A-Za-z0-9/_.-]+$) ) {
            croak "Scenario $scenario: Zone name '$zone_name' is not valid";
        }

        if ( defined( $expected_parent_ip ) and ref( $expected_parent_ip ) ne 'ARRAY' ) {
            croak "Scenario $scenario: Incorrect reference type of expected parent IPs. Expected: ARRAY";
        }

        if ( defined( $expected_del_ns ) and ref( $expected_del_ns ) ne 'ARRAY' ) {
            croak "Scenario $scenario: Incorrect reference type of expected delegation name servers. Expected: ARRAY";
        }

        if ( defined( $expected_zone_ns ) and ref( $expected_zone_ns ) ne 'ARRAY' ) {
            croak "Scenario $scenario: Incorrect reference type of expected zone name servers. Expected: ARRAY";
        }

        if ( ref( $undelegated_ns ) ne 'ARRAY' ) {
            croak "Scenario $scenario: Incorrect reference type of undelegated name servers expressions. Expected: ARRAY";
        }

        _check_ip_addresses( $scenario, $expected_parent_ip );
        _check_ns_expressions( $scenario, $expected_del_ns );
        _check_ns_expressions( $scenario, $expected_zone_ns );
        _check_ns_expressions( $scenario, $undelegated_ns );

        if ( not $testable ) {
            push @untested_scenarios, $scenario;
            next;
        }

        subtest $scenario => sub {
            if ( @$undelegated_ns ) {
                my %undel_ns;
                foreach my $nsexp ( @$undelegated_ns ) {
                    my ( $ns, $ip ) = split m(/), $nsexp;
                    $undel_ns{$ns} //= [];
                    push @{ $undel_ns{$ns} }, $ip if $ip;
                }

                # Use default value of "fill_in_empty_oob_glue".
                Zonemaster::Engine->add_fake_delegation( $zone_name => \%undel_ns, fill_in_empty_oob_glue => 1 );
            }

            # Method: get_parent_ns_ips()
            my $method = 'get_parent_ns_ips';
            subtest $method => sub {
                my $res = Zonemaster::Engine::TestMethodsV2->$method( Zonemaster::Engine->zone( $zone_name ) );
                if ( defined $expected_parent_ip ) {
                    ok( defined $res, "Result is defined" ) or diag "Unexpected undefined result";
                    foreach my $expected_ip ( @{ $expected_parent_ip } ) {
                        ok( grep( /^$expected_ip$/, uniq map { $_->address->short } @{ $res } ), "Name server IP '$expected_ip' is present" )
                            or diag "Expected but missing: $expected_ip";
                    }
                    ok( scalar @{ $res } == scalar @{ $expected_parent_ip }, "Number of name server IPs in both arrays match" )
                        or diag "Number of name server IPs in both arrays does not match (found ". scalar @{ $res } . ", expected " . @{ $expected_parent_ip } . ")";
                }
                else {
                    ok( ! defined $res, "Result is undefined" ) or diag "Unexpected defined result";
                }
            };

            # Methods: get_del_ns_names_and_ips() and get_zone_ns_names_and_ips()
            my @method_names = qw( get_del_ns_names_and_ips get_zone_ns_names_and_ips );
            my @expected_all_ns = ( $expected_del_ns, $expected_zone_ns );
            foreach my $i ( 0..$#method_names ) {
                my $method = $method_names[$i];
                subtest $method => sub {
                    my $expected_res = $expected_all_ns[$i];
                    my $res = Zonemaster::Engine::TestMethodsV2->$method( Zonemaster::Engine->zone( $zone_name ) );
                    if ( defined $expected_res ) {
                        ok( defined $res, "Result is defined" ) or diag "Unexpected undefined result";
                        foreach my $expected_ns ( @{ $expected_res } ) {
                            ok( grep( /^$expected_ns$/, @{ $res } ), "Name server '$expected_ns' is present" )
                                or diag "Expected but missing: $expected_ns";
                        }
                        foreach my $ns ( @{ $res } ) {
                            ok( grep( /^$ns$/, @{ $expected_res } ), "Name server '$ns' is expected" )
                                or diag "Present but not expected: $ns";
                        }
                        ok( scalar @{ $res } == scalar @{ $expected_res }, "Number of name server in both arrays match" )
                            or diag "Number of name servers in both arrays does not match (found " . scalar @{ $res } . ", expected " . scalar @{ $expected_res }.")";
                    }
                    else {
                        ok( ! defined $res, "Result is undefined" ) or diag "Unexpected defined result";
                    }
                };
            }

            # Methods: get_del_ns_names() and get_zone_ns_names()
            @method_names = qw( get_del_ns_names get_zone_ns_names );
            my $expected_del_ns_names = defined $expected_del_ns ?
                [ uniq map { (split( m(/), $_ ))[0] } @{ $expected_del_ns } ] : undef;
            my $expected_zone_ns_names = defined $expected_zone_ns ?
                [ uniq map { (split( m(/), $_ ))[0] } @{ $expected_zone_ns } ] : undef;
            my @expected_ns_names = ( $expected_del_ns_names, $expected_zone_ns_names );
            foreach my $i ( 0..$#method_names ) {
                my $method = $method_names[$i];
                subtest $method => sub {
                    my $expected_res = $expected_ns_names[$i];
                    my $res = Zonemaster::Engine::TestMethodsV2->$method( Zonemaster::Engine->zone( $zone_name ) );
                    if ( defined $expected_res ) {
                        ok( defined $res, "Result is defined" ) or diag "Unexpected undefined result";
                        foreach my $expected_name ( @{ $expected_res } ) {
                            ok( grep( /^$expected_name$/, @{ $res } ), "Name server name '$expected_name' is present" )
                                or diag "Expected but missing: $expected_name";
                        }
                        foreach my $name ( @{ $res } ) {
                            ok( grep( /^$name$/, @{ $expected_res } ), "Name server name '$name' is expected" )
                                or diag "Present but not expected: $name";
                        }
                        ok( scalar @{ $res } == scalar @{ $expected_res }, "Number of name server names in both arrays match" )
                            or diag "Number of name server names in both arrays does not match (found " . scalar @{ $res } . ", expected " . scalar @{ $expected_res }.")";
                    }
                    else {
                        ok( ! defined $res, "Result is undefined" ) or diag "Unexpected defined result";
                    }
                };
            }

            # Methods: get_del_ns_ips() and get_zone_ns_ips()
            @method_names = qw( get_del_ns_ips get_zone_ns_ips );
            my $expected_del_ns_ips = defined $expected_del_ns ?
                [ uniq grep { $_ ne '' } map { (split( m(/), $_ ))[1] ? (split( m(/), $_ ))[1] : '' } @{ $expected_del_ns } ] : undef;
            my $expected_zone_ns_ips = defined $expected_zone_ns ?
                [ uniq grep { $_ ne '' } map { (split( m(/), $_ ))[1] ? (split( m(/), $_ ))[1] : '' } @{ $expected_zone_ns } ] : undef;

            my @expected_ns_ips = ( $expected_del_ns_ips, $expected_zone_ns_ips ); 
            foreach my $i ( 0..$#method_names ) {
                my $method = $method_names[$i];
                subtest $method => sub {
                    my $expected_res = $expected_ns_ips[$i];
                    my $res = Zonemaster::Engine::TestMethodsV2->$method( Zonemaster::Engine->zone( $zone_name ) );
                    if ( defined $expected_res ) {
                        ok( defined $res, "Result is defined" ) or diag "Unexpected undefined result";
                        foreach my $expected_ip ( @{ $expected_res } ) {
                            ok( grep( /^$expected_ip$/, @{ $res } ), "Name server IP '$expected_ip' is present" )
                                or diag "Expected but missing: $expected_ip";
                        }
                        foreach my $ip ( @{ $res } ) {
                            ok( grep( /^$ip$/, @{ $expected_res } ), "Name server IP '$ip' is expected" )
                                or diag "Present but not expected: $ip";
                        }
                        ok( scalar @{ $res } == scalar @{ $expected_res }, "Number of name server IPs in both arrays match" )
                            or diag "Number of name server IPs in both arrays does not match (found " . scalar @{ $res } . ", expected " . scalar @{ $expected_res }.")";
                    }
                    else {
                        ok( ! defined $res, "Result is undefined" ) or diag "Unexpected defined result";
                    }
                };
            }
        }
    }

    if ( @untested_scenarios ) {
        warn "Untested scenarios:\n";
        warn "\tScenario $_ has been disabled from testing.\n" for @untested_scenarios;
    }
}


sub perform_testcase_testing {
    my ( $test_case, $test_module, $aref_alltags, $href_subtests, $selected_scenarios, $disabled_scenarios ) = @_;
    my %subtests = %$href_subtests;

    my @selected_scenarios = map {uc} split(/, */, $selected_scenarios) if $selected_scenarios;
    my @disabled_scenarios = map {uc} split(/, */, $disabled_scenarios) if $disabled_scenarios;

    my @untested_scenarios = ();

    if ( $selected_scenarios ) {
        foreach my $scen (@selected_scenarios) {
            unless ( exists $subtests{$scen} ) {
                croak "Scenario $scen does not exist";
            }
        }
    }

    if ( ref( $aref_alltags ) ne 'ARRAY' ) {
        croak 'All tags array variable must be an array ref'
    }

    foreach my $t ( @$aref_alltags ) {
        croak "Invalid tag in 'all tags': '$t'" unless $t =~ /^[A-Z]+[A-Z0-9_]*[A-Z0-9]$/;
    }

    for my $scenario ( sort ( keys %subtests ) ) {
        next if $selected_scenarios and not grep /^$scenario$/,  @selected_scenarios;
        if ( @disabled_scenarios and grep /^$scenario$/, @disabled_scenarios ) {
            push @untested_scenarios, $scenario;
            next;
        }

        if ( ref( $scenario ) ne '' or $scenario ne uc($scenario) ) {
            croak "Scenario $scenario: Key must (i) not be a reference and (ii) be in all uppercase";
        }

        if ( scalar @{ $subtests{$scenario} } != 6 ) {
            croak "Scenario $scenario: Incorrect number of values. " .
                "Correct format is: { SCENARIO_NAME => [" .
                "testable " .
                "zone_name, " .
                "[ MANDATORY_MESSAGE_TAGS ], " .
                "[ FORBIDDEN_MESSAGE_TAGS ], " .
                "[ UNDELEGATED_NS ], " .
                "[ UNDELEGATED_DS ], " .
                " ] }";
        }

        my ( $testable,
             $zone_name,
             $mandatory_message_tags,
             $forbidden_message_tags,
             $undelegated_ns,
             $undelegated_ds
            ) = @{ $subtests{$scenario} };

        if ( ref( $testable ) ne '' ) {
            croak "Scenario $scenario: Type of testable must not be a reference";
        }

        if ( $testable != 1 and $testable != 0 ) {
            croak "Scenario $scenario: Value of testable must be 0 or 1";
        }

        $testable = 1 if $selected_scenarios and grep /^$scenario$/, @selected_scenarios;

        if ( ref( $zone_name ) ne '' ) {
            croak "Scenario $scenario: Type of zone name must not be a reference";
        }

        if ( $zone_name !~ m(^[A-Za-z0-9/_.-]+$) ) {
            croak "Scenario $scenario: Zone name '$zone_name' is not valid";
        }

        if ( ! defined( $mandatory_message_tags ) and ! defined( $forbidden_message_tags ) ) {
            croak "Scenario $scenario: Not both array of mandatory tags and array of forbidden tags can be undefined";
        }

        if ( defined( $mandatory_message_tags ) and defined( $forbidden_message_tags ) and
             not scalar @{ $mandatory_message_tags } and not scalar @{ $forbidden_message_tags } ) {
            croak "Scenario $scenario: Not both arrays of mandatory message tags and forbidden message tags, respectively, can be empty";
        }

        if ( defined( $mandatory_message_tags ) and ref( $mandatory_message_tags ) ne 'ARRAY' ) {
            croak "Scenario $scenario: Incorrect reference type of mandatory message tags. Expected: ARRAY";
        }

        if ( defined( $forbidden_message_tags ) and ref( $forbidden_message_tags ) ne 'ARRAY' ) {
            croak "Scenario $scenario: Incorrect reference type of forbidden message tags. Expected: ARRAY";
        }

        if ( ! defined( $mandatory_message_tags ) ) {
            my @tags;
            foreach my $t ( @$aref_alltags ) {
                push @tags, $t unless grep( /^$t$/, @$forbidden_message_tags );
            }
            $mandatory_message_tags = \@tags;
        }

        if ( ! defined( $forbidden_message_tags ) ) {
            my @tags;
            foreach my $t ( @$aref_alltags ) {
                push @tags, $t unless grep( /^$t$/, @$mandatory_message_tags );
            }
            $forbidden_message_tags = \@tags;
        }

        foreach my $tag ( @$mandatory_message_tags ) {
            croak "Scenario $scenario: Invalid message tag in 'mandatory_message_tags': '$tag'" unless $tag =~ /^[A-Z]+[A-Z0-9_]*[A-Z0-9]$/;
        }

        foreach my $tag ( @$mandatory_message_tags ) {
            unless ( grep( /^$tag$/, @$aref_alltags ) ) {
                croak "Scenario $scenario: Message tag '$tag' in 'mandatory_message_tags' is missing in 'all_tags'";
            }
        }

        foreach my $tag ( @$forbidden_message_tags ) {
            croak "Scenario $scenario: Invalid message tag in 'forbidden_message_tags': '$tag'" unless $tag =~ /^[A-Z]+[A-Z0-9_]*[A-Z0-9]$/;
        }

        foreach my $tag ( @$forbidden_message_tags ) {
            unless ( grep( /^$tag$/, @$aref_alltags ) ) {
                croak "Scenario $scenario: Message tag '$tag' in 'forbidden_message_tags' is missing in 'all_tags'";
            }
        }

        if ( ref( $undelegated_ns ) ne 'ARRAY' ) {
            croak "Scenario $scenario: Incorrect reference type of undelegated name servers expressions. Expected: ARRAY";
        }

        if ( ref( $undelegated_ds ) ne 'ARRAY' ) {
            croak "Scenario $scenario: Incorrect reference type of undelegated DS expressions. Expected: ARRAY";
        }

        _check_ns_expressions( $scenario, $undelegated_ns );
        _check_ds_expressions( $scenario, $undelegated_ds );

        if ( not $testable ) {
            push @untested_scenarios, $scenario;
            next;
        }

        subtest $scenario => sub {

            if ( @$undelegated_ns ) {
                my %undel_ns;
                foreach my $nsexp ( @$undelegated_ns ) {
                    my ($ns, $ip) = split m(/), $nsexp;
                    $undel_ns{$ns} //= [];
                    push @{ $undel_ns{$ns} }, $ip if $ip;
                }

                # Use default value of "fill_in_empty_oob_glue".
                Zonemaster::Engine->add_fake_delegation( $zone_name => \%undel_ns, fill_in_empty_oob_glue => 1 );
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
