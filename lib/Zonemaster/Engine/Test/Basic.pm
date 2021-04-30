package Zonemaster::Engine::Test::Basic;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare("v1.0.16");

use Zonemaster::Engine;

use Carp;
use List::MoreUtils qw[any none];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Constants qw[:ip :name];
use Zonemaster::Engine::Test::Address;
use Zonemaster::Engine::Test::Syntax;
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Util;

###
### Entry Points
###

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    push @results, $class->basic00( $zone );

    if (
        none {
            $_->tag eq q{DOMAIN_NAME_LABEL_TOO_LONG}
              or $_->tag eq q{DOMAIN_NAME_ZERO_LENGTH_LABEL}
              or $_->tag eq q{DOMAIN_NAME_TOO_LONG}
        }
        @results
      )
    {
        push @results, $class->basic01( $zone );

        push @results, $class->basic02( $zone );

        # Perform BASIC3 if BASIC2 failed
        if ( none { $_->tag eq q{HAS_NAMESERVERS} } @results ) {
            push @results, $class->basic03( $zone ) if Zonemaster::Engine::Util::should_run_test( q{basic03} );
        }
        else {
            push @results,
              info(
                HAS_NAMESERVER_NO_WWW_A_TEST => {
                    zname => $zone->name,
                }
              );
        }

        push @results, $class->basic04( $zone );

    } ## end if ( none { $_->tag eq...})

    return @results;
} ## end sub all

sub can_continue {
    my ( $class, @results ) = @_;
    my %tag = map { $_->tag => 1 } @results;

    if ( not $tag{NO_GLUE_PREVENTS_NAMESERVER_TESTS} and $tag{HAS_NAMESERVERS} ) {
        return 1;
    }
    else {
        return;
    }
}

###
### Metadata Exposure
###

