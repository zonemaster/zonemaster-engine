package Zonemaster::Engine::Test::Consistency;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.1.16");

use List::MoreUtils qw[uniq];
use Locale::TextDomain qw[Zonemaster-Engine];
use Net::IP::XS;
use Readonly;

use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Constants qw[:ip :soa];
use Zonemaster::Engine::NameserverSet;
use Zonemaster::Engine::Test::Address;
use Zonemaster::Engine::Util;
use Zonemaster::Engine::TestMethods;

=head1 NAME

Zonemaster::Engine::Test::Consistency - Module implementing tests focused on name servers responses consistency

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Consistency->all( $zone );

=head1 METHODS

=over

=item all()

    my @logentry_array = all( $zone );

Runs the default set of tests for that module, i.e. L<six tests|/TESTS>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    if ( Zonemaster::Engine::Util::should_run_test( q{consistency01} ) ) {
        push @results, $class->consistency01( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{consistency02} ) ) {
        push @results, $class->consistency02( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{consistency03} ) ) {
        push @results, $class->consistency03( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{consistency04} ) ) {
        push @results, $class->consistency04( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{consistency05} ) ) {
        push @results, $class->consistency05( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{consistency06} ) ) {
        push @results, $class->consistency06( $zone );
    }

    return @results;
}

=over

=item metadata()

    my $hash_ref = metadata();

Returns a reference to a hash, the keys of which are the names of all Test Cases in the module, and the corresponding values are references to
an array containing all the message tags that the Test Case can use in L<log entries|Zonemaster::Engine::Logger::Entry>.

=back

=cut

