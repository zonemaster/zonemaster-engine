package Zonemaster::Engine::Test::Basic;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare("v1.0.19");

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
        if ( none { $_->tag eq q{B02_AUTH_RESPONSE_SOA} } @results ) {
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

    } ## end if ( none { $_->tag eq...})

    return @results;
} ## end sub all

sub can_continue {
    my ( $class, @results ) = @_;
    my %tag = map { $_->tag => 1 } @results;

    if ( not $tag{B02_NO_DELEGATION} and $tag{B02_AUTH_RESPONSE_SOA} ) {
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
              B02_AUTH_RESPONSE_SOA
              B02_NO_DELEGATION
              B02_NO_WORKING_NS
              B02_NS_BROKEN
              B02_NS_NOT_AUTH
              B02_NS_NO_IP_ADDR
              B02_NS_NO_RESPONSE
              B02_UNEXPECTED_RCODE
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
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    BASIC00 => sub {
        __x    # BASIC:BASIC00
          'Domain name must be valid', @_;
    },
    BASIC01 => sub {
        __x    # BASIC:BASIC01
          'The domain must have a parent domain', @_;
    },
    BASIC02 => sub {
        __x    # BASIC:BASIC02
          'The domain must have at least one working name server', @_;
    },
    BASIC03 => sub {
        __x    # BASIC:BASIC03
          'The Broken but functional test', @_;
    },
    BASIC04 => sub {
        __x    # BASIC:BASIC04
          'Test of basic nameserver and zone functionality', @_;
    },
    A_QUERY_NO_RESPONSES => sub {
        __x    # BASIC:A_QUERY_NO_RESPONSES
          'Nameservers did not respond to A query.';
    },
    B02_AUTH_RESPONSE_SOA => sub {
        __x    # BASIC:B02_AUTH_RESPONSE_SOA
          'Authoritative answer on SOA query for "{domain}" is returned by name servers "{ns_list}".', @_;
    },
    B02_NO_DELEGATION => sub {
        __x    # BASIC:B02_NO_DELEGATION
          'There is no delegation (name servers) for "{domain}" which means it does not exist as a zone.', @_;
    },
    B02_NO_WORKING_NS => sub {
        __x    # BASIC:B02_NO_WORKING_NS
          'There is no working name server for "{domain}" so it is unreachable.', @_;
    },
    B02_NS_BROKEN => sub {
        __x    # BASIC:B02_NS_BROKEN
          'Broken response from name server "{ns}" on an SOA query.', @_;
    },
    B02_NS_NOT_AUTH => sub {
        __x    # BASIC:B02_NS_NOT_AUTH
          'Name server "{ns}" does not give an authoritative answer on an SOA query.', @_;
    },
    B02_NS_NO_IP_ADDR => sub {
        __x    # BASIC:B02_NS_NO_IP_ADDR
          'Name server "{nsname}" cannot be resolved into an IP address.', @_;
    },
    B02_NS_NO_RESPONSE => sub {
        __x    # BASIC:B02_NS_NO_RESPONSE
          'Name server "{ns}" does not respond to an SOA query.', @_;
    },
    B02_UNEXPECTED_RCODE => sub {
        __x    # BASIC:B02_UNEXPECTED_RCODE
          'Name server "{ns}" responds with an unexpected RCODE name ("{rcode}") on an SOA query.', @_;
    },
    DOMAIN_NAME_LABEL_TOO_LONG => sub {
        __x    # BASIC:DOMAIN_NAME_LABEL_TOO_LONG
          'Domain name ({domain}) has a label ({label}) too long ({dlength}/{max}).', @_;
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
    NO_PARENT => sub {
        __x    # BASIC:NO_PARENT
          'No parent domain could be found for the domain under test.', @_;
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

sub _ip_disabled_message {
    my ( $results_array, $ns, @rrtypes ) = @_;

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
        push @$results_array, map {
          info(
            IPV4_DISABLED => {
                ns     => $ns->string,
                rrtype => $_,
            }
          )
        } @rrtypes;
        return 1;
    }

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
        push @$results_array, map {
          info(
            IPV6_DISABLED => {
                ns     => $ns->string,
                rrtype => $_,
            }
          )
        } @rrtypes;
        return 1;
    }
    return 0;
}

sub _ip_enabled_message {
    my ( $results_array, $ns, @rrtypes ) = @_;

    if ( Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
        push @$results_array, map {
          info(
            IPV4_ENABLED => {
                ns     => $ns->string,
                rrtype => $_,
            }
          )
        } @rrtypes;
    }

    if ( Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
        push @$results_array, map {
          info(
            IPV6_ENABLED => {
                ns     => $ns->string,
                rrtype => $_,
            }
          )
        } @rrtypes;
    }
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
                    label  => $local_label,
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
    
    my $query_type = q{SOA};

    my %auth_response_soa;
    my %ns_broken;
    my %ns_not_auth;
    my %ns_cant_resolve;
    my %ns_no_response;
    my %unexpected_rcode;

    my @ns = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };

    if ( not scalar @ns ) {
        push @results,
            info(
                B02_NO_DELEGATION => {
                    domain => $zone->name
                }
            );
            
        return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
    }

    foreach my $ns ( @ns ) {
        if ( _ip_disabled_message( \@results, $ns, $query_type ) ) {
            next;
        }
        _ip_enabled_message( \@results, $ns, $query_type );

        # This is not a realistical conditional check considering the current implementation of Engine::Nameserver.
        # Any Engine::Nameserver object created will (must) have an IP address. So it is here as a placeholder.
        if ( not $ns->address ) {
            $ns_cant_resolve{$ns->name} = 1;
            next;
        }

        my $p = $ns->query( $zone->name, $query_type );

        if ( $p ) {
            if ( not $p->aa ) {
                $ns_not_auth{$ns->string} = 1;
            }
            elsif ( $p->rcode ne 'NOERROR' ) {
                $unexpected_rcode{$ns->string} = $p->rcode;
            }
            else {
                if ( $p->get_records_for_name( $query_type, $zone->name, q{answer} ) ) {
                    $auth_response_soa{$ns->string} = 1;
                }
                else {
                    $ns_broken{$ns->string} = 1;
                }
            }
        }
        else {
            $ns_no_response{$ns->string} = 1;
        }
    }

    if ( scalar keys %auth_response_soa ) {
        push @results,
            info(
                B02_AUTH_RESPONSE_SOA => {
                    domain => $zone->name,
                    ns_list => join( q{;}, sort keys %auth_response_soa )
                }
            );
    }
    else {
        push @results,
            info(
                B02_NO_WORKING_NS => {
                    domain => $zone->name
                }
            );

        if ( scalar keys %ns_broken ) {
            push @results, map {
                info(
                    B02_NS_BROKEN => {
                        ns => $_
                    }
                )
            } keys %ns_broken;
        }

        if ( scalar keys %ns_not_auth ) {
            push @results, map {
                info(
                    B02_NS_NOT_AUTH => {
                        ns => $_
                    }
                )
            } keys %ns_not_auth;
        }

        if ( scalar keys %ns_cant_resolve ) {
            push @results, map {
                info(
                    B02_NS_NO_IP_ADDR => {
                        nsname => $_
                    }
                )
            } keys %ns_cant_resolve;
        }

        if ( scalar keys %ns_no_response ) {
            push @results, map {
                info(
                    B02_NS_NO_RESPONSE => {
                        ns => $_
                    }
                )
            } keys %ns_no_response;
        }

        if ( scalar keys %unexpected_rcode ) {
            push @results, map {
                info(
                    B02_UNEXPECTED_RCODE => {
                        rcode => $unexpected_rcode{$_},
                        ns => $_
                    }
                )
            } keys %unexpected_rcode;
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub basic02

sub basic03 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my $query_type = q{A};

    my $name        = q{www.} . $zone->name;
    my $response_nb = 0;
    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) } ) {
        if ( _ip_disabled_message( \@results, $ns, $query_type ) ) {
            next;
        }
        _ip_enabled_message( \@results, $ns, $query_type );

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

=back

=cut