sub metadata {
    my ( $class ) = @_;

    return {
        basic00 => [
            qw(
              DOMAIN_NAME_LABEL_TOO_LONG
              DOMAIN_NAME_ZERO_LENGTH_LABEL
              DOMAIN_NAME_TOO_LONG
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        basic01 => [
            qw(
              NO_PARENT
              HAS_PARENT
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        basic02 => [
            qw(
              NO_GLUE_PREVENTS_NAMESERVER_TESTS
              NS_FAILED
              NS_NO_RESPONSE
              HAS_NAMESERVERS
              IPV4_DISABLED
              IPV6_DISABLED
              IPV4_ENABLED
              IPV6_ENABLED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        basic03 => [
            qw(
              A_QUERY_NO_RESPONSES
              HAS_A_RECORDS
              IPV4_DISABLED
              IPV4_ENABLED
              IPV6_DISABLED
              IPV6_ENABLED
              NO_A_RECORDS
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        basic04 => [
            qw(
              B04_MISSING_NS_RECORD
              B04_MISSING_SOA_RECORD
              B04_NO_RESPONSE
              B04_NO_RESPONSE_NS_QUERY
              B04_NO_RESPONSE_SOA_QUERY
              B04_NS_RECORD_NOT_AA
              B04_RESPONSE_TCP_NOT_UDP
              B04_SOA_RECORD_NOT_AA
              B04_UNEXPECTED_RCODE_NS_QUERY
              B04_UNEXPECTED_RCODE_SOA_QUERY
              B04_WRONG_NS_RECORD
              B04_WRONG_SOA_RECORD
              IPV4_DISABLED
              IPV4_ENABLED
              IPV6_DISABLED
              IPV6_ENABLED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    A_QUERY_NO_RESPONSES => sub {
        __x    # BASIC:A_QUERY_NO_RESPONSES
          'Nameservers did not respond to A query.';
    },
    B04_MISSING_NS_RECORD => sub {
        __x    # BASIC:B04_MISSING_NS_RECORD
          'Nameserver {ns} repond to a NS query with no records in answer.', @
    },
    B04_MISSING_SOA_RECORD => sub {
        __x    # BASIC:B04_MISSING_SOA_RECORD
          'Nameserver {ns} repond to a SOA query with no records in answer.', @_;
    },
    B04_NO_RESPONSE => sub {
        __x    # BASIC:B04_NO_RESPONSE
          'Nameserver {ns} did not respond over UDP and TCP.', @_;
    },
    B04_NO_RESPONSE_NS_QUERY => sub {
        __x    # BASIC:B04_NO_RESPONSE_NS_QUERY
          'No response from nameserver {ns} on NS queries.', @_;
    },
    B04_NO_RESPONSE_SOA_QUERY => sub {
        __x    # BASIC:B04_NO_RESPONSE_SOA_QUERY
          'No response from nameserver {ns} on SOA queries.', @_;
    },
    B04_NS_RECORD_NOT_AA => sub {
        __x    # BASIC:B04_NS_RECORD_NOT_AA
          'Nameserver {ns} response is not authoritative on NS query.', @_;
    },
    B04_RESPONSE_TCP_NOT_UDP => sub {
        __x    # BASIC:B04_RESPONSE_TCP_NOT_UDP
          'Nameserver {ns} did not respond over UDP.', @_;
    },
    B04_SOA_RECORD_NOT_AA => sub {
        __x    # BASIC:B04_SOA_RECORD_NOT_AA
          'Nameserver {ns} response is not authoritative on SOA query.', @_;
    },
    B04_UNEXPECTED_RCODE_NS_QUERY => sub {
        __x    # BASIC:B04_UNEXPECTED_RCODE_NS_QUERY
          'Nameserver {ns} responds with an unexpected RCODE ({rcode}) on a NS query.', @_;
    },
    B04_UNEXPECTED_RCODE_SOA_QUERY => sub {
        __x    # BASIC:B04_UNEXPECTED_RCODE_SOA_QUERY
          'Nameserver {ns} responds with an unexpected RCODE ({rcode}) on a SOA query.', @_;
    },
    B04_WRONG_NS_RECORD => sub {
        __x    # BASIC:B04_WRONG_NS_RECORD
          'Nameserver {ns} responds with a wrong owner name ({owner} instead of {name}) on NS queries.', @_;
    },
    B04_WRONG_SOA_RECORD => sub {
        __x    # BASIC:B04_WRONG_SOA_RECORD
          'Nameserver {ns} responds with a wrong owner name ({owner} instead of {name}) on SOA queries.', @_;
    },
    DOMAIN_NAME_LABEL_TOO_LONG => sub {
        __x    # BASIC:DOMAIN_NAME_LABEL_TOO_LONG
          'Domain name ({domain}) has a label ({dlabel}) too long ({dlength}/{max}).', @_;
    },
    DOMAIN_NAME_TOO_LONG => sub {
        __x    # BASIC:DOMAIN_NAME_TOO_LONG
          'Domain name is too long ({fqdnlength}/{max}).', @_;
    },
    DOMAIN_NAME_ZERO_LENGTH_LABEL => sub {
        __x    # BASIC:DOMAIN_NAME_ZERO_LENGTH_LABEL
          'Domain name ({domain}) has a zero-length label.', @_;
    },
    HAS_A_RECORDS => sub {
        __x    # BASIC:HAS_A_RECORDS
          'Nameserver {ns} returned "A" record(s) for {domain}.', @_;
    },
    HAS_NAMESERVER_NO_WWW_A_TEST => sub {
        __x    # BASIC:HAS_NAMESERVER_NO_WWW_A_TEST
          'Functional nameserver found. "A" query for www.{zname} test skipped.', @_;
    },
    HAS_NAMESERVERS => sub {
        __x    # BASIC:HAS_NAMESERVERS
          'Nameserver {ns} listed these servers as glue: {nsnlist}.', @_;
    },
    HAS_PARENT => sub {
        __x    # BASIC:HAS_PARENT
          'Parent domain \'{pname}\' was found for the tested domain.', @_;
    },
    IPV4_DISABLED => sub {
        __x    # BASIC:IPV4_DISABLED
          'IPv4 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IPV4_ENABLED => sub {
        __x    # BASIC:IPV4_ENABLED
          'IPv4 is enabled, can send "{rrtype}" query to {ns}.', @_;
    },
    IPV6_DISABLED => sub {
        __x    # BASIC:IPV6_DISABLED
          'IPv6 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IPV6_ENABLED => sub {
        __x    # BASIC:IPV6_ENABLED
          'IPv6 is enabled, can send "{rrtype}" query to {ns}.', @_;
    },
    NO_A_RECORDS => sub {
        __x    # BASIC:NO_A_RECORDS
          'Nameserver {ns} did not return "A" record(s) for {domain}.', @_;
    },
    NO_GLUE_PREVENTS_NAMESERVER_TESTS => sub {
        __x    # BASIC:NO_GLUE_PREVENTS_NAMESERVER_TESTS
          'No NS records for tested zone from parent. NS tests skipped.', @_;
    },
    NO_PARENT => sub {
        __x    # BASIC:NO_PARENT
          'No parent domain could be found for the domain under test.', @_;
    },
    NS_FAILED => sub {
        __x    # BASIC:NS_FAILED
          'Nameserver {ns} did not return NS records. RCODE was {rcode}.', @_;
    },
    NS_NO_RESPONSE => sub {
        __x    # BASIC:NS_NO_RESPONSE
          'Nameserver {ns} did not respond to NS query.', @_;
    },
    TEST_CASE_END => sub {
        __x    # BASIC:TEST_CASE_END
          'TEST_CASE_END {testcase}.', @_;
    },
    TEST_CASE_START => sub {
        __x    # BASIC:TEST_CASE_START
          'TEST_CASE_START {testcase}.', @_;
    },
);

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

sub version {
    return "$Zonemaster::Engine::Test::Basic::VERSION";
}

###
### Tests
###

sub basic00 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my $name = name( $zone );

    foreach my $local_label ( @{ $name->labels } ) {
        if ( length $local_label > $LABEL_MAX_LENGTH ) {
            push @results,
              info(
                q{DOMAIN_NAME_LABEL_TOO_LONG} => {
                    domain  => "$name",
                    dlabel  => $local_label,
                    dlength => length( $local_label ),
                    max     => $LABEL_MAX_LENGTH,
                }
              );
        }
        elsif ( length $local_label == 0 ) {
            push @results,
              info(
                q{DOMAIN_NAME_ZERO_LENGTH_LABEL} => {
                    domain => "$name",
                }
              );
        }
    } ## end foreach my $local_label ( @...)

    my $fqdn = $name->fqdn;
    if ( length( $fqdn ) > $FQDN_MAX_LENGTH ) {
        push @results,
          info(
            q{DOMAIN_NAME_TOO_LONG} => {
                fqdn       => $fqdn,
                fqdnlength => length( $fqdn ),
                max        => $FQDN_MAX_LENGTH,
            }
          );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );

} ## end sub basic00

sub basic01 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my $parent = $zone->parent;

    if ( not $parent ) {
        push @results,
          info(
            NO_PARENT => {
                zone => $zone->name->string,
            }
          );
    }
    else {
        push @results,
          info(
            HAS_PARENT => {
                zone  => $zone->name->string,
                pname => $parent->name->string,
            }
          );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub basic01

sub basic02 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my $query_type = q{NS};
    my @ns = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };

    if ( not scalar @ns ) {
        push @results,
          info(
            NO_GLUE_PREVENTS_NAMESERVER_TESTS => {}
          );
    }

    foreach my $ns ( @ns ) {
        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }
        elsif ( Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_ENABLED => {
                    ns     => $ns->string,
                    rrtype => $query_type,
                }
              );
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }
        elsif ( Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_ENABLED => {
                    ns     => $ns->string,
                    rrtype => $query_type,
                }
              );
        }

        my $p = $ns->query( $zone->name, $query_type );

        if ( $p ) {
            if ( $p->has_rrs_of_type_for_name( $query_type, $zone->name ) ) {
                push @results,
                  info(
                    HAS_NAMESERVERS => {
                        nsnlist =>
                          join( q{,}, sort map { $_->nsdname } $p->get_records_for_name( $query_type, $zone->name ) ),
                        ns => $ns->string,
                    }
                  );
            }
            else {
                push @results,
                  info(
                    NS_FAILED => {
                        ns    => $ns->string,
                        rcode => $p->rcode,
                    }
                  );
            }
        } ## end if ( $p )
        else {
            push @results, info( NS_NO_RESPONSE => { ns => $ns->string } );
        }
    } ## end foreach my $ns ( @{ Zonemaster::Engine::TestMethods...})

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub basic02

sub basic03 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my $query_type = q{A};

    my $name        = q{www.} . $zone->name;
    my $response_nb = 0;
    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) } ) {
        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }
        elsif ( Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_ENABLED => {
                    ns     => $ns->string,
                    rrtype => $query_type,
                }
              );
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $query_type,
                }
              );
            next;
        }
        elsif ( Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_ENABLED => {
                    ns     => $ns->string,
                    rrtype => $query_type,
                }
              );
        }

        my $p = $ns->query( $name, $query_type );
        next if not $p;
        $response_nb++;
        if ( $p->has_rrs_of_type_for_name( $query_type, $name ) ) {
            push @results,
              info(
                HAS_A_RECORDS => {
                    ns     => $ns->string,
                    domain => $name,
                }
              );
        }
        else {
            push @results,
              info(
                NO_A_RECORDS => {
                    ns     => $ns->string,
                    domain => $name,
                }
              );
        }
    } ## end foreach my $ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar( @{ Zonemaster::Engine::TestMethods->method4( $zone ) } ) and not $response_nb ) {
        push @results, info( A_QUERY_NO_RESPONSES => {} );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub basic03

