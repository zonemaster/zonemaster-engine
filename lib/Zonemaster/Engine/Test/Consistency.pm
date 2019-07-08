package Zonemaster::Engine::Test::Consistency;

use version; our $VERSION = version->declare("v1.1.8");

use strict;
use warnings;

use 5.014002;

use Zonemaster::Engine;
use Zonemaster::Engine::Util;
use Zonemaster::Engine::Test::Address;
use Zonemaster::Engine::Constants qw[:ip :soa];

use List::MoreUtils qw[uniq];

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
              )
        ],
        consistency06 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_SOA_QUERY
              ONE_SOA_MNAME
              MULTIPLE_SOA_MNAMES
              )
        ],
    };
} ## end sub metadata

sub translation {
    return {
        ADDRESSES_MATCH      => 'Glue records are consistent between glue and authoritative data.',
        EXTRA_ADDRESS_CHILD  => 'Child has extra nameserver IP address(es) not listed at parent ({addresses}).',
        EXTRA_ADDRESS_PARENT => 'Parent has extra nameserver IP address(es) not listed at child ({addresses}).',
        IPV4_DISABLED        => 'IPv4 is disabled, not sending "{rrtype}" query to {ns}/{address}.',
        IPV6_DISABLED        => 'IPv6 is disabled, not sending "{rrtype}" query to {ns}/{address}.',
        MULTIPLE_NS_SET      => 'Saw {count} NS set.',
        MULTIPLE_SOA_MNAMES  => 'Saw {count} SOA mname.',
        MULTIPLE_SOA_RNAMES  => 'Saw {count} SOA rname.',
        MULTIPLE_SOA_SERIALS => 'Saw {count} SOA serial numbers.',
        MULTIPLE_SOA_TIME_PARAMETER_SET => 'Saw {count} SOA time parameter set.',
        NO_RESPONSE                     => 'Nameserver {ns}/{address} did not respond.',
        NO_RESPONSE_NS_QUERY            => 'No response from nameserver {ns}/{address} on NS queries.',
        NO_RESPONSE_SOA_QUERY           => 'No response from nameserver {ns}/{address} on SOA queries.',
        NS_SET                          => 'Saw NS set ({nsset}) on following nameserver set : {servers}.',
        ONE_NS_SET                      => 'A unique NS set was seen ({nsset}).',
        ONE_SOA_MNAME                   => 'A single SOA mname value was seen ({mname})',
        ONE_SOA_RNAME                   => 'A single SOA rname value was seen ({rname})',
        ONE_SOA_SERIAL                  => 'A single SOA serial number was seen ({serial}).',
        ONE_SOA_TIME_PARAMETER_SET      => 'A single SOA time parameter set was seen '
          . '(REFRESH={refresh},RETRY={retry},EXPIRE={expire},MINIMUM={minimum}).',
        SOA_RNAME            => 'Saw SOA rname {rname} on following nameserver set : {servers}.',
        SOA_SERIAL           => 'Saw SOA serial number {serial} on following nameserver set : {servers}.',
        SOA_SERIAL_VARIATION => 'Difference between the smaller serial '
          . '({serial_min}) and the bigger one ({serial_max}) is greater than the maximum allowed ({max_variation}).',
        SOA_TIME_PARAMETER_SET => 'Saw SOA time parameter set '
          . '(REFRESH={refresh},RETRY={retry},EXPIRE={expire},MINIMUM={minimum}) on following nameserver set : {servers}.',
        TOTAL_ADDRESS_MISMATCH => 'No common nameserver IP addresses between child ({child}) and parent ({glue}).',
    };
} ## end sub translation

sub version {
    return "$Zonemaster::Engine::Test::Consistency::VERSION";
}

###
### Tests
###

sub consistency01 {
    my ( $class, $zone ) = @_;
    my @results;
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
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results,
              info(
                NO_RESPONSE_SOA_QUERY => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
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
                servers => join( q{;}, sort @{ $serials{$serial} } ),
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

    return @results;
} ## end sub consistency01

sub consistency02 {
    my ( $class, $zone ) = @_;
    my @results;
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
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results,
              info(
                NO_RESPONSE_SOA_QUERY => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
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
                    servers => join( q{;}, @{ $rnames{$rname} } ),
                }
              );
        }
    }

    return @results;
} ## end sub consistency02

sub consistency03 {
    my ( $class, $zone ) = @_;
    my @results;
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
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results,
              info(
                NO_RESPONSE_SOA_QUERY => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
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
                    servers => join( q{;}, sort @{ $time_parameter_sets{$time_parameter_set} } ),
                }
              );
        }
    } ## end elsif ( scalar( keys %time_parameter_sets...))

    return @results;
} ## end sub consistency03