sub metadata {
    my ( $class ) = @_;

    return {
        consistency01 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_SOA_QUERY
              ONE_SOA_SERIAL
              MULTIPLE_SOA_SERIALS
              SOA_SERIAL
              SOA_SERIAL_VARIATION
              IPV4_DISABLED
              IPV6_DISABLED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        consistency02 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_SOA_QUERY
              ONE_SOA_RNAME
              MULTIPLE_SOA_RNAMES
              SOA_RNAME
              IPV4_DISABLED
              IPV6_DISABLED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        consistency03 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_SOA_QUERY
              ONE_SOA_TIME_PARAMETER_SET
              MULTIPLE_SOA_TIME_PARAMETER_SET
              SOA_TIME_PARAMETER_SET
              IPV4_DISABLED
              IPV6_DISABLED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        consistency04 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_NS_QUERY
              ONE_NS_SET
              MULTIPLE_NS_SET
              NS_SET
              IPV4_DISABLED
              IPV6_DISABLED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        consistency05 => [
            qw(
              CS05_CHILD_ZONE_LAME
              CS05_DELEGATION
              CS05_EXTRA_ADDR_CHILD
              CS05_ID_ADDR_MISMATCH
              CS05_ID_ADDR_MISSING
              CS05_INCONSISTENT_DELEGATION
              CS05_MISSING_GLUE_FOR_NS
              CS05_MISSING_GLUE_FOR_NS_UNDEL
              CS05_MISSING_GLUE_FOR_ROOT_NS
              CS05_NO_MISMATCH_GLUE_ZONE
              CS05_NO_NS_ADDR_CHILD
              CS05_OOD_ADDR_MISMATCH
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        consistency06 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_SOA_QUERY
              ONE_SOA_MNAME
              MULTIPLE_SOA_MNAMES
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    CONSISTENCY01 => sub {
        __x    # CONSISTENCY:CONSISTENCY01
          'SOA serial number consistency';
    },
    CONSISTENCY02 => sub {
        __x    # CONSISTENCY:CONSISTENCY02
          'SOA RNAME consistency';
    },
    CONSISTENCY03 => sub {
        __x    # CONSISTENCY:CONSISTENCY03
          'SOA timers consistency';
    },
    CONSISTENCY04 => sub {
        __x    # CONSISTENCY:CONSISTENCY04
          'Name server NS consistency';
    },
    CONSISTENCY05 => sub {
        __x    # CONSISTENCY:CONSISTENCY05
          'Consistency between delegation and zone data';
    },
    CONSISTENCY06 => sub {
        __x    # CONSISTENCY:CONSISTENCY06
          'SOA MNAME consistency';
    },
    CS05_CHILD_ZONE_LAME => sub {
        __x    # CONSISTENCY:CS05_CHILD_ZONE_LAME
          'There is no working name server for the child zone. Tested name servers are "{ns_list}".', @_;
    },
    CS05_DELEGATION => sub {
        __x    # CONSISTENCY:CS05_DELEGATION
          'Delegation of the child zone as provided by the parent name servers listed: "{ns_deleg_list}". Parent name servers: "{ns_list}".', @_;
    },
    CS05_EXTRA_ADDR_CHILD => sub {
        __x    # CONSISTENCY:CS05_EXTRA_ADDR_CHILD
          'There is one or more extra address records found in the child zone that are not present as glue in the delegation: "{ns_list}".', @_;
    },
    CS05_NO_MISMATCH_GLUE_ZONE => sub {
        __     # CONSISTENCY:CS05_NO_MISMATCH_GLUE_ZONE
          'There is no mismatch between delegation from parent and authoritative data in the child zone.';
    },
    CS05_ID_ADDR_MISMATCH => sub {
        __x    # CONSISTENCY:CS05_ID_ADDR_MISMATCH
          'For name server {nsname} the glue record in the delegation "{ns_ip_list_glue}" is different from the address record in the child zone "{ns_ip_list_zone}".', @_;
    },
    CS05_ID_ADDR_MISSING => sub {
        __x    # CONSISTENCY:CS05_ID_ADDR_MISSING
          'Address record for {nsname}, used as glue record in delegation, is missing in the child zone.', @_;
    },
    CS05_INCONSISTENT_DELEGATION => sub {
        __     # CONSISTENCY:CS05_INCONSISTENT_DELEGATION
          'The delegation is inconsistent between the parent nameservers.';
    },
    CS05_MISSING_GLUE_FOR_NS => sub {
        __x    # CONSISTENCY:CS05_MISSING_GLUE_FOR_NS
          'Expected glue record for {nsname} is missing in the delegation. Found in the parent name servers "{ns_list}".', @_;
    },
    CS05_MISSING_GLUE_FOR_NS_UNDEL => sub {
        __x    # CONSISTENCY:CS05_MISSING_GLUE_FOR_NS_UNDEL
          'IP address (glue record) is expected but missing for {nsname} in the undelegated data.', @_;
    },
    CS05_MISSING_GLUE_FOR_ROOT_NS => sub {
        __x    # CONSISTENCY:CS05_MISSING_GLUE_FOR_ROOT_NS
          'IP address (glue record) is expected but missing for {nsname} in the undelegated data or hint data for root.', @_;
    },
    CS05_NO_NS_ADDR_CHILD => sub {
        __     # CONSISTENCY:CS05_NO_NS_ADDR_CHILD
          'Child zone cannot be tested since there are no name server IP addresses for that zone.';
    },
    CS05_OOD_ADDR_MISMATCH => sub {
        __x    # CONSISTENCY:CS05_OOD_ADDR_MISMATCH
          'For name server {nsname} the glue record in the delegation "{ns_ip_list_glue}" is different from the address record in the child zone "{ns_ip_list_zone}".', @_;
    },
    IPV4_DISABLED => sub {
        __x    # CONSISTENCY:IPV4_DISABLED
          'IPv4 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IPV6_DISABLED => sub {
        __x    # CONSISTENCY:IPV6_DISABLED
          'IPv6 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    MULTIPLE_NS_SET => sub {
        __x    # CONSISTENCY:MULTIPLE_NS_SET
          'Found {count} NS set(s).', @_;
    },
    MULTIPLE_SOA_MNAMES => sub {
        __x    # CONSISTENCY:MULTIPLE_SOA_MNAMES
          'Saw {count} SOA mname.', @_;
    },
    MULTIPLE_SOA_RNAMES => sub {
        __x    # CONSISTENCY:MULTIPLE_SOA_RNAMES
          'Found {count} SOA rname(s).', @_;
    },
    MULTIPLE_SOA_SERIALS => sub {
        __x    # CONSISTENCY:MULTIPLE_SOA_SERIALS
          'Found {count} SOA serial number(s).', @_;
    },
    MULTIPLE_SOA_TIME_PARAMETER_SET => sub {
        __x    # CONSISTENCY:MULTIPLE_SOA_TIME_PARAMETER_SET
          "Found {count} SOA time parameter set(s).", @_;
    },
    NO_RESPONSE => sub {
        __x    # CONSISTENCY:NO_RESPONSE
          'Nameserver {ns} did not respond.', @_;
    },
    NO_RESPONSE_NS_QUERY => sub {
        __x    # CONSISTENCY:NO_RESPONSE_NS_QUERY
          'No response from nameserver {ns} on NS queries.', @_;
    },
    NO_RESPONSE_SOA_QUERY => sub {
        __x    # CONSISTENCY:NO_RESPONSE_SOA_QUERY
          'No response from nameserver {ns} on SOA queries.', @_;
    },
    NS_SET => sub {
        __x    # CONSISTENCY:NS_SET
          'Saw NS set ({nsname_list}) on following nameserver set : {servers}.', @_;
    },
    ONE_NS_SET => sub {
        __x    # CONSISTENCY:ONE_NS_SET
          "A single NS set was found ({nsname_list}).", @_;
    },
    ONE_SOA_MNAME => sub {
        __x    # CONSISTENCY:ONE_SOA_MNAME
          "A single SOA mname value was seen ({mname}).", @_;
    },
    ONE_SOA_RNAME => sub {
        __x    # CONSISTENCY:ONE_SOA_RNAME
          "A single SOA rname value was found ({rname}).", @_;
    },
    ONE_SOA_SERIAL => sub {
        __x    # CONSISTENCY:ONE_SOA_SERIAL
          "A single SOA serial number was found ({serial}).", @_;
    },
    ONE_SOA_TIME_PARAMETER_SET => sub {
        __x    # CONSISTENCY:ONE_SOA_TIME_PARAMETER_SET
          'A single SOA time parameter set was seen '
          . '(REFRESH={refresh},RETRY={retry},EXPIRE={expire},MINIMUM={minimum}).',
          @_;
    },
    SOA_RNAME => sub {
        __x    # CONSISTENCY:SOA_RNAME
          "Found SOA rname {rname} on following nameserver set : {ns_list}.", @_;
    },
    SOA_SERIAL => sub {
        __x    # CONSISTENCY:SOA_SERIAL
          'Saw SOA serial number {serial} on following nameserver set : {ns_list}.', @_;
    },
    SOA_SERIAL_VARIATION => sub {
        __x    # CONSISTENCY:SOA_SERIAL_VARIATION
          'Difference between the smaller serial ({serial_min}) and the bigger one ({serial_max}) '
          . 'is greater than the maximum allowed ({max_variation}).', @_;
    },
    SOA_TIME_PARAMETER_SET => sub {
        __x    # CONSISTENCY:SOA_TIME_PARAMETER_SET
          'Saw SOA time parameter set (REFRESH={refresh}, RETRY={retry}, EXPIRE={expire}, '
          . 'MINIMUM={minimum}) on following nameserver set : {ns_list}.', @_;
    },
    TEST_CASE_END => sub {
        __x    # CONSISTENCY:TEST_CASE_END
          'TEST_CASE_END {testcase}.', @_;
    },
    TEST_CASE_START => sub {
        __x    # CONSISTENCY:TEST_CASE_START
          'TEST_CASE_START {testcase}.', @_;
    },
);

=over

=item tag_descriptions()

    my $hash_ref = tag_descriptions();

Used by the L<built-in translation system|Zonemaster::Engine::Translator>.

Returns a reference to a hash, the keys of which are the message tags and the corresponding values are strings (message ids).

=back

=cut

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

=over

=item version()

    my $version_string = version();

Returns a string containing the version of the current module.

=back

=cut

sub version {
    return "$Zonemaster::Engine::Test::Consistency::VERSION";
}

=head1 INTERNAL METHODS

=over

=item _emit_log()

    my $log_entry = _emit_log( $message_tag_string, $hash_ref );

Adds a message to the L<logger|Zonemaster::Engine::Logger> for this module.
See L<Zonemaster::Engine::Logger::Entry/add($tag, $argref, $module, $testcase)> for more details.

Takes a string (message tag) and a reference to a hash (arguments).

Returns a L<Zonemaster::Engine::Logger::Entry> object.

=back

=cut

sub _emit_log { my ( $tag, $argref ) = @_; return Zonemaster::Engine->logger->add( $tag, $argref, 'Consistency' ); }

=over

=item _ip_disabled_message()

    my $bool = _ip_disabled_message( $logentry_array_ref, $ns, @query_type_array );

Checks if the IP version of a given name server is allowed to be queried. If not, it adds a logging message and returns true. Else, it returns false.

Takes a reference to an array of L<Zonemaster::Engine::Logger::Entry> objects, a L<Zonemaster::Engine::Nameserver> object and an array of strings (query type).

Returns a boolean.

=back

=cut

sub _ip_disabled_message {
    my ( $results_array, $ns, @rrtypes ) = @_;

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
        push @$results_array, map {
          _emit_log(
            IPV6_DISABLED => {
                ns     => $ns->string,
                rrtype => $_
            }
          )
        } @rrtypes;
        return 1;
    }

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
        push @$results_array, map {
          _emit_log(
            IPV4_DISABLED => {
                ns     => $ns->string,
                rrtype => $_,
            }
          )
        } @rrtypes;
        return 1;
    }
    return 0;
}


=head1 TESTS

=over

=item consistency01()

    my @logentry_array = consistency01( $zone );

Runs the L<Consistency01 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Consistency-TP/consistency01.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub consistency01 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Consistency01';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my %nsnames_and_ip;
    my %serials;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( _ip_disabled_message( \@results, $local_ns, $query_type ) ) {
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results, _emit_log( NO_RESPONSE => { ns => $local_ns->string } );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results, _emit_log( NO_RESPONSE_SOA_QUERY => { ns => $local_ns->string } );
            next;
        }
        else {
            push @{ $serials{ $soa->serial } }, $local_ns->name->string . q{/} . $local_ns->address->short;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    my @serial_numbers = sort keys %serials;

    foreach my $serial ( @serial_numbers ) {
        push @results,
          _emit_log(
            SOA_SERIAL => {
                serial  => $serial,
                ns_list => join( q{;}, sort @{ $serials{$serial} } ),
            }
          );
    }

    if ( scalar( @serial_numbers ) == 1 ) {
        push @results,
          _emit_log(
            ONE_SOA_SERIAL => {
                serial => ( keys %serials )[0],
            }
          );
    }
    elsif ( scalar @serial_numbers ) {
        push @results,
          _emit_log(
            MULTIPLE_SOA_SERIALS => {
                count => scalar( keys %serials ),
            }
          );
        if ( $serial_numbers[-1] - $serial_numbers[0] > $SERIAL_MAX_VARIATION ) {
            push @results,
              _emit_log(
                SOA_SERIAL_VARIATION => {
                    serial_min    => $serial_numbers[0],
                    serial_max    => $serial_numbers[-1],
                    max_variation => $SERIAL_MAX_VARIATION,
                }
              );
        }
    } ## end elsif ( scalar @serial_numbers)

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub consistency01

=over

=item consistency02()

    my @logentry_array = consistency02( $zone );

Runs the L<Consistency02 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Consistency-TP/consistency02.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub consistency02 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Consistency02';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my %nsnames_and_ip;
    my %rnames;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( _ip_disabled_message( \@results, $local_ns, $query_type ) ) {
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results, _emit_log( NO_RESPONSE => { ns => $local_ns->string } );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results, _emit_log( NO_RESPONSE_SOA_QUERY => { ns => $local_ns->string } );
            next;
        }
        else {
            push @{ $rnames{ lc( $soa->rname ) } }, $local_ns->name->string . q{/} . $local_ns->address->short;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar( keys %rnames ) == 1 ) {
        push @results,
          _emit_log(
            ONE_SOA_RNAME => {
                rname => ( keys %rnames )[0],
            }
          );
    }
    elsif ( scalar( keys %rnames ) ) {
        push @results,
          _emit_log(
            MULTIPLE_SOA_RNAMES => {
                count => scalar( keys %rnames ),
            }
          );
        foreach my $rname ( keys %rnames ) {
            push @results,
              _emit_log(
                SOA_RNAME => {
                    rname   => $rname,
                    ns_list => join( q{;}, @{ $rnames{$rname} } ),
                }
              );
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub consistency02

=over

=item consistency03()

    my @logentry_array = consistency03( $zone );

Runs the L<Consistency03 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Consistency-TP/consistency03.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub consistency03 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Consistency03';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my %nsnames_and_ip;
    my %time_parameter_sets;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( _ip_disabled_message( \@results, $local_ns, $query_type ) ) {
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results, _emit_log( NO_RESPONSE => { ns => $local_ns->string } );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results, _emit_log( NO_RESPONSE_SOA_QUERY => { ns => $local_ns->string } );
            next;
        }
        else {
            push
              @{ $time_parameter_sets{ sprintf q{%d;%d;%d;%d}, $soa->refresh, $soa->retry, $soa->expire, $soa->minimum }
              },
              $local_ns->name->string . q{/} . $local_ns->address->short;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar( keys %time_parameter_sets ) == 1 ) {
        my ( $refresh, $retry, $expire, $minimum ) = split /;/sxm, ( keys %time_parameter_sets )[0];
        push @results,
          _emit_log(
            ONE_SOA_TIME_PARAMETER_SET => {
                refresh => $refresh,
                retry   => $retry,
                expire  => $expire,
                minimum => $minimum,
            }
          );
    }
    elsif ( scalar( keys %time_parameter_sets ) ) {
        push @results,
          _emit_log(
            MULTIPLE_SOA_TIME_PARAMETER_SET => {
                count => scalar( keys %time_parameter_sets ),
            }
          );
        foreach my $time_parameter_set ( keys %time_parameter_sets ) {
            my ( $refresh, $retry, $expire, $minimum ) = split /;/sxm, $time_parameter_set;
            push @results,
              _emit_log(
                SOA_TIME_PARAMETER_SET => {
                    refresh => $refresh,
                    retry   => $retry,
                    expire  => $expire,
                    minimum => $minimum,
                    ns_list => join( q{;}, sort @{ $time_parameter_sets{$time_parameter_set} } ),
                }
              );
        }
    } ## end elsif ( scalar( keys %time_parameter_sets...))

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub consistency03

=over

=item consistency04()

    my @logentry_array = consistency04( $zone );

Runs the L<Consistency04 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Consistency-TP/consistency04.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub consistency04 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Consistency04';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my %nsnames_and_ip;
    my %ns_sets;
    my $query_type = q{NS};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( _ip_disabled_message( \@results, $local_ns, $query_type ) ) {
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results, _emit_log( NO_RESPONSE => { ns => $local_ns->string } );
            next;
        }

        my ( @ns ) = sort map { lc( $_->nsdname ) } $p->get_records_for_name( $query_type, $zone->name );

        if ( not scalar( @ns ) ) {
            push @results, _emit_log( NO_RESPONSE_NS_QUERY => { ns => $local_ns->string } );
            next;
        }
        else {
            push @{ $ns_sets{ join( q{;}, @ns ) } }, $local_ns->string;
            $nsnames_and_ip{ $local_ns->string }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar( keys %ns_sets ) == 1 ) {
        push @results, _emit_log( ONE_NS_SET => { nsname_list => ( keys %ns_sets )[0] });
    }
    elsif ( scalar( keys %ns_sets ) ) {
        push @results,
          _emit_log(
            MULTIPLE_NS_SET => {
                count => scalar( keys %ns_sets ),
            }
          );
        foreach my $ns_set ( keys %ns_sets ) {
            push @results,
              _emit_log(
                NS_SET => {
                    nsname_list => $ns_set,
                    servers     => join( q{;}, @{ $ns_sets{$ns_set} } ),
                }
              );
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub consistency04

=over

=item consistency05()

    my @logentry_array = consistency05( $zone );

Runs the L<Consistency05 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Consistency-TP/consistency05.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub consistency05 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Consistency05';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    # Steps 1–3
    my @parent_ns = @{ Zonemaster::Engine::TestMethodsV2->get_parent_ns_names_and_ips( $zone ) // [] };
    my @parent_ns_ips = @{ Zonemaster::Engine::TestMethodsV2->get_parent_ns_ips( $zone ) // [] };

    my @child_ns_ips = uniq
        @{ Zonemaster::Engine::TestMethodsV2->get_del_ns_ips( $zone ) // [] },
        @{ Zonemaster::Engine::TestMethodsV2->get_zone_ns_ips( $zone ) // [] };

    my %delegation;
    my %child_zone_ns;
    my $delegation_id_ns = Zonemaster::Engine::NameserverSet->new();
    my $delegation_ood_ns = Zonemaster::Engine::NameserverSet->new();
    my %missing_glue;
    my $auth_addr_records_in_child = Zonemaster::Engine::NameserverSet->new();
    my %extra_address_child;

    # Step 4
    foreach my $parent_ns ( @parent_ns_ips ) {
        my $p = $parent_ns->query( $zone->name(), 'SOA' );
        next unless ( defined $p and $p->is_redirect );

        my %authority =
            map { lc name( $_->nsdname() ) => 1 }
            $p->get_records_for_name( 'NS', $zone, 'authority' );

        
        my @additional =
            map {
                my $name = name( $_->owner() );

                # Filters out A and AAAA records with invalid IP addresses
                my $addr = Net::IP::XS->new( $_->address );
                if ( defined $addr ) {
                    Zonemaster::Engine::Nameserver->new( { name => $name, address => $addr } )
                }
                else {
                    ()
                }
            }
            grep {
                my $name = lc name( $_->owner() );
                exists $authority{$name} and ( $_->type eq 'A' or $_->type eq 'AAAA' )
            }
            $p->additional;

        my $set = Zonemaster::Engine::NameserverSet->new();
        $set->push( keys %authority, @additional );

        $delegation{$parent_ns} = [ $set->sorted_items() ];
    }


    # Step 5
    foreach my $parent_ns_ip ( sort keys %delegation ) {
        foreach my $delegation_ns ( @{ $delegation{$parent_ns_ip} } ) {
            my $delegation_ns_name = do {
                if ( $delegation_ns->isa('Zonemaster::Engine::Nameserver') ) {
                    $delegation_ns->name()
                }
                else {
                    $delegation_ns;
                }
            };

            if ( $zone->name()->is_in_bailiwick( $delegation_ns_name ) ) {
                if ( $delegation_ns->isa('Zonemaster::Engine::DNSName') ) {
                    push @{$missing_glue{ lc $delegation_ns }}, $parent_ns_ip;
                }
                $delegation_id_ns->push($delegation_ns);
            }
            else {
                $delegation_ood_ns->push($delegation_ns);
            }
        }
    }

    # Step 6
    {
        my %delegation_sets;
        for my $d ( keys %delegation ) {
            my $s = join(";", @{$delegation{$d}});
            push @{$delegation_sets{$s}}, $d;
        }
        if ( scalar %delegation_sets > 1 ) {
            push @results, _emit_log( CS05_INCONSISTENT_DELEGATION => {} );
            while ( my ($ns_deleg_list, $ns_list) = each %delegation_sets ) {
                push @results, _emit_log( CS05_DELEGATION => {
                    ns_deleg_list => $ns_deleg_list,
                    ns_list => join( ';', @$ns_list )
                } );
            }
        }
    }

    # Step 7
    if ( $zone->name() ne '.' ) {
        foreach my $fake_name ( Zonemaster::Engine::Recursor->get_fake_names( $zone->name() ) ) {
            $fake_name = name( $fake_name );
            my @fake_ns = map {
                Zonemaster::Engine::Nameserver->new( { name => $fake_name, address => $_ } )
            } Zonemaster::Engine::Recursor->get_fake_addresses( $zone->name(), $fake_name );

            if ( $zone->name()->is_in_bailiwick( $fake_name ) ) {
                if ( scalar @fake_ns == 0 ) {
                    push @results, _emit_log( CS05_MISSING_GLUE_FOR_NS_UNDEL => { nsname => $fake_name } );
                }
                else {
                    $delegation_id_ns->push( @fake_ns );
                }
            }
            else {
                if ( scalar @fake_ns == 0 ) {
                    $delegation_ood_ns->push( $fake_name );
                }
                else {
                    $delegation_ood_ns->push( @fake_ns );
                }
            }
        }
    }

    # Step 8
    if ( $zone->name() eq '.' ) {
        my @hint_ns = @{ Zonemaster::Engine::TestMethodsV2->get_del_ns_names_and_ips( $zone ) };

        foreach my $item ( @hint_ns ) {
            if ( $item->isa( 'Zonemaster::Engine::DNSName') ) {
                push @results, _emit_log( CS05_MISSING_GLUE_FOR_ROOT_NS => { nsname => $item } );
            }
            else {
                $delegation_id_ns->push( $item );
            }
        }
    }

    # Step 9
    while ( my ($ns, $ns_list) = each %missing_glue ) {
        push @results, _emit_log( CS05_MISSING_GLUE_FOR_NS => {
            nsname => $ns,
            ns_list => join(';', @$ns_list)
        } );
    }

    # Step 10
    if ( scalar @child_ns_ips == 0 ) {
        push @results, _emit_log( CS05_NO_NS_ADDR_CHILD => {} );
        goto out;
    }

    # Step 11
    foreach my $ns ( @child_ns_ips ) {
        my $p = $ns->query( $zone->name(), 'NS' );
        next unless defined $p and $p->rcode eq 'NOERROR' and $p->aa;

        my @ns_nsnames = uniq map { name( lc $_->nsdname() ) } $p->get_records_for_name( 'NS', $zone );
        $child_zone_ns{ $ns->address()->short() } = \@ns_nsnames if scalar @ns_nsnames > 0;

        my @id_ns = uniq (
            grep( { $zone->name()->is_in_bailiwick(name($_)) } @ns_nsnames ),
            $delegation_id_ns->names()
        );

        foreach my $s ( @id_ns ) {
            foreach my $qtype ( qw(A AAAA) ) {
                my $p = Zonemaster::Engine::Recursor->recurse( $s, $qtype );
                next unless defined $p and $p->rcode eq 'NOERROR' and $p->aa;

                $auth_addr_records_in_child->push(
                    map {
                        Zonemaster::Engine::Nameserver->new( { name => $s, address => $_->address() } )
                    } $p->get_records_for_name( $qtype, $s, 'answer' )
                );
            }
        }
    }

    # Step 12
    if ( scalar %child_zone_ns == 0 ) {
        push @results, _emit_log( CS05_CHILD_ZONE_LAME => { ns_list => join(';', @child_ns_ips) } );
        goto out;
    }

    # Step 13
    foreach my $n ( $delegation_id_ns->names() ) {
        my $parent_glue = Zonemaster::Engine::NameserverSet->new();
        $parent_glue->push(
            grep { $_->isa('Zonemaster::Engine::Nameserver') } $delegation_id_ns->get($n)
        );
        next if scalar $parent_glue->items() == 0;

        my $child_auth = Zonemaster::Engine::NameserverSet->new();
        $child_auth->push( $auth_addr_records_in_child->get($n) );
        my ( $only_in_parent, $only_in_child ) = $parent_glue->difference( $child_auth );

        if ( scalar $child_auth->items() == 0 ) {
            push @results, _emit_log( CS05_ID_ADDR_MISSING => { nsname => $n } );
        }
        elsif ( scalar $only_in_parent->items() != 0 ) {
            push @results, _emit_log( CS05_ID_ADDR_MISMATCH => {
                nsname => $n,
                ns_ip_list_glue => join( ';', map { $_->address()->short() } $only_in_parent->sorted_items() ),
                ns_ip_list_zone => join( ';', map { $_->address()->short() } $child_auth->sorted_items() )
            } );
        }
        elsif ( scalar $only_in_child->items() != 0 ) {
            $extra_address_child{ $_->address()->short() } = 1 foreach $only_in_child->items();
        }
    }

    # Step 14
    if ( scalar %extra_address_child ) {
        push @results, _emit_log( CS05_EXTRA_ADDR_CHILD => {
            ns_list => join(';', sort keys %extra_address_child )
        } );
    }

    # Step 15
    foreach my $n ( $delegation_ood_ns->names() ) {
        my $set = Zonemaster::Engine::NameserverSet->new();
        $set->push(
            grep { $_->isa('Zonemaster::Engine::Nameserver') } $delegation_ood_ns->get($n)
        );
        next if scalar $set->items() == 0;

        my $lookup = Zonemaster::Engine::NameserverSet->new();
        $lookup->push(
            map {
                Zonemaster::Engine::Nameserver->new( { name => $_->owner(), address => $_->address() } )
            }
            map {
                my $p = Zonemaster::Engine::Recursor->recurse( $n, $_ );
                if ( defined $p and $p->rcode eq 'NOERROR' and $p->aa ) {
                    $p->get_records_for_name( $_, $n, 'answer' );
                }
                else {
                    ();
                }
            } ( qw(A AAAA) )
        );

        if ( scalar $lookup->items() ) {
            if ( not $set->equals( $lookup ) ) {
                push @results, _emit_log( CS05_OOD_ADDR_MISMATCH => {
                    nsname => $n,
                    ns_ip_list_ref => join( ";", map { $_->address() } $set->sorted_items() ),
                    ns_ip_list_lookup => join( ";", map { $_->address() } $lookup->sorted_items() )
                } );
            }
        }
    }

    # Step 16
    if ( not grep /^CS05_/, map { $_->tag() } @results ) {
        push @results, _emit_log( CS05_NO_MISMATCH_GLUE_ZONE => {} );
    }

  out:
    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
}                               ## end sub consistency05

=over

=item consistency06()

    my @logentry_array = consistency06( $zone );

Runs the L<Consistency06 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Consistency-TP/consistency06.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub consistency06 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Consistency06';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my %nsnames_and_ip;
    my %mnames;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( _ip_disabled_message( \@results, $local_ns, $query_type ) ) {
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results, _emit_log( NO_RESPONSE => { ns => $local_ns->string } );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results, _emit_log( NO_RESPONSE_SOA_QUERY => { ns => $local_ns->string } );
            next;
        }
        else {
            push @{ $mnames{ lc( $soa->mname ) } }, $local_ns->name->string . q{/} . $local_ns->address->short;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar( keys %mnames ) == 1 ) {
        push @results,
          _emit_log(
            ONE_SOA_MNAME => {
                mname => ( keys %mnames )[0],
            }
          );
    }
    elsif ( scalar( keys %mnames ) ) {
        push @results,
          _emit_log(
            MULTIPLE_SOA_MNAMES => {
                count => scalar( keys %mnames ),
            }
          );
        foreach my $mname ( keys %mnames ) {
            push @results,
              _emit_log(
                SOA_MNAME => {
                    mname   => $mname,
                    ns_list => join( q{;}, @{ $mnames{$mname} } ),
                }
              );
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub consistency06

1;