sub basic04 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my $name = name( $zone );
    my @query_types = qw{SOA NS};
    my @ns = @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) };

    foreach my $ns ( @ns ) {
        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results, map {
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              )
            } @query_types;
            next;
        }
        elsif ( Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results, map {
              info(
                IPV4_ENABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              )
            } @query_types;
        }


        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results, map {
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              )
            } @query_type;
            next;
        }
        elsif ( Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results, map {
              info(
                IPV6_ENABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              )
            } @query_type;
        }

        my $p_soa_udp = $ns->query( $name, q{SOA}, { usevc => 0 } );
        my $p_ns_udp  = $ns->query( $name, q{NS}, { usevc => 0 } );

        if ( not $p_soa_udp and not $p_ns_udp ) {
            my $p_soa_tcp = $ns->query( $name, q{SOA}, { usevc => 1 } );
            if ( not $p_soa_tcp ) {
                push @results,
                  info(
                    B04_NO_RESPONSE => {
                        ns => $ns->string
                    }
                  );
            }
            else {
                push @results,
                  info(
                    B04_RESPONSE_TCP_NOT_UDP => {
                        ns => $ns->string
                    }
                  );
            }
        }
        else {
            if ( not $p_soa_udp ) {
                push @results,
                  info(
                    B04_NO_RESPONSE_SOA_QUERY => {
                        ns => $ns->string
                    }
                  );
            }
            else {
                if ( $p_soa_udp->rcode ne q{NOERROR} ) {
                    push @results,
                      info(
                        B04_UNEXPECTED_RCODE_SOA_QUERY => {
                            ns => $ns->string,
                            rcode => $p_soa_udp->rcode
                        }
                      );
                }
                else {
                    my ( $soa ) = $p_soa_udp->get_records( q{SOA}, q{answer} );
                    if ( not $soa ) {
                        push @results,
                          info(
                            B04_MISSING_SOA_RECORD => {
                                ns => $ns->string
                            }
                          );
                    }
                    else {
                        if ( lc($soa->owner) ne lc($name->fqdn) ) {
                            push @results,
                              info(
                                B04_WRONG_SOA_RECORD => {
                                    ns    => $ns->string,
                                    owner => lc($soa->owner),
                                    name  => lc($name->fqdn)
                                }
                              );
                        }
                        elsif ( not $p_soa_udp->aa ) {
                            push @results,
                              info(
                                B04_SOA_RECORD_NOT_AA => {
                                    ns => $ns->string
                                }
                              );
                        }
                    }
                }
            }
            if ( not $p_ns_udp ) {
                push @results,
                  info(
                    B04_NO_RESPONSE_NS_QUERY => {
                        ns => $ns->string
                    }
                  );
            }
            else {
                if ( $p_ns_udp->rcode ne q{NOERROR} ) {
                    push @results,
                      info(
                        B04_UNEXPECTED_RCODE_NS_QUERY => {
                            ns    => $ns->string,
                            rcode => $p_ns_udp->rcode
                        }
                      );
                }
                else {
                    my ( $ns ) = $p_ns_udp->get_records( q{NS}, q{answer} );
                    if ( not $ns ) {
                        push @results,
                          info(
                            B04_MISSING_NS_RECORD => {
                                ns => $ns->string
                            }
                          );
                    }
                    else {
                        if ( lc($ns->owner) ne lc($name->fqdn) ) {
                            push @results,
                              info(
                                B04_WRONG_NS_RECORD => {
                                    ns    => $ns->string,
                                    owner => lc($ns->owner),
                                    name  => lc($name->fqdn)
                                }
                              );
                        }
                        elsif ( not $p_ns_udp->aa ) {
                            push @results,
                              info(
                                B04_NS_RECORD_NOT_AA => {
                                    ns => $ns->string
                                }
                              );
                        }
                    }
                }
            }
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub basic04

1;

=head1 NAME

Zonemaster::Engine::Test::Basic - module implementing test for very basic domain functionality

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Basic->all($zone);

=head1 METHODS

=over

=item all($zone)

Runs between one and three tests, depending on the zone. If L<basic01> passes, L<basic02> is run. If L<basic02> fails, L<basic03> is run.

=item metadata()

Returns a reference to a hash, the keys of which are the names of all test methods in the module, and the corresponding values are references to
lists with all the tags that the method can use in log entries.

=item tag_descriptions()

Returns a refernce to a hash with translation functions. Used by the builtin translation system.

=item version()

Returns a version string for the module.

=item can_continue(@results)

Looks at the provided log entries and returns true if they indicate that further testing of the relevant zone is possible.

=back

=head1 TESTS

=over

=item basic00

Checks if the domain name to be tested is valid. Not all syntax tests are done here, it "just" checks domain name total length and labels length.
In case of failure, all other tests are aborted.

=item basic01

Checks that we can find a parent zone for the zone we're testing. If we can't, no further testing is done.

=item basic02

Checks that the nameservers for the parent zone returns NS records for the tested zone, and that at least one of the nameservers thus pointed out
responds sensibly to an NS query for the tested zone.

=item basic03

Checks if at least one of the nameservers pointed out by the parent zone gives a useful response when sent an A query for the C<www> label in the
tested zone (that is, if we're testing C<example.org> this test will as for A records for C<www.example.org>). This test is only run if the
L<basic02> test has I<failed>.

=item basic04

Query all nameservers pointed out by the parent zone or found in delegation for NS and/or SOA records. Initially done in several
test cases, these tests should be done only here.

=back

=cut