sub consistency04 {
    my ( $class, $zone ) = @_;
    my @results;
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
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }

        my ( @ns ) = sort map { lc( $_->nsdname ) } $p->get_records_for_name( $query_type, $zone->name );

        if ( not scalar( @ns ) ) {
            push @results,
              info(
                NO_RESPONSE_NS_QUERY => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }
        else {
            push @{ $ns_sets{ join( q{,}, @ns ) } }, $local_ns->name->string . q{/} . $local_ns->address->short;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar( keys %ns_sets ) == 1 ) {
        push @results,
          info(
            ONE_NS_SET => {
                nsset => ( keys %ns_sets )[0],
            }
          );
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
                    nsset   => $ns_set,
                    servers => join( q{;}, @{ $ns_sets{$ns_set} } ),
                }
              );
        }
    }

    return @results;
} ## end sub consistency04

sub _get_addr_rrs {
    my ( $class, $ns, $name, $qtype ) = @_;
    my $p = $ns->query( $name, $qtype );
    if ( !$p ) {
        return info(
            NO_RESPONSE => {
                ns      => $ns->name->string,
                address => $ns->address->short,
            }
        );
    }
    elsif ($p->is_redirect) {
        my $p_pub = Zonemaster::Engine->recurse( $name, $qtype, 'IN' );
        if ( $p_pub ) {
            return ( undef, $p_pub->get_records_for_name( $qtype, $name, 'answer' ) );
        } else {
            return ( undef );
        }
    }
    elsif ( $p->aa and $p->rcode eq 'NOERROR' ) {
        return ( undef, $p->get_records_for_name( $qtype, $name, 'answer' ) );
    }
    elsif (not ($p->aa and $p->rcode eq 'NXDOMAIN')) {
        return info(
            CHILD_NS_FAILED => {
                ns      => $ns->name->string,
                address => $ns->address->short,
            }
        );
    }
}

sub consistency05 {
    my ( $class, $zone ) = @_;
    my @results;

    my %strict_glue;
    my %extended_glue;
    for my $ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) } ) {
        my $ns_string = $ns->name->fqdn . "/" . $ns->address->short;
        if ( $zone->name->is_in_bailiwick( $ns->name ) ) {
            $strict_glue{ $ns_string } = 1;
        }
        else {
            push @{ $extended_glue{ $ns->name->string } }, $ns_string;
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
            my ( $msg_a,    @rrs_a )    = $class->_get_addr_rrs( $ns, $ib_nsname, 'A' );
            my ( $msg_aaaa, @rrs_aaaa ) = $class->_get_addr_rrs( $ns, $ib_nsname, 'AAAA' );

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
                $child_ib_strings{ lc( $rr->name ) . "/" . $rr->address } = 1;
            }
        }

        if ( $is_lame ) {
            push @results, info( CHILD_ZONE_LAME => {} );
            return @results;
        }
    } ## end for my $ib_nsname ( @ib_nsnames)

    my @ib_match       = grep { exists $child_ib_strings{$_} } keys %strict_glue;
    my @ib_mismatch    = grep { !exists $child_ib_strings{$_} } keys %strict_glue;
    my @ib_extra_child = grep { !exists $strict_glue{$_} } keys %child_ib_strings;

    if ( @ib_mismatch ) {
        push @results,
          info(
            IN_BAILIWICK_ADDR_MISMATCH => {
                parent_addresses => join( q{;}, sort keys %strict_glue ),
                zone_addresses => join( q{;}, sort keys %child_ib_strings ),
            }
          );
    }
    if ( @ib_extra_child ) {
        push @results,
          info(
            EXTRA_ADDRESS_CHILD => {
                addresses => join( q{;}, sort @ib_extra_child ),
            }
          );
    }

    my @oob_match;
    my @oob_mismatch;
    for my $glue_name ( keys %extended_glue ) {
        my @glue_strings = @{ $extended_glue{$glue_name} };

        my %child_oob_strings;

        my $p_a = Zonemaster::Engine->recurse( $glue_name, 'A', 'IN' );
        if ( $p_a ) {
            for my $rr ( $p_a->get_records_for_name( 'A', $glue_name, 'answer' ) ) {
                $child_oob_strings{ $rr->owner . "/" . $rr->address } = 1;
            }
        }

        my $p_aaaa = Zonemaster::Engine->recurse( $glue_name, 'AAAA', 'IN' );
        if ( $p_aaaa ) {
            for my $rr ( $p_aaaa->get_records_for_name( 'AAAA', $glue_name, 'answer' ) ) {
                $child_oob_strings{ $rr->owner . "/" . $rr->address } = 1;
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
        push @results,
          info(
            ADDRESSES_MATCH => {
                addresses => join( q{;}, sort @ib_match, @oob_match ),
            }
          );
    }

    return @results;
} ## end sub consistency05

sub consistency06 {
    my ( $class, $zone ) = @_;
    my @results;
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
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results,
              info(
                NO_RESPONSE_SOA_QUERY => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
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
                    servers => join( q{;}, @{ $mnames{$mname} } ),
                }
              );
        }
    }

    return @results;
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

=item translation()

Returns a refernce to a hash with translation data. Used by the builtin translation system.

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
