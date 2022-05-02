package Zonemaster::Engine::Test::Nameserver;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare( "v1.0.27" );

use List::MoreUtils qw[uniq none];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;
use JSON::PP;

use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Constants qw[:ip];
use Zonemaster::Engine::Test::Address;
use Zonemaster::Engine::Util;
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Net::IP;

Readonly my @NONEXISTENT_NAMES => qw{
  xn--nameservertest.iis.se
  xn--nameservertest.icann.org
  xn--nameservertest.ripe.net
};

###
### Entry Points
###

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver01} ) ) {
        push @results, $class->nameserver01( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver02} ) ) {
        push @results, $class->nameserver02( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver03} ) ) {
        push @results, $class->nameserver03( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver04} ) ) {
        push @results, $class->nameserver04( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver05} ) ) {
        push @results, $class->nameserver05( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver06} ) ) {
        push @results, $class->nameserver06( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver07} ) ) {
        push @results, $class->nameserver07( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver08} ) ) {
        push @results, $class->nameserver08( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver09} ) ) {
        push @results, $class->nameserver09( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver10} ) ) {
        push @results, $class->nameserver10( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver11} ) ) {
        push @results, $class->nameserver11( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver12} ) ) {
        push @results, $class->nameserver12( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{nameserver13} ) ) {
        push @results, $class->nameserver13( $zone );
    }

    return @results;
} ## end sub all

###
### Metadata Exposure
###

