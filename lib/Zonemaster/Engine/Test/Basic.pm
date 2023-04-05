package Zonemaster::Engine::Test::Basic;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare("v1.0.19");

use Carp;
use List::MoreUtils qw[any none uniq];
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
              B01_CHILD_IS_ALIAS
              B01_CHILD_FOUND
              B01_CHILD_NOT_EXIST
              B01_INCONSISTENT_ALIAS
              B01_INCONSISTENT_DELEGATION
              B01_NO_CHILD
              B01_PARENT_FOUND
              B01_PARENT_UNDETERMINED
              B01_UNEXPECTED_NS_RESPONSE
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
          'Domain name must be valid';
    },
    BASIC01 => sub {
        __x    # BASIC:BASIC01
          'The domain must have a parent domain';
    },
    BASIC02 => sub {
        __x    # BASIC:BASIC02
          'The domain must have at least one working name server';
    },
    BASIC03 => sub {
        __x    # BASIC:BASIC03
          'The Broken but functional test';
    },
    A_QUERY_NO_RESPONSES => sub {
        __x    # BASIC:A_QUERY_NO_RESPONSES
          'Nameservers did not respond to A query.';
    },
    B01_CHILD_IS_ALIAS => sub {
        __x    # BASIC:B01_CHILD_IS_ALIAS
          '"{domain_child}" is not a zone. It is an alias for "{domain_target}". Run a test for "{domain_target}" instead. '
          . 'Returned from name servers "{ns_ip_list}.', @_;
    },
    B01_CHILD_FOUND => sub {
        __x    # BASIC:B01_CHILD_FOUND
          'The zone "{domain}" is found.', @_;
    },
    B01_CHILD_NOT_EXIST => sub {
        __x    # BASIC:B01_CHILD_NOT_EXIST
          '"{domain}" does not exist as it is not delegated.', @_;
    },
    B01_INCONSISTENT_ALIAS => sub {
        __x    # BASIC:B01_INCONSISTENT_ALIAS
          'The alias for "{domain}" is inconsistent between name servers.', @_;
    },
    B01_INCONSISTENT_DELEGATION => sub {
        __x    # BASIC:B01_INCONSISTENT_DELEGATION
          'The name servers for parent zone "{domain_parent}" give inconsistent delegation of "{domain_child}". '
          . 'Returned from name servers "{ns_ip_list}".', @_;
    },
    B01_NO_CHILD => sub {
        __x    # BASIC:B01_NO_CHILD
          '"{domain_child}" does not exist as a DNS zone. Try to test "{domain_super}" instead.', @_;
    },
    B01_PARENT_FOUND => sub {
        __x    # BASIC:B01_PARENT_FOUND
          'The parent zone is "{domain}" as returned from name servers "{ns_ip_list}".', @_;
    },
    B01_PARENT_UNDETERMINED => sub {
        __x    # BASIC:B01_PARENT_UNDETERMINED
          'The parent zone cannot be determined on name servers "{ns_ip_list}".', @_;
    },
    B01_UNEXPECTED_NS_RESPONSE => sub {
        __x    # BASIC:B01_UNEXPECTED_NS_RESPONSE
          'Name servers for parent domain "{domain_parent}" give an incorrect response on SOA query for "{domain_child}". '
          . 'Returned from name servers "{ns_ip_list}".', @_;
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

    if ( $zone->name eq '.' ) {
        push @results,
          info(
             B01_CHILD_FOUND => {
                domain => $zone->name
             }
          );
        
        return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
    }

    my %all_servers;
    my @handled_servers;
    my %parent_information;
    my %parent_found;
    my %delegation_found;
    my %non_aa_non_delegation;
    my %aa_nxdomain;
    my %aa_soa;
    my %aa_cname;
    my %cname_with_referral;
    my %aa_dname;
    my %aa_nodata;

    $all_servers{$_} = name( '.' ) for Zonemaster::Engine::Recursor->root_servers;

    my %rrs_ns;
    my @remaining_servers = keys %all_servers;

    while ( @remaining_servers ) {
        my $ns_string = shift @remaining_servers;
        my @ns_labels = split( '/', $ns_string );
        push @handled_servers, $ns_labels[1];

        my $ns = ns( $ns_labels[0], $ns_labels[1] );
        my $zone_name = $all_servers{$ns_string};
        my $query_type = q{SOA};

        if ( _ip_disabled_message( \@results, $ns, $query_type ) ) {
            next;
        }
        _ip_enabled_message( \@results, $ns, $query_type );

        my $p = $ns->query( $zone->name->string, $query_type );

        unless ( $p and ( $p->rcode eq 'NOERROR' or $p->rcode eq 'NXDOMAIN' ) ) {
            next;
        }

        if ( not $p->is_redirect and not $p->aa ) {
            push @{$non_aa_non_delegation{$zone->name->string}}, $ns_string;
        }

        if ( $p->is_redirect and index( $zone_name, name( lc( ( $p->get_records( 'NS' ) )[0]->owner ) ) ) == -1 
            and index( $zone->name->fqdn, name( lc( ( $p->get_records( 'NS' ) )[0]->owner ) ) ) == -1 ) {
            next;
        }

        if ( $p->is_redirect and index( $zone->name->fqdn, name( lc( ( $p->get_records( 'NS' ) )[0]->owner ) ) ) > 0 ) {
            $rrs_ns{$_->nsdname}{'referral'} = $_->owner for $p->get_records( 'NS' );

            $rrs_ns{$_->owner}{'addresses'}{$_->address} = 1 for ( $p->get_records( q{A} ), $p->get_records( 'AAAA' ) );

            foreach my $ns_name ( keys %rrs_ns ) {
                unless ( exists $rrs_ns{$ns_name}{'addresses'} and scalar keys %{ $rrs_ns{$ns_name}{'addresses'} } > 0 ) {
                    my $p_a = Zonemaster::Engine::Recursor->recurse( $ns_name, q{A} );

                    if ( $p_a and $p_a->rcode eq 'NOERROR' ) {
                        $rrs_ns{$ns_name}{'addresses'}{$_->address} = 1 for $p->get_records_for_name( 'A', $ns_name );
                    }

                    my $p_aaaa = Zonemaster::Engine::Recursor->recurse( $ns_name, q{AAAA} );

                    if ( $p_aaaa and $p_aaaa->rcode eq 'NOERROR' ) {
                        $rrs_ns{$ns_name}{'addresses'}{$_->address} = 1 for $p->get_records_for_name( 'AAAA', $ns_name );
                    }
                }

                foreach my $ns_ip ( keys %{ $rrs_ns{$ns_name}{'addresses'} } ) {
                    unless ( grep { $_ eq $ns_ip } @handled_servers ) {
                        $all_servers{$ns_name . '/' . $ns_ip} = $rrs_ns{$ns_name}{'referral'};
                        push @remaining_servers, $ns_name . '/' . $ns_ip;
                        push @handled_servers, $ns_ip;
                    }
                }
            }
        }

        my $pass = 0;
        if ( $p->is_redirect and scalar $p->get_records_for_name( 'NS', $zone->name->string ) ) {
            $pass += 1;
        }

        if ( $p->is_redirect and scalar $p->get_records_for_name( 'CNAME', $zone->name->string, q{answer} ) ) {
            $pass += 1;
        }

        if ( $p->aa ) {
            $pass += 1;
        }

        if ( $pass == 1 ) {
            $parent_information{$ns->string}{$zone_name} = $p;
        }
    }

    @handled_servers = ();
    @remaining_servers = keys %parent_information;

    while ( @remaining_servers ) {
        my $ns_string = shift @remaining_servers;
        my @ns_labels = split( '/', $ns_string );
        push @handled_servers, $ns_labels[1];

        my $ns = ns( $ns_labels[0], $ns_labels[1] );
        my $query_type = q{NS};

        foreach my $zone_name ( keys %{ $parent_information{$ns_string} } ) {
            if ( _ip_disabled_message( \@results, $ns, $query_type ) ) {
                next;
            }
            _ip_enabled_message( \@results, $ns, $query_type );

            my $p = $ns->query( $zone_name, $query_type );

            if ( $p and $p->get_records_for_name( 'NS', $zone_name, q{answer} ) ) {
                foreach my $rr ( $p->get_records_for_name( 'NS', $zone_name, q{answer} ) ) {
                    my @ips;
                    my $p_a = Zonemaster::Engine::Recursor->recurse( $rr->nsdname, q{A} );

                    if ( $p_a ) {
                        push @ips, $_->address for $p_a->get_records_for_name( q{A}, $rr->nsdname, q{answer} );
                    }

                    my $p_aaaa = Zonemaster::Engine::Recursor->recurse( $rr->nsdname, q{AAAA} );

                    if ( $p_aaaa ){
                        push @ips, $_->address for $p_aaaa->get_records_for_name( q{AAAA}, $rr->nsdname, q{answer} );
                    }

                    $query_type = q{SOA};

                    foreach my $ip ( uniq @ips ) {
                        my $new_ns = ns( $rr->nsdname, $ip );

                        if ( not exists $parent_information{$new_ns->string} ) {
                            if ( _ip_disabled_message( \@results, $new_ns, $query_type ) ) {
                                next;
                            }
                            _ip_enabled_message( \@results, $new_ns, $query_type );

                            my $new_p = $new_ns->query( $zone->name->string, $query_type );
                            my $pass = 0;

                            if ( $new_p ) {
                                if ( $new_p->is_redirect and scalar $new_p->get_records_for_name( 'NS', $zone->name->fqdn, q{authority} ) ) {
                                    $pass += 1;
                                }

                                if ( $new_p->aa and $new_p->rcode eq q{NOERROR} ) {
                                    $pass += 1;
                                }

                                if ( $pass == 1 ) {
                                    $parent_information{$new_ns->string}{$zone_name} = $new_p;
                                    push @remaining_servers, $new_ns->string;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    foreach my $ns_string ( keys %parent_information ) {
        foreach my $zone_name ( keys %{ $parent_information{$ns_string} } ) {
            my $p = $parent_information{$ns_string}{$zone_name};
            
            if ( $p ) {
                if ( $p->is_redirect ) {
                    push @{ $parent_found{$zone_name} }, $ns_string;
                    push @{ $delegation_found{$zone_name} }, $ns_string;
                }

                if ( $p->aa and $p->rcode eq 'NXDOMAIN' ) {
                    push @{ $parent_found{$zone_name} }, $ns_string;
                    push @{ $aa_nxdomain{$zone_name} }, $ns_string;
                }

                if ( $p->aa and scalar $p->get_records_for_name( 'SOA', $zone->name->string, q{answer} ) ) {
                    if ( $zone->name->next_higher eq $zone_name ) {
                        push @{ $aa_soa{$zone_name} }, $ns_string;
                    }
                }

                if ( $p->aa and scalar $p->get_records_for_name( 'CNAME', $zone->name->string, q{answer} ) ) {
                    push @{ $parent_found{$zone_name} }, $ns_string;
                    push @{ $aa_cname{$zone_name} }, $ns_string;
                }

                if ( $p->is_redirect and scalar $p->get_records_for_name( 'CNAME', $zone->name->string, q{answer} ) ) {
                    push @{ $parent_found{$zone_name} }, $ns_string;
                    push @{ $cname_with_referral{$zone_name} }, $ns_string;
                }

                if ( $p->aa and $p->no_such_record ) {
                    my @ns_labels = split( '/', $ns_string );
                    my $new_ns = ns( $ns_labels[0], $ns_labels[1] );
                    my $query_type = 'DNAME';

                    if ( _ip_disabled_message( \@results, $new_ns, $query_type ) ) {
                        next;
                    }
                    _ip_enabled_message( \@results, $new_ns, $query_type );

                    my $new_p = $new_ns->query( $zone->name->string, $query_type );

                    if ( $new_p and $new_p->aa and $new_p->rcode eq 'NOERROR' and scalar $new_p->get_records_for_name( 'DNAME', $zone->name->string, q{answer} ) ) {
                        push @{ $parent_found{$zone_name} }, $ns_string;
                        push @{ $aa_dname{( $new_p->get_records_for_name( 'DNAME', $zone->name->fqdn, q{answer} ) )[0]->dname}{$zone_name} }, $ns_string;
                    }
                    else {
                        push @{ $parent_found{$zone_name} }, $ns_string;
                        push @{ $aa_nodata{$zone_name} }, $ns_string;
                    }
                }
            }
        }
    }

    if ( scalar keys %parent_found ) {
        push @results, map {
          info(
              B01_PARENT_FOUND => {
                domain => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $parent_found{$_} } )
              }
          )
        } keys %parent_found;

        if ( scalar keys %parent_found > 1 ) {
          push @results,
            info(
                B01_PARENT_UNDETERMINED => {
                  ns_ip_list => join( q{;}, uniq sort map { @{ $parent_found{$_} } } keys %parent_found )
                }
            );
        }
    }

    if ( not scalar keys %parent_found and not scalar keys %aa_soa ) {
        push @results,
          info(
              B01_PARENT_UNDETERMINED => {
                ns_ip_list => join( q{;}, sort keys %parent_information )
              }
          );
    }

    if ( scalar keys %delegation_found or scalar keys %aa_soa ) {
        push @results,
          info(
              B01_CHILD_FOUND => {
                domain => $zone->name->string
              }
           );

        if ( scalar keys %aa_nxdomain or scalar keys %aa_cname or scalar keys %cname_with_referral or scalar keys %aa_dname or scalar keys %aa_nodata ) {            
            push @results, map {
              info(
                  B01_INCONSISTENT_DELEGATION => {
                    domain_parent => $_,
                    domain_child => $zone->name->string,
                    ns_ip_list => join( q{;}, sort keys %parent_information )
                  }
               )
            } uniq ( keys %aa_nxdomain, keys %aa_cname, keys %cname_with_referral, keys %aa_dname, keys %aa_nodata );
        }
        elsif ( not scalar keys %delegation_found ) {
            foreach my $zone_name ( keys %aa_soa ) {
                if ( not $zone->name->next_higher eq $zone_name ) {
                    push @results,
                      info(
                          B01_PARENT_FOUND => {
                            domain => $zone_name,
                            ns_ip_list => join( q{;}, uniq sort @{ $aa_soa{$zone_name} } )
                          }
                      );
                }
            }

            if ( scalar keys %aa_soa > 1 ) {
                push @results,
                  info(
                      B01_PARENT_UNDETERMINED => {
                        ns_ip_list => join( q{;}, uniq sort map { @{ $aa_soa{$_} } } keys %aa_soa )
                      }
                  );
            }
        }
    }

    if ( not scalar keys %delegation_found and not scalar keys %aa_soa ) {
        if ( Zonemaster::Engine::Recursor->has_fake_addresses( $zone->name->string ) ) {
            push @results,
              info(
                  B01_CHILD_NOT_EXIST => {
                    domain => $zone->name->string
                  }
              );
        }
        else {
            push @results,
              info(
                  B01_NO_CHILD => {
                    domain_child => $zone->name->string,
                    domain_super => $zone->name->next_higher
                  }
              );
        }
    }

    if ( scalar keys %aa_dname ) {
        push @results, map { my $target = $_;
          info(
              B01_CHILD_IS_ALIAS => {
                domain_child => $zone->name->string,
                domain_target => $target,
                ns_ip_list => join( q{;}, uniq sort map { @{ $aa_dname{$target}{$_} } } keys %{ $aa_dname{$target} } )
              }
          )
        } keys %aa_dname;

        if ( scalar keys %aa_dname > 1 ) {
            push @results,
              info(
                  B01_INCONSISTENT_ALIAS => {
                    domain => $zone->name->string
                  }
              );
        }
    }

    if ( scalar keys %non_aa_non_delegation ) {
        push @results, map {
          info(
              B01_UNEXPECTED_NS_RESPONSE => {
                domain_child => $zone->name->string,
                domain_parent => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $non_aa_non_delegation{$_} } )
              }
          )
        } keys %non_aa_non_delegation;
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

    my @ns_names = @{ Zonemaster::Engine::TestMethods->method2( $zone ) };
    my @ns = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    
    if ( not scalar @ns_names ) {
        push @results,
            info(
                B02_NO_DELEGATION => {
                    domain => $zone->name
                }
            );
            
        return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
    }

    if ( not scalar @ns ) {
        my %found_ip;
        my @ns_ips = @{ $zone->glue_addresses };

        foreach my $ns_name ( @ns_names ) {
            $found_ip{$ns_name->string} = 0;
            
            foreach my $rr ( @ns_ips ) {
                if ( $rr->owner eq $ns_name ) {
                    $found_ip{$ns_name->string} = 1;
                    push @ns, Zonemaster::Engine::Nameserver->new({ name => $ns_name, address => $rr->address });
                }
            }
        }

        foreach my $ns_name ( keys %found_ip ) {
            if ( $found_ip{$ns_name} == 0 ) {
                $ns_cant_resolve{$ns_name} = 1;
            }
        }
    }

    foreach my $ns ( @ns ) {
        if ( _ip_disabled_message( \@results, $ns, $query_type ) ) {
            next;
        }
        _ip_enabled_message( \@results, $ns, $query_type );

        my $p = $ns->query( $zone->name, $query_type );

        if ( $p ) {
            if ( $p->rcode ne 'NOERROR' ) {
                $unexpected_rcode{$ns->string} = $p->rcode;
            }
            elsif ( not $p->aa ) {
                $ns_not_auth{$ns->string} = 1;
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
