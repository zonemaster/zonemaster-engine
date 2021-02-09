package Zonemaster::Engine::Test::Consistency;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare("v1.1.16");

use Zonemaster::Engine;

use List::MoreUtils qw[uniq];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Constants qw[:ip :soa];
use Zonemaster::Engine::Test::Address;
use Zonemaster::Engine::Util;
use Zonemaster::Engine::TestMethods;

###
### Entry points
###

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

###
### Metadata Exposure
###

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
              ADDRESSES_MATCH
              CHILD_NS_FAILED
              CHILD_ZONE_LAME
              EXTRA_ADDRESS_CHILD
              IN_BAILIWICK_ADDR_MISMATCH
              NO_RESPONSE
              OUT_OF_BAILIWICK_ADDR_MISMATCH
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
    ADDRESSES_MATCH => sub {
        __x    # CONSISTENCY:ADDRESSES_MATCH
          'Glue records are consistent between glue and authoritative data.', @_;
    },
    CHILD_NS_FAILED => sub {
        __x    # CONSISTENCY:CHILD_NS_FAILED
          'Unexpected or erroneous reply from {ns}.', @_;
    },
    CHILD_ZONE_LAME => sub {
        __x    # CONSISTENCY:CHILD_ZONE_LAME
          'Lame delegation.', @_;
    },
    EXTRA_ADDRESS_CHILD => sub {
        __x    # CONSISTENCY:EXTRA_ADDRESS_CHILD
          'Child has extra nameserver IP address(es) not listed at parent ({ns_ip_list}).', @_;
    },
    IN_BAILIWICK_ADDR_MISMATCH => sub {
        __x    # CONSISTENCY:IN_BAILIWICK_ADDR_MISMATCH
          'In-bailiwick name server listed at parent has a mismatch between glue data at parent '
          . '({parent_addresses}) and any equivalent address record in child zone ({zone_addresses}).',
          @_;
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
    OUT_OF_BAILIWICK_ADDR_MISMATCH => sub {
        __x    # CONSISTENCY:OUT_OF_BAILIWICK_ADDR_MISMATCH
          'Out-of-bailiwick name server listed at parent with glue record has a mismatch between '
          . 'the glue at the parent ({parent_addresses}) and any equivalent address record found '
          . 'in authoritative zone ({zone_addresses}).', @_;
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

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

sub version {
    return "$Zonemaster::Engine::Test::Consistency::VERSION";
}

###
### Tests
###

sub consistency01 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;
    my %serials;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $local_ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $local_ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results, info( NO_RESPONSE => { ns => $local_ns->string } );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results, info( NO_RESPONSE_SOA_QUERY => { ns => $local_ns->string } );
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
          info(
            SOA_SERIAL => {
                serial  => $serial,
                ns_list => join( q{;}, sort @{ $serials{$serial} } ),
            }
          );
    }

    if ( scalar( @serial_numbers ) == 1 ) {
        push @results,
          info(
            ONE_SOA_SERIAL => {
                serial => ( keys %serials )[0],
            }
          );
    }
    elsif ( scalar @serial_numbers ) {
        push @results,
          info(
            MULTIPLE_SOA_SERIALS => {
                count => scalar( keys %serials ),
            }
          );
        if ( $serial_numbers[-1] - $serial_numbers[0] > $MAX_SERIAL_VARIATION ) {
            push @results,
              info(
                SOA_SERIAL_VARIATION => {
                    serial_min    => $serial_numbers[0],
                    serial_max    => $serial_numbers[-1],
                    max_variation => $MAX_SERIAL_VARIATION,
                }
              );
        }
    } ## end elsif ( scalar @serial_numbers)

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub consistency01

sub consistency02 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;
    my %rnames;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $local_ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $local_ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results, info( NO_RESPONSE => { ns => $local_ns->string } );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results, info( NO_RESPONSE_SOA_QUERY => { ns => $local_ns->string } );
            next;
        }
        else {
            push @{ $rnames{ lc( $soa->rname ) } }, $local_ns->name->string . q{/} . $local_ns->address->short;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar( keys %rnames ) == 1 ) {
        push @results,
          info(
            ONE_SOA_RNAME => {
                rname => ( keys %rnames )[0],
            }
          );
    }
    elsif ( scalar( keys %rnames ) ) {
        push @results,
          info(
            MULTIPLE_SOA_RNAMES => {
                count => scalar( keys %rnames ),
            }
          );
        foreach my $rname ( keys %rnames ) {
            push @results,
              info(
                SOA_RNAME => {
                    rname   => $rname,
                    ns_list => join( q{;}, @{ $rnames{$rname} } ),
                }
              );
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub consistency02

sub consistency03 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;
    my %time_parameter_sets;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $local_ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $local_ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results, info( NO_RESPONSE => { ns => $local_ns->string } );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results, info( NO_RESPONSE_SOA_QUERY => { ns => $local_ns->string } );
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
          info(
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
          info(
            MULTIPLE_SOA_TIME_PARAMETER_SET => {
                count => scalar( keys %time_parameter_sets ),
            }
          );
        foreach my $time_parameter_set ( keys %time_parameter_sets ) {
            my ( $refresh, $retry, $expire, $minimum ) = split /;/sxm, $time_parameter_set;
            push @results,
              info(
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

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub consistency03

sub consistency04 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;
    my %ns_sets;
    my $query_type = q{NS};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $local_ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $local_ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results, info( NO_RESPONSE => { ns => $local_ns->string } );
            next;
        }

        my ( @ns ) = sort map { lc( $_->nsdname ) } $p->get_records_for_name( $query_type, $zone->name );

        if ( not scalar( @ns ) ) {
            push @results, info( NO_RESPONSE_NS_QUERY => { ns => $local_ns->string } );
            next;
        }
        else {
            push @{ $ns_sets{ join( q{;}, @ns ) } }, $local_ns->string;
            $nsnames_and_ip{ $local_ns->string }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar( keys %ns_sets ) == 1 ) {
        push @results, info( ONE_NS_SET => { nsname_list => ( keys %ns_sets )[0] });
    }
    elsif ( scalar( keys %ns_sets ) ) {
        push @results,
          info(
            MULTIPLE_NS_SET => {
                count => scalar( keys %ns_sets ),
            }
          );
        foreach my $ns_set ( keys %ns_sets ) {
            push @results,
              info(
                NS_SET => {
                    nsname_list => $ns_set,
                    servers     => join( q{;}, @{ $ns_sets{$ns_set} } ),
                }
              );
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub consistency04

sub _get_addr_rrs {
    my ( $class, $ns, $name, $qtype ) = @_;
    my $p = $ns->query( $name, $qtype, { recurse => 0 } );
    if ( !$p ) {
        return info( NO_RESPONSE => { ns => $ns->string } );
    }
    elsif ($p->is_redirect) {
        my $p = Zonemaster::Engine->recurse( $name, $qtype, q{IN} );
        if ( $p ) {
            return ( undef, $p->get_records_for_name( $qtype, $name, 'answer' ) );
        } else {
            return ( undef );
        }
    }
    elsif ( $p->aa and $p->rcode eq 'NOERROR' ) {
        return ( undef, $p->get_records_for_name( $qtype, $name, 'answer' ) );
    }
    elsif (not ($p->aa and $p->rcode eq 'NXDOMAIN')) {
        return info( CHILD_NS_FAILED => { ns => $ns->string } );
    }
    return ( undef );
}

sub consistency05 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %strict_glue;
    my %extended_glue;

    # We need to work on Methods...
    # This part of code is supposed to replace method4 call
    my @child_nsnames;
    my @nsnames;
    my $ns_aref = $zone->parent->query_all( $zone->name, q{NS} );
    my %parent_glues;
    foreach my $p ( @{$ns_aref} ) {
        next if not $p;
        push @nsnames, $p->get_records_for_name( q{NS}, $zone->name );
    }
    @child_nsnames = uniq map { name( lc( $_->nsdname ) ) } @nsnames;
    foreach my $nsname ( @child_nsnames ) {
        my $a_aref = $zone->parent->query_all( $nsname, q{A} );
        my $aaaa_aref = $zone->parent->query_all( $nsname, q{AAAA} );
        foreach my $p ( @{$a_aref} ) {
            next if not $p;
            foreach my $rr ( $p->get_records_for_name( q{A}, $nsname ) ) {
                $parent_glues{ lc( $rr->owner ) . q{/} . $rr->address } = $nsname;
            }
        }
        foreach my $p ( @{$aaaa_aref} ) {
            next if not $p;
            foreach my $rr ( $p->get_records_for_name( q{AAAA}, $nsname ) ) {
                $parent_glues{ lc( $rr->owner ) . q{/} . $rr->address } = $nsname;
            }
        }
    }

    for my $ns_string ( keys %parent_glues ) {
        if ( $zone->name->is_in_bailiwick( $parent_glues{$ns_string} ) ) {
            $strict_glue{ $ns_string } = 1;
        }
        else {
            push @{ $extended_glue{ $parent_glues{$ns_string} } }, $ns_string;
        }
    }

    my @ib_nsnames =
      grep { $zone->name->is_in_bailiwick( $_ ) } @{ Zonemaster::Engine::TestMethods->method2and3( $zone ) };
    my @ib_nss = grep { Zonemaster::Engine::Util::ipversion_ok( $_->address->version ) }
      @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) };
    my %child_ib_strings;
    for my $ib_nsname ( @ib_nsnames ) {
        my $is_lame = 1;
        for my $ns ( @ib_nss ) {
            my ( $msg_a,    @rrs_a )    = $class->_get_addr_rrs( $ns, $ib_nsname, q{A} );
            my ( $msg_aaaa, @rrs_aaaa ) = $class->_get_addr_rrs( $ns, $ib_nsname, q{AAAA} );

            if ( defined $msg_a ) {
                push @results, $msg_a;
            }
            if ( defined $msg_aaaa ) {
                push @results, $msg_aaaa;
            }
            if ( !defined $msg_a || !defined $msg_aaaa ) {
                $is_lame = 0;
            }

            for my $rr ( @rrs_a, @rrs_aaaa ) {
                $child_ib_strings{ lc( $rr->name ) . q{/} . $rr->address } = 1;
            }
        }

        if ( $is_lame ) {
            push @results, info( CHILD_ZONE_LAME => {} );
            return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
        }
    } ## end for my $ib_nsname ( @ib_nsnames)

    my @ib_match       = grep { exists $child_ib_strings{$_} } keys %strict_glue;
    my @ib_mismatch    = grep { !exists $child_ib_strings{$_} } keys %strict_glue;
    my @ib_extra_child = grep { !exists $strict_glue{$_} } keys %child_ib_strings;

    if ( scalar @ib_mismatch ) {
        push @results,
          info(
            IN_BAILIWICK_ADDR_MISMATCH => {
                parent_addresses => join( q{;}, sort keys %strict_glue ),
                zone_addresses => join( q{;}, sort keys %child_ib_strings ),
            }
          );
    }
    if ( scalar @ib_extra_child ) {
        push @results,
          info(
            EXTRA_ADDRESS_CHILD => {
                ns_ip_list => join( q{;}, sort @ib_extra_child ),
            }
          );
    }

    my @oob_match;
    my @oob_mismatch;
    for my $glue_name ( keys %extended_glue ) {
        my @glue_strings = @{ $extended_glue{$glue_name} };

        my %child_oob_strings;

        my $p_a = Zonemaster::Engine->recurse( $glue_name, q{A}, q{IN} );
        if ( $p_a ) {
            for my $rr ( $p_a->get_records_for_name( q{A}, $glue_name, q{answer} ) ) {
                $child_oob_strings{ lc( $rr->owner ) . q{/} . $rr->address } = 1;
            }
        }

        my $p_aaaa = Zonemaster::Engine->recurse( $glue_name, q{AAAA}, q{IN} );
        if ( $p_aaaa ) {
            for my $rr ( $p_aaaa->get_records_for_name( q{AAAA}, $glue_name, q{answer} ) ) {
                $child_oob_strings{ lc( $rr->owner ) . q{/} . $rr->address } = 1;
            }
        }

        push @oob_match,    grep { exists $child_oob_strings{$_} } @glue_strings;
        push @oob_mismatch, grep { !exists $child_oob_strings{$_} } @glue_strings;
        if ( grep { !exists $child_oob_strings{$_} } @glue_strings ) {
            push @results,
              info(
                OUT_OF_BAILIWICK_ADDR_MISMATCH => {
                    parent_addresses => join( q{;}, sort @glue_strings ),
                    zone_addresses => join( q{;}, sort keys %child_oob_strings ),
                }
              );
        }
    } ## end for my $glue_name ( keys...)

    if ( !@ib_extra_child && !@ib_mismatch && !@oob_mismatch ) {
        push @results, info( ADDRESSES_MATCH => {} );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub consistency05

sub consistency06 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;
    my %mnames;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $local_ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $local_ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results, info( NO_RESPONSE => { ns => $local_ns->string } );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results, info( NO_RESPONSE_SOA_QUERY => { ns => $local_ns->string } );
            next;
        }
        else {
            push @{ $mnames{ lc( $soa->mname ) } }, $local_ns->name->string . q{/} . $local_ns->address->short;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar( keys %mnames ) == 1 ) {
        push @results,
          info(
            ONE_SOA_MNAME => {
                mname => ( keys %mnames )[0],
            }
          );
    }
    elsif ( scalar( keys %mnames ) ) {
        push @results,
          info(
            MULTIPLE_SOA_MNAMES => {
                count => scalar( keys %mnames ),
            }
          );
        foreach my $mname ( keys %mnames ) {
            push @results,
              info(
                SOA_MNAME => {
                    mname   => $mname,
                    ns_list => join( q{;}, @{ $mnames{$mname} } ),
                }
              );
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub consistency06

1;

=head1 NAME

Zonemaster::Engine::Test::Consistency - Consistency module showing the expected structure of Zonemaster test modules

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Consistency->all($zone);

=head1 METHODS

=over

=item all($zone)

Runs the default set of tests and returns a list of log entries made by the tests.

=item metadata()

Returns a reference to a hash, the keys of which are the names of all test methods in the module, and the corresponding values are references to
lists with all the tags that the method can use in log entries.

=item tag_descriptions()

Returns a refernce to a hash with translation functions. Used by the builtin translation system.

=item version()

Returns a version string for the module.

=back

=head1 TESTS

=over

=item consistency01($zone)

Query all nameservers for SOA, and see that they all have the same SOA serial number.

=item consistency02($zone)

Query all nameservers for SOA, and see that they all have the same SOA rname.

=item consistency03($zone)

Query all nameservers for SOA, and see that they all have the same time parameters (REFRESH/RETRY/EXPIRE/MINIMUM).

=item consistency04($zone)

Query all nameservers for NS set, and see that they have all the same content.

=item consistency05($zone)

Verify that the glue records are consistent between glue and authoritative data.

=item consistency06($zone)

Query all nameservers for SOA, and see that they all have the same SOA mname.

=back

=cut