sub metadata {
    my ( $class ) = @_;

    return {
        nameserver01 => [
            qw(
              IS_A_RECURSOR
              NO_RECURSOR
              NO_RESPONSE
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver02 => [
            qw(
              BREAKS_ON_EDNS
              EDNS_RESPONSE_WITHOUT_EDNS
              EDNS_VERSION_ERROR
              EDNS0_SUPPORT
              NO_EDNS_SUPPORT
              NO_RESPONSE
              NS_ERROR
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver03 => [
            qw(
              AXFR_FAILURE
              AXFR_AVAILABLE
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver04 => [
            qw(
              DIFFERENT_SOURCE_IP
              SAME_SOURCE_IP
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver05 => [
            qw(
              AAAA_BAD_RDATA
              AAAA_QUERY_DROPPED
              AAAA_UNEXPECTED_RCODE
              AAAA_WELL_PROCESSED
              A_UNEXPECTED_RCODE
              NO_RESPONSE
              IPV4_DISABLED
              IPV6_DISABLED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver06 => [
            qw(
              CAN_NOT_BE_RESOLVED
              CAN_BE_RESOLVED
              NO_RESOLUTION
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver07 => [
            qw(
              UPWARD_REFERRAL_IRRELEVANT
              UPWARD_REFERRAL
              NO_UPWARD_REFERRAL
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver08 => [
            qw(
              QNAME_CASE_INSENSITIVE
              QNAME_CASE_SENSITIVE
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver09 => [
            qw(
              CASE_QUERY_SAME_ANSWER
              CASE_QUERY_DIFFERENT_ANSWER
              CASE_QUERY_SAME_RC
              CASE_QUERY_DIFFERENT_RC
              CASE_QUERY_NO_ANSWER
              CASE_QUERIES_RESULTS_OK
              CASE_QUERIES_RESULTS_DIFFER
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver10 => [
            qw(
              N10_NO_RESPONSE_EDNS1_QUERY
              N10_UNEXPECTED_RCODE
              N10_EDNS_RESPONSE_ERROR
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver11 => [
            qw(
              NO_RESPONSE
              NO_EDNS_SUPPORT
              UNKNOWN_OPTION_CODE
              NS_ERROR
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver12 => [
            qw(
              NO_RESPONSE
              NO_EDNS_SUPPORT
              Z_FLAGS_NOTCLEAR
              NS_ERROR
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        nameserver13 => [
            qw(
              NO_RESPONSE
              NO_EDNS_SUPPORT
              NS_ERROR
              MISSING_OPT_IN_TRUNCATED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    AAAA_BAD_RDATA => sub {
        __x    # NAMESERVER:AAAA_BAD_RDATA
            'Nameserver {ns} answered AAAA query with an unexpected RDATA length ({length} instead of 16).', @_;
    },
    AAAA_QUERY_DROPPED => sub {
        __x    # NAMESERVER:AAAA_QUERY_DROPPED
          'Nameserver {ns} dropped AAAA query.', @_;
    },
    AAAA_UNEXPECTED_RCODE => sub {
        __x    # NAMESERVER:AAAA_UNEXPECTED_RCODE
          'Nameserver {ns} answered AAAA query with an unexpected rcode ({rcode}).', @_;
    },
    AAAA_WELL_PROCESSED => sub {
        __x    # NAMESERVER:AAAA_WELL_PROCESSED
          'The following nameservers answer AAAA queries without problems : {ns_list}.', @_;
    },
    A_UNEXPECTED_RCODE => sub {
        __x    # NAMESERVER:A_UNEXPECTED_RCODE
          'Nameserver {ns} answered A query with an unexpected rcode ({rcode}).', @_;
    },
    AXFR_AVAILABLE => sub {
        __x    # NAMESERVER:AXFR_AVAILABLE
          'Nameserver {ns} allow zone transfer using AXFR.', @_;
    },
    AXFR_FAILURE => sub {
        __x    # NAMESERVER:AXFR_FAILURE
          'AXFR not available on nameserver {ns}.', @_;
    },
    BREAKS_ON_EDNS => sub {
        __x    # NAMESERVER:BREAKS_ON_EDNS
          'No response from {ns} when EDNS is used in query asking for {domain}.', @_;
    },
    CAN_BE_RESOLVED => sub {
        __x    # NAMESERVER:CAN_BE_RESOLVED
          'All nameservers succeeded to resolve to an IP address.', @_;
    },
    CAN_NOT_BE_RESOLVED => sub {
        __x    # NAMESERVER:CAN_NOT_BE_RESOLVED
          'The following nameservers failed to resolve to an IP address : {nsname_list}.', @_;
    },
    CASE_QUERIES_RESULTS_DIFFER => sub {
        __x    # NAMESERVER:CASE_QUERIES_RESULTS_DIFFER
          'When asked for {type} records on "{domain}" with different cases, all servers do not reply consistently.', @_;
    },
    CASE_QUERIES_RESULTS_OK => sub {
        __x    # NAMESERVER:CASE_QUERIES_RESULTS_OK
          'When asked for {type} records on "{domain}" with different cases, all servers reply consistently.', @_;
    },
    CASE_QUERY_DIFFERENT_ANSWER => sub {
        __x    # NAMESERVER:CASE_QUERY_DIFFERENT_ANSWER
          'When asked for {type} records on "{query1}" and "{query2}", '
          . 'nameserver {ns} returns different answers.',
          @_;
    },
    CASE_QUERY_DIFFERENT_RC => sub {
        __x    # NAMESERVER:CASE_QUERY_DIFFERENT_RC
          'When asked for {type} records on "{query1}" and "{query2}", '
          . 'nameserver {ns} returns different RCODE ("{rcode1}" vs "{rcode2}").',
          @_;
    },
    CASE_QUERY_NO_ANSWER => sub {
        __x    # NAMESERVER:CASE_QUERY_NO_ANSWER
          'When asked for {type} records on "{domain}", nameserver {ns} returns nothing.', @_;
    },
    CASE_QUERY_SAME_ANSWER => sub {
        __x    # NAMESERVER:CASE_QUERY_SAME_ANSWER
          'When asked for {type} records on "{query1}" and "{query2}", nameserver {ns} returns same answers.',
          @_;
    },
    CASE_QUERY_SAME_RC => sub {
        __x    # NAMESERVER:CASE_QUERY_SAME_RC
          'When asked for {type} records on "{query1}" and "{query2}", '
          . 'nameserver {ns} returns same RCODE "{rcode}".',
          @_;
    },
    DIFFERENT_SOURCE_IP => sub {
        __x    # NAMESERVER:DIFFERENT_SOURCE_IP
          'Nameserver {ns} replies on a SOA query with a different source address ({source}).', @_;
    },
    EDNS_RESPONSE_WITHOUT_EDNS => sub {
        __x    # NAMESERVER:EDNS_RESPONSE_WITHOUT_EDNS
          'Response without EDNS from {ns} on query with EDNS0 asking for {domain}.', @_;
    },
    EDNS_VERSION_ERROR => sub {
        __x    # NAMESERVER:EDNS_VERSION_ERROR
          'Incorrect version of EDNS (expected 0) in response from {ns} '
          . 'on query with EDNS (version 0) asking for {domain}.',
          @_;
    },
    EDNS0_SUPPORT => sub {
        __x    # NAMESERVER:EDNS0_SUPPORT
          'The following nameservers support EDNS0 : {ns_list}.', @_;
    },
    IPV4_DISABLED => sub {
        __x    # NAMESERVER:IPV4_DISABLED
          'IPv4 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IPV6_DISABLED => sub {
        __x    # NAMESERVER:IPV6_DISABLED
          'IPv6 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IS_A_RECURSOR => sub {
        __x    # NAMESERVER:IS_A_RECURSOR
          'Nameserver {ns} is a recursor.', @_;
    },
    MISSING_OPT_IN_TRUNCATED => sub {
        __x    # NAMESERVER:MISSING_OPT_IN_TRUNCATED
          'Nameserver {ns} replies on an EDNS query with a truncated response without EDNS.', @_;
    },
    NO_EDNS_SUPPORT => sub {
        __x    # NAMESERVER:NO_EDNS_SUPPORT
          'Nameserver {ns} does not support EDNS0 (replies with FORMERR).', @_;
    },
    NO_RECURSOR => sub {
        __x    # NAMESERVER:NO_RECURSOR
          'Nameserver {ns} is not a recursor.', @_;
    },
    NO_RESOLUTION => sub {
        __x    # NAMESERVER:NO_RESOLUTION
          "No nameserver was successfully resolved to an IP address.", @_;
    },
    NO_RESPONSE => sub {
        __x    # NAMESERVER:NO_RESPONSE
          'No response from {ns} asking for {domain}.', @_;
    },
    NO_UPWARD_REFERRAL => sub {
        __x    # NAMESERVER:NO_UPWARD_REFERRAL
          'None of the following nameservers returns an upward referral : {nsname_list}.', @_;
    },
    NS_ERROR => sub {
        __x    # NAMESERVER:NS_ERROR
          'Erroneous response from nameserver {ns}.', @_;
    },
    N10_NO_RESPONSE_EDNS1_QUERY => sub {
        __x    # N10_NO_RESPONSE_EDNS1_QUERY
          'No response to a query with EDNS version 1 from the following nameservers: {ns_ip_list} ', @_;
    },
    N10_UNEXPECTED_RCODE => sub {
        __x    # N10_UNEXPECTED_RCODE
          'Erroneous response with RCODE "{rcode}" (expected "BADVERS") from the following nameservers: {ns_ip_list}', @_;
    },
    N10_EDNS_RESPONSE_ERROR => sub {
        __x    # N10_EDNS_RESPONSE_ERROR
          'Expected RCODE ("BADVERS") but received erroneous response from the following nameservers: {ns_ip_list}', @_;
    },
    QNAME_CASE_INSENSITIVE => sub {
        __x    # NAMESERVER:QNAME_CASE_INSENSITIVE
          'Nameserver {ns} does not preserve original case of the queried name ({domain}).', @_;
    },
    QNAME_CASE_SENSITIVE => sub {
        __x    # NAMESERVER:QNAME_CASE_SENSITIVE
          "Nameserver {ns} preserves original case of queried names ({domain}).", @_;
    },
    SAME_SOURCE_IP => sub {
        __x    # NAMESERVER:SAME_SOURCE_IP
          'All nameservers reply with same IP used to query them.', @_;
    },
    TEST_CASE_END => sub {
        __x    # NAMESERVER:TEST_CASE_END
          'TEST_CASE_END {testcase}.', @_;
    },
    TEST_CASE_START => sub {
        __x    # NAMESERVER:TEST_CASE_START
          'TEST_CASE_START {testcase}.', @_;
    },
    UNKNOWN_OPTION_CODE => sub {
        __x    # NAMESERVER:UNKNOWN_OPTION_CODE
          'Nameserver {ns} responds with an unknown ENDS OPTION-CODE.', @_;
    },
    UPWARD_REFERRAL => sub {
        __x    # NAMESERVER:UPWARD_REFERRAL
          'Nameserver {ns} returns an upward referral.', @_;
    },
    UPWARD_REFERRAL_IRRELEVANT => sub {
        __x    # NAMESERVER:UPWARD_REFERRAL_IRRELEVANT
          'Upward referral tests skipped for root zone.', @_;
    },
    Z_FLAGS_NOTCLEAR => sub {
        __x    # NAMESERVER:Z_FLAGS_NOTCLEAR
          'Nameserver {ns} has one or more unknown EDNS Z flag bits set.', @_;
    },
);

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

sub version {
    return "$Zonemaster::Engine::Test::Nameserver::VERSION";
}

sub nameserver01 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my @nss;
    {
        my %nss = map { $_->string => $_ }
          @{ Zonemaster::Engine::TestMethods->method4( $zone ) },
          @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
        @nss = values %nss;
    }

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) ) {
        @nss = grep { $_->address->version != $IP_VERSION_6 } @nss;
    }
    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) ) {
        @nss = grep { $_->address->version != $IP_VERSION_4 } @nss;
    }

    for my $ns ( @nss ) {

        my $response_count = 0;
        my $nxdomain_count = 0;
        my $is_no_recursor = 1;
        my $has_seen_ra    = 0;
        for my $nonexistent_name ( @NONEXISTENT_NAMES ) {

            my $p = $ns->query( $nonexistent_name, q{A}, { blacklisting_disabled => 1 } );
            if ( !$p ) {
                push @results,
                  info(
                    NO_RESPONSE => {
                        ns     => $ns->string,
                        domain => $nonexistent_name,
                    }
                  );
                $is_no_recursor = 0;
            }
            else {
                $response_count++;

                if ( $p->ra ) {
                    $has_seen_ra = 1;
                }

                if ( $p->rcode eq q{NXDOMAIN} ) {
                    $nxdomain_count++;
                }
            }
        } ## end for my $nonexistent_name...

        if ( $has_seen_ra || ( $response_count > 0 && $nxdomain_count == $response_count ) ) {
            push @results, info( IS_A_RECURSOR => { ns => $ns->string } );
            $is_no_recursor = 0;
        }

        if ( $is_no_recursor ) {
            push @results, info( NO_RECURSOR => { ns => $ns->string } );
        }
    } ## end for my $ns ( @nss )

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver01

sub nameserver02 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {
        next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 );

        next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 );

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        my $p = $local_ns->query( $zone->name, q{SOA}, { edns_size => 512 } );
        if ( $p ) {
            if ( $p->rcode eq q{FORMERR} and not $p->has_edns) {
                push @results, info( NO_EDNS_SUPPORT => { ns => $local_ns->string } );
            }
            elsif ( $p->rcode eq q{NOERROR} and not $p->edns_rcode and $p->get_records( q{SOA}, q{answer} ) and $p->edns_version == 0 ) {
                $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
                next;
            }
            elsif ( $p->rcode eq q{NOERROR} and not $p->has_edns ) {
                push @results,
                  info(
                    EDNS_RESPONSE_WITHOUT_EDNS => {
                        ns     => $local_ns->string,
                        domain => $zone->name,
                    }
                  );
            }
            elsif ( $p->rcode eq q{NOERROR} and $p->has_edns and $p->edns_version != 0 ) {
                push @results,
                  info(
                    EDNS_VERSION_ERROR => {
                        ns     => $local_ns->string,
                        domain => $zone->name,
                    }
                  );
            }
            else {
                push @results, info( NS_ERROR => { ns => $local_ns->string } );
            }
        }
        else {
            my $p2 = $local_ns->query( $zone->name, q{SOA} );
            if ( $p2 ) {
                push @results,
                  info(
                    BREAKS_ON_EDNS => {
                        ns     => $local_ns->string,
                        domain => $zone->name,
                    }
                  );
            }
            else {
                push @results,
                  info(
                    NO_RESPONSE => {
                        ns     => $local_ns->string,
                        domain => $zone->name,
                    }
                  );
            }
        }

        $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar keys %nsnames_and_ip and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results,
          info(
            EDNS0_SUPPORT => {
                ns_list => join( q{;}, keys %nsnames_and_ip ),
            }
          );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver02

sub nameserver03 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 );

        next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 );

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        my $first_rr;
        eval {
            $local_ns->axfr( $zone->name, sub { ( $first_rr ) = @_; return 0; } );
            1;
        } or do {
            push @results, info( AXFR_FAILURE => { ns => $local_ns->string } );
        };

        if ( $first_rr and $first_rr->type eq q{SOA} ) {
            push @results, info( AXFR_AVAILABLE => { ns => $local_ns->string } );
        }

        $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver03

sub nameserver04 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 );

        next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 );

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        my $p = $local_ns->query( $zone->name, q{SOA} );
        if ( $p ) {
            if ( $p->answerfrom and ( $local_ns->address->short ne Zonemaster::Engine::Net::IP->new( $p->answerfrom )->short ) ) {
                push @results,
                  info(
                    DIFFERENT_SOURCE_IP => {
                        ns     => $local_ns->string,
                        source => $p->answerfrom,
                    }
                  );
            }
        }
        $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar keys %nsnames_and_ip and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results,
          info(
            SAME_SOURCE_IP => {
                names => join( q{,}, keys %nsnames_and_ip ),
            }
          );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver04

sub nameserver05 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;
    my $aaaa_issue = 0;
    my @aaaa_ok;

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) } ) {

        next if $nsnames_and_ip{ $ns->name->string . q{/} . $ns->address->short };

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{A},
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{A},
                }
              );
            next;
        }

        $nsnames_and_ip{ $ns->name->string . q{/} . $ns->address->short }++;

        my $p = $ns->query( $zone->name, q{A}, { usevc => 0 } );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns     => $ns->string,
                    domain => $zone->name,
                }
              );
        }
        elsif ( $p->rcode ne q{NOERROR} ) {
            push @results,
              info(
                A_UNEXPECTED_RCODE => {
                    ns    => $ns->string,
                    rcode => $p->rcode,
                }
              );
        }
        else {
            $p = $ns->query( $zone->name, q{AAAA}, { usevc => 0 } );

            if ( not $p ) {
                push @results,
                info( AAAA_QUERY_DROPPED => { ns => $ns->string } );
                $aaaa_issue++;
            }
            elsif ( $p->rcode ne q{NOERROR} ) {
                push @results,
                  info(
                    AAAA_UNEXPECTED_RCODE => {
                        ns    => $ns->string,
                        rcode => $p->rcode,
                    }
                  );
                $aaaa_issue++;
            }
            else {
                foreach my $rr ( $p->get_records( q{AAAA}, q{answer} ) ) {
                    if ( length($rr->rdf(0)) != 16 ) {
                        push @results,
                          info(
                            AAAA_BAD_RDATA => {
                                ns     => $ns->string,
                                length => length( $rr->rdf( 0 ) ),
                            }
                          );
                        $aaaa_issue++;
                    }
                    else {
                        push @aaaa_ok, $rr->address;    
                    }
                }
            }
        }
    }

    if ( scalar @aaaa_ok and not $aaaa_issue ) {
        push @results,
          info(
            AAAA_WELL_PROCESSED => {
                ns_list => join( q{;}, keys %nsnames_and_ip ),
            }
          );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver05

sub nameserver06 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my @all_nsnames = uniq map { lc( $_->string ) } @{ Zonemaster::Engine::TestMethods->method2( $zone ) },
      @{ Zonemaster::Engine::TestMethods->method3( $zone ) };
    my @all_nsnames_with_ip = uniq map { lc( $_->name->string ) } @{ Zonemaster::Engine::TestMethods->method4( $zone ) },
      @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my @all_nsnames_without_ip;
    my %diff;

    @diff{@all_nsnames} = undef;
    delete @diff{@all_nsnames_with_ip};

    @all_nsnames_without_ip = keys %diff;
    if ( scalar @all_nsnames_without_ip and scalar @all_nsnames_with_ip ) {
        push @results,
          info(
            CAN_NOT_BE_RESOLVED => {
                nsname_list => join( q{;}, @all_nsnames_without_ip ),
            }
          );
    }
    elsif ( not scalar @all_nsnames_with_ip ) {
        push @results,
          info(
            NO_RESOLUTION => {
                names => join( q{,}, @all_nsnames_without_ip ),
            }
          );
    }
    else {
        push @results, info( CAN_BE_RESOLVED => {} );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver06

sub nameserver07 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;
    my %nsnames;

    if ( $zone->name eq q{.} ) {
        push @results, info( UPWARD_REFERRAL_IRRELEVANT => {} );
    }
    else {
        foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) },
            @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
        {
            next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 );

            next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 );

            next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

            my $p = $local_ns->query( q{.}, q{NS}, { blacklisting_disabled => 1 } );
            if ( $p ) {
                my @ns = $p->get_records( q{NS}, q{authority} );

                if ( @ns ) {
                    push @results, info( UPWARD_REFERRAL => { ns => $local_ns->string } );
                }
            }
            $nsnames{ $local_ns->name }++;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

        if ( scalar keys %nsnames_and_ip and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
            push @results,
              info(
                NO_UPWARD_REFERRAL => {
                    nsname_list => join( q{;}, sort keys %nsnames ),
                }
              );
        }
    } ## end else [ if ( $zone->name eq q{.})]

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver07

sub nameserver08 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;
    my $original_name = q{www.} . $zone->name->string;
    my $randomized_uc_name;

    $original_name =~ s/[.]+\z//smgx;

    do {
        $randomized_uc_name = scramble_case $original_name;
    } while ( $randomized_uc_name eq $original_name );

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {
        next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 );

        next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 );

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        my $p = $local_ns->query( $randomized_uc_name, q{SOA} );

        if ( $p and my ( $qrr ) = $p->question() ) {
            my $qrr_name = $qrr->name();
            $qrr_name =~ s/\.\z//smgx;
            if ( $qrr_name eq $randomized_uc_name ) {
                push @results,
                  info(
                    QNAME_CASE_SENSITIVE => {
                        ns     => $local_ns->string,
                        domain => $randomized_uc_name,
                    }
                  );
            }
            else {
                push @results,
                  info(
                    QNAME_CASE_INSENSITIVE => {
                        ns     => $local_ns->string,
                        domain => $randomized_uc_name,
                    }
                  );
            }
        } ## end if ( $p and my ( $qrr ...))
        $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver08

sub nameserver09 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %nsnames_and_ip;
    my $original_name = q{www.} . $zone->name->string;
    my $record_type   = q{SOA};
    my $randomized_uc_name1;
    my $randomized_uc_name2;
    my $all_results_match = 1;

    $original_name =~ s/[.]+\z//smgx;

    do {
        $randomized_uc_name1 = scramble_case $original_name;
    } while ( $randomized_uc_name1 eq $original_name );

    do {
        $randomized_uc_name2 = scramble_case $original_name;
    } while ( $randomized_uc_name2 eq $original_name or $randomized_uc_name2 eq $randomized_uc_name1 );

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {
        next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $local_ns->address->version == $IP_VERSION_6 );

        next if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $local_ns->address->version == $IP_VERSION_4 );

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        my $p1 = $local_ns->query( $randomized_uc_name1, $record_type );
        my $p2 = $local_ns->query( $randomized_uc_name2, $record_type );

        my $answer1_string = q{};
        my $answer2_string = q{};
        my $json = JSON::PP->new->canonical->pretty;
        if ( $p1 and scalar $p1->answer ) {

            my @answer1 = map { lc $_->string } sort $p1->answer;
            $answer1_string = $json->encode( \@answer1 );

            if ( $p2 and scalar $p2->answer ) {

                my @answer2 = map { lc $_->string } sort $p2->answer;
                $answer2_string = $json->encode( \@answer2 );
            }

            if ( $answer1_string eq $answer2_string ) {
                push @results,
                  info(
                    CASE_QUERY_SAME_ANSWER => {
                        ns     => $local_ns->string,
                        type   => $record_type,
                        query1 => $randomized_uc_name1,
                        query2 => $randomized_uc_name2,
                    }
                  );
            }
            else {
                $all_results_match = 0;
                push @results,
                  info(
                    CASE_QUERY_DIFFERENT_ANSWER => {
                        ns     => $local_ns->string,
                        type   => $record_type,
                        query1 => $randomized_uc_name1,
                        query2 => $randomized_uc_name2,
                    }
                  );
            }

        } ## end if ( $p1 and scalar $p1...)
        elsif ( $p1 and $p2 ) {

            if ( $p1->rcode eq $p2->rcode ) {
                push @results,
                  info(
                    CASE_QUERY_SAME_RC => {
                        ns     => $local_ns->string,
                        type   => $record_type,
                        query1 => $randomized_uc_name1,
                        query2 => $randomized_uc_name2,
                        rcode  => $p1->rcode,
                    }
                  );
            }
            else {
                $all_results_match = 0;
                push @results,
                  info(
                    CASE_QUERY_DIFFERENT_RC => {
                        ns     => $local_ns->string,
                        type   => $record_type,
                        query1 => $randomized_uc_name1,
                        query2 => $randomized_uc_name2,
                        rcode1 => $p1->rcode,
                        rcode2 => $p2->rcode,
                    }
                  );
            }

        } ## end elsif ( $p1 and $p2 )
        elsif ( $p1 or $p2 ) {
            $all_results_match = 0;
            push @results,
              info(
                CASE_QUERY_NO_ANSWER => {
                    ns     => $local_ns->string,
                    type   => $record_type,
                    domain => $p1 ? $randomized_uc_name1 : $randomized_uc_name2,
                }
              );
        }

        $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( $all_results_match ) {
        push @results,
          info(
            CASE_QUERIES_RESULTS_OK => {
                type   => $record_type,
                domain => $original_name,
            }
          );
    }
    else {
        push @results,
          info(
            CASE_QUERIES_RESULTS_DIFFER => {
                type   => $record_type,
                domain => $original_name,
            }
          );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver09

sub nameserver10 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my @no_response_edns1;
    my %unexpected_rcode;
    my @edns_response_error;

    my @nss;
    {
        my %nss = map { $_->string => $_ }
          @{ Zonemaster::Engine::TestMethods->method4( $zone ) },
          @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
        @nss = values %nss;
    }

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) ) {
        @nss = grep { $_->address->version != $IP_VERSION_6 } @nss;
    }
    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) ) {
        @nss = grep { $_->address->version != $IP_VERSION_4 } @nss;
    }

    for my $ns ( @nss ) {
        my $p = $ns->query( $zone->name, q{SOA}, { edns_details => { version => 0 } } );
        
        if ( $p and $p->rcode eq q{NOERROR} ){
            my $p2 = $ns->query( $zone->name, q{SOA}, { edns_details => { version => 1 } } );
            
            if ( $p2 ) {
                if ( $p2->rcode ne q{BADVERS} ) {
                    push @{ $unexpected_rcode{$p->rcode} }, $ns->address->short;
                }
                elsif ( $p2->rcode eq q{BADVERS} and $p2->edns_version == 0 and not scalar $p2->answer){
                    next;
                }
                else {
                    push @edns_response_error, $ns->address->short;
                }
            }
            else {
                push @no_response_edns1, $ns->address->short;
            }
        }
    }

    if ( scalar @no_response_edns1 ){
        push @results,
            info(
                N10_NO_RESPONSE_EDNS1_QUERY => {
                    ns_ip_list => join ( q{;}, uniq sort @no_response_edns1 )
                }
            );
    }

    if ( scalar keys %unexpected_rcode ){
        push @results, map {
            info(
                N10_UNEXPECTED_RCODE => {
                    rcode     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $unexpected_rcode{$_} } )
                }
            )
        } keys %unexpected_rcode;
    }

    if ( scalar @edns_response_error ){
        push @results,
            info(
                N10_EDNS_RESPONSE_ERROR => {
                    ns_ip_list => join ( q{;}, uniq sort @edns_response_error )
                }
            );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver10

sub nameserver11 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my @nss;
    {
        my %nss = map { $_->string => $_ }
          @{ Zonemaster::Engine::TestMethods->method4( $zone ) },
          @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
        @nss = values %nss;
    }

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) ) {
        @nss = grep { $_->address->version != $IP_VERSION_6 } @nss;
    }
    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) ) {
        @nss = grep { $_->address->version != $IP_VERSION_4 } @nss;
    }

    # Choose an unassigned EDNS0 Option Codes
    # values 15-26945 are Unassigned. Let's say we use 137 ???
    my $opt_code = 137;
    my $opt_data = q{};
    my $opt_length = length($opt_data);
    my $rdata = $opt_code*65536 + $opt_length;

    for my $ns ( @nss ) {
        my $p = $ns->query( $zone->name, q{SOA}, { edns_details => { data => $rdata } } );
        if ( $p ) {
            if ( $p->rcode eq q{FORMERR} and not $p->edns_rcode ) {
                push @results, info( NO_EDNS_SUPPORT => { ns => $ns->string } );
            }
            elsif ( defined $p->edns_data ) {
                push @results, info( UNKNOWN_OPTION_CODE => { ns => $ns->string } );
            }
            elsif ( $p->rcode eq q{NOERROR} and not $p->edns_rcode and $p->edns_version == 0 and not defined $p->edns_data and $p->get_records( q{SOA}, q{answer} ) ) {
                next;
            }
            else {
                push @results, info( NS_ERROR => { ns => $ns->string, } );
            }
        }
        else {
            push @results,
              info(
                NO_RESPONSE => {
                    ns     => $ns->string,
                    domain => $zone->name,
                }
              );
        }

    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver11

sub nameserver12 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my @nss;
    {
        my %nss = map { $_->string => $_ }
          @{ Zonemaster::Engine::TestMethods->method4( $zone ) },
          @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
        @nss = values %nss;
    }

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) ) {
        @nss = grep { $_->address->version != $IP_VERSION_6 } @nss;
    }
    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) ) {
        @nss = grep { $_->address->version != $IP_VERSION_4 } @nss;
    }

    for my $ns ( @nss ) {
        my $p = $ns->query( $zone->name, q{SOA}, { edns_details => { z => 3 } } );
        if ( $p ) {
            if ( $p->rcode eq q{FORMERR} and not $p->edns_rcode ) {
                push @results, info( NO_EDNS_SUPPORT => { ns => $ns->string } );
            }
            elsif ( $p->edns_z ) {
                push @results, info( Z_FLAGS_NOTCLEAR => { ns => $ns->string } );
            }
            elsif ( $p->rcode eq q{NOERROR} and not $p->edns_rcode and $p->edns_version == 0 and $p->edns_z == 0 and $p->get_records( q{SOA}, q{answer} ) ) {
                next;
            }
            else {
                push @results, info( NS_ERROR => { ns => $ns->string } );
            }
        }
        else {
            push @results,
              info(
                NO_RESPONSE => {
                    ns     => $ns->string,
                    domain => $zone->name,
                }
              );
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver12

sub nameserver13 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my @nss;
    {
        my %nss = map { $_->string => $_ }
          @{ Zonemaster::Engine::TestMethods->method4( $zone ) },
          @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
        @nss = values %nss;
    }

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) ) {
        @nss = grep { $_->address->version != $IP_VERSION_6 } @nss;
    }
    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) ) {
        @nss = grep { $_->address->version != $IP_VERSION_4 } @nss;
    }

    for my $ns ( @nss ) {
        my $p = $ns->query( $zone->name, q{SOA}, { usevc => 0, fallback => 0, edns_details => { do => 1, udp_size => 512  } } );
        if ( $p ) {
            if ( $p->rcode eq q{FORMERR} and not $p->edns_rcode ) {
                push @results, info( NO_EDNS_SUPPORT => { ns => $ns->string, } );
            }
            elsif ( $p->tc and not $p->has_edns ) {
                push @results, info( MISSING_OPT_IN_TRUNCATED => { ns => $ns->string } );
            }
            elsif ( $p->rcode eq q{NOERROR} and not $p->edns_rcode and $p->edns_version == 0 ) {
                next;
            }
            else {
                push @results, info( NS_ERROR => { ns => $ns->string } );
            }
        }
        else {
            push @results,
              info(
                NO_RESPONSE => {
                    ns     => $ns->string,
                    domain => $zone->name,
                }
              );
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub nameserver13

1;

=head1 NAME

Zonemaster::Engine::Test::Nameserver - module implementing tests of the properties of a name server

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Nameserver->all($zone);

=head1 METHODS

=over

=item all($zone)

Runs the default set of tests and returns a list of log entries made by the tests

=item tag_descriptions()

Returns a refernce to a hash with translation functions. Used by the builtin translation system.

=item metadata()

Returns a reference to a hash, the keys of which are the names of all test methods in the module, and the corresponding values are references to
lists with all the tags that the method can use in log entries.

=item version()

Returns a version string for the module.

=back

=head1 TESTS

=over

=item nameserver01($zone)

Verify that nameserver is not recursive.

=item nameserver02($zone)

Verify EDNS0 support.

=item nameserver03($zone)

Verify that zone transfer (AXFR) is not available.

=item nameserver04($zone)

Verify that replies from nameserver comes from the expected IP address.

=item nameserver05($zone)

Verify behaviour against AAAA queries.

=item nameserver06($zone)

Verify that each nameserver can be resolved to an IP address.

=item nameserver07($zone)

Check whether authoritative name servers return an upward referral.

=item nameserver08($zone)

Check whether authoritative name servers responses match the case of every letter in QNAME.

=item nameserver09($zone)

Check whether authoritative name servers return same results for equivalent names with different cases in the request.

=item nameserver10($zone)

Check whether authoritative name servers respond correctly to queries with undefined EDNS version.

=item nameserver11($zone)

Check whether authoritative name servers responses doe not include unknown EDNS OPTION-CODE used in query.

=item nameserver12($zone)

Check whether authoritative name servers responses has "Z" bits cleared even if they are set in the query.

=item nameserver13($zone)

This Test Case will try to verify that if the response to a query with an OPT record is truncated, then the response will contain an OPT record.

=back

=cut
