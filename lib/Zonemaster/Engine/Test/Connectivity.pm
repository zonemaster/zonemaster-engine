package Zonemaster::Engine::Test::Connectivity;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare("v1.1.0");

use Carp;
use List::MoreUtils qw[uniq];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;

use Zonemaster::Engine::Profile;
use Zonemaster::Engine::ASNLookup;
use Zonemaster::Engine::Constants qw[:ip];
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Util;

=head1 NAME

Zonemaster::Engine::Test::Connectivity - Module implementing tests focused on name servers reachability

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Connectivity->all( $zone );

=head1 METHODS

=over

=item all()

    my @array = all( $zone );

Runs the default set of tests for that module, i.e. L<four tests|/TESTS>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    if ( Zonemaster::Engine::Util::should_run_test( q{connectivity01} ) ) {
        push @results, $class->connectivity01( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{connectivity02} ) ) {
        push @results, $class->connectivity02( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{connectivity03} ) ) {
        push @results, $class->connectivity03( $zone );
    }
    if ( Zonemaster::Engine::Util::should_run_test( q{connectivity04} ) ) {
        push @results, $class->connectivity04( $zone );
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
        connectivity01 => [
            qw(
              CN01_IPV4_DISABLED
              CN01_IPV6_DISABLED
              CN01_MISSING_NS_RECORD_UDP
              CN01_MISSING_SOA_RECORD_UDP
              CN01_NO_RESPONSE_NS_QUERY_UDP
              CN01_NO_RESPONSE_SOA_QUERY_UDP
              CN01_NO_RESPONSE_UDP
              CN01_NS_RECORD_NOT_AA_UDP
              CN01_SOA_RECORD_NOT_AA_UDP
              CN01_UNEXPECTED_RCODE_NS_QUERY_UDP
              CN01_UNEXPECTED_RCODE_SOA_QUERY_UDP
              CN01_WRONG_NS_RECORD_UDP
              CN01_WRONG_SOA_RECORD_UDP
              IPV4_DISABLED
              IPV6_DISABLED
              TEST_CASE_END
              TEST_CASE_START
            )
        ],
        connectivity02 => [
            qw(
              CN02_MISSING_NS_RECORD_TCP
              CN02_MISSING_SOA_RECORD_TCP
              CN02_NO_RESPONSE_NS_QUERY_TCP
              CN02_NO_RESPONSE_SOA_QUERY_TCP
              CN02_NO_RESPONSE_TCP
              CN02_NS_RECORD_NOT_AA_TCP
              CN02_SOA_RECORD_NOT_AA_TCP
              CN02_UNEXPECTED_RCODE_NS_QUERY_TCP
              CN02_UNEXPECTED_RCODE_SOA_QUERY_TCP
              CN02_WRONG_NS_RECORD_TCP
              CN02_WRONG_SOA_RECORD_TCP
              IPV4_DISABLED
              IPV6_DISABLED
              TEST_CASE_END
              TEST_CASE_START
            )
        ],
        connectivity03 => [
            qw(
              ASN_INFOS_RAW
              ASN_INFOS_ANNOUNCE_BY
              ASN_INFOS_ANNOUNCE_IN
              EMPTY_ASN_SET
              ERROR_ASN_DATABASE
              IPV4_DIFFERENT_ASN
              IPV4_ONE_ASN
              IPV4_SAME_ASN
              IPV6_DIFFERENT_ASN
              IPV6_ONE_ASN
              IPV6_SAME_ASN
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        connectivity04 => [
            qw(
              ASN_INFOS_RAW
              ASN_INFOS_ANNOUNCE_IN
              CN04_EMPTY_PREFIX_SET
              CN04_ERROR_PREFIX_DATABASE
              CN04_IPV4_DIFFERENT_PREFIX
              CN04_IPV4_SAME_PREFIX
              CN04_IPV6_DIFFERENT_PREFIX
              CN04_IPV6_SAME_PREFIX
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    CONNECTIVITY01 => sub {
        __x    # CONNECTIVITY:CONNECTIVITY01
          'UDP connectivity';
    },
    CONNECTIVITY02 => sub {
        __x    # CONNECTIVITY:CONNECTIVITY02
          'TCP connectivity';
    },
    CONNECTIVITY03 => sub {
        __x    # CONNECTIVITY:CONNECTIVITY03
          'AS Diversity';
    },
    CONNECTIVITY04 => sub {
        __x    # CONNECTIVITY:CONNECTIVITY04
          'IP Prefix Diversity';
    },
    CN01_IPV4_DISABLED => sub {
        __x    # CONNECTIVITY:CN01_IPV4_DISABLED
          'IPv4 is disabled. No DNS queries are sent to these name servers: "{ns_list}".', @_;
    },
    CN01_IPV6_DISABLED => sub {
        __x    # CONNECTIVITY:CN01_IPV6_DISABLED
          'IPv6 is disabled. No DNS queries are sent to these name servers: "{ns_list}".', @_;
    },
    CN01_MISSING_NS_RECORD_UDP => sub {
        __x    # CONNECTIVITY:CN01_MISSING_NS_RECORD_UDP
          'Nameserver {ns} responds to a NS query with no NS records in the answer section over UDP.', @_;
    },
    CN01_MISSING_SOA_RECORD_UDP => sub {
        __x    # CONNECTIVITY:CN01_MISSING_SOA_RECORD_UDP
          'Nameserver {ns} responds to a SOA query with no SOA records in the answer section over UDP.', @_;
    },
    CN01_NO_RESPONSE_NS_QUERY_UDP => sub {
        __x    # CONNECTIVITY:CN01_NO_RESPONSE_NS_QUERY_UDP
          'No response received from name server "{ns}" to NS queries over UDP.', @_;
    },
    CN01_NO_RESPONSE_SOA_QUERY_UDP => sub {
        __x    # CONNECTIVITY:CN01_NO_RESPONSE_SOA_QUERY_UDP
          'No response received from name server "{ns}" to SOA queries over UDP.', @_;
    },
    CN01_NO_RESPONSE_UDP => sub {
        __x    # CONNECTIVITY:CN01_NO_RESPONSE_UDP
          'No response received from name server "{ns}" to any queries over UDP.', @_;
    },
    CN01_NS_RECORD_NOT_AA_UDP => sub {
        __x    # CONNECTIVITY:CN01_NS_RECORD_NOT_AA_UDP
          'Nameserver {ns} does not give an authoritative response on an NS query over UDP.', @_;
    },
    CN01_SOA_RECORD_NOT_AA_UDP => sub {
        __x    # CONNECTIVITY:CN01_SOA_RECORD_NOT_AA_UDP
          'Nameserver {ns} does not give an authoritative response on an SOA query over UDP.', @_;
    },
    CN01_UNEXPECTED_RCODE_NS_QUERY_UDP => sub {
        __x    # CONNECTIVITY:CN01_UNEXPECTED_RCODE_NS_QUERY_UDP
          'Nameserver {ns} responds with an unexpected RCODE ({rcode}) on an NS query over UDP.', @_;
    },
    CN01_UNEXPECTED_RCODE_SOA_QUERY_UDP => sub {
        __x    # CONNECTIVITY:CN01_UNEXPECTED_RCODE_SOA_QUERY_UDP
          'Nameserver {ns} responds with an unexpected RCODE ({rcode}) on an SOA query over UDP.', @_;
    },
    CN01_WRONG_NS_RECORD_UDP => sub {
        __x    # CONNECTIVITY:CN01_WRONG_NS_RECORD_UDP
          'Nameserver {ns} responds with a wrong owner name ({domain_found} instead of {domain_expected}) on NS queries over UDP.', @_;
    },
    CN01_WRONG_SOA_RECORD_UDP => sub {
        __x    # CONNECTIVITY:CN01_WRONG_SOA_RECORD_UDP
          'Nameserver {ns} responds with a wrong owner name ({domain_found} instead of {domain_expected}) on SOA queries over UDP.', @_;
    },
    CN02_MISSING_NS_RECORD_TCP => sub {
        __x    # CONNECTIVITY:CN02_MISSING_NS_RECORD_TCP
          'Nameserver {ns} responds to a NS query with no NS records in the answer section over TCP.', @_;
    },
    CN02_MISSING_SOA_RECORD_TCP => sub {
        __x    # CONNECTIVITY:CN02_MISSING_SOA_RECORD_TCP
          'Nameserver {ns} responds to a SOA query with no SOA records in the answer section over TCP.', @_;
    },
    CN02_NO_RESPONSE_NS_QUERY_TCP => sub {
        __x    # CONNECTIVITY:CN02_NO_RESPONSE_NS_QUERY_TCP
          'No response received from name server "{ns}" to NS queries over TCP.', @_;
    },
    CN02_NO_RESPONSE_SOA_QUERY_TCP => sub {
        __x    # CONNECTIVITY:CN02_NO_RESPONSE_SOA_QUERY_TCP
          'No response received from name server "{ns}" to SOA queries over TCP.', @_;
    },
    CN02_NO_RESPONSE_TCP => sub {
        __x    # CONNECTIVITY:CN02_NO_RESPONSE_TCP
          'No response received from name server "{ns}" to any queries over TCP.', @_;
    },
    CN02_NS_RECORD_NOT_AA_TCP => sub {
        __x    # CONNECTIVITY:CN02_NS_RECORD_NOT_AA_TCP
          'Nameserver {ns} does not give an authoritative response on an NS query over TCP.', @_;
    },
    CN02_SOA_RECORD_NOT_AA_TCP => sub {
        __x    # CONNECTIVITY:CN02_SOA_RECORD_NOT_AA_TCP
          'Nameserver {ns} does not give an authoritative response on an SOA query over TCP.', @_;
    },
    CN02_UNEXPECTED_RCODE_NS_QUERY_TCP => sub {
        __x    # CONNECTIVITY:CN02_UNEXPECTED_RCODE_NS_QUERY_TCP
          'Nameserver {ns} responds with an unexpected RCODE ({rcode}) on an NS query over TCP.', @_;
    },
    CN02_UNEXPECTED_RCODE_SOA_QUERY_TCP => sub {
        __x    # CONNECTIVITY:CN02_UNEXPECTED_RCODE_SOA_QUERY_TCP
          'Nameserver {ns} responds with an unexpected RCODE ({rcode}) on an SOA query over TCP.', @_;
    },
    CN02_WRONG_NS_RECORD_TCP => sub {
        __x    # CONNECTIVITY:CN02_WRONG_NS_RECORD_TCP
          'Nameserver {ns} responds with a wrong owner name ({domain_found} instead of {domain_expected}) on NS queries over TCP.', @_;
    },
    CN02_WRONG_SOA_RECORD_TCP => sub {
        __x    # CONNECTIVITY:CN02_WRONG_SOA_RECORD_TCP
          'Nameserver {ns} responds with a wrong owner name ({domain_found} instead of {domain_expected}) on SOA queries over TCP.', @_;
    },
    CN04_ASN_INFOS_ANNOUNCE_IN => sub {
        __x    # CONNECTIVITY:ASN_INFOS_ANNOUNCE_IN
          'Name server IP address "{ns_ip}" is announced in prefix "{prefix}".', @_;
    },
    CN04_ASN_INFOS_RAW => sub {
        __x    # CONNECTIVITY:ASN_INFOS_RAW
          'The ASN data for name server IP address "{ns_ip}" is "{data}".', @_;
    },
    CN04_EMPTY_PREFIX_SET => sub {
        __x    # CONNECTIVITY:CN04_EMPTY_PREFIX_SET
          'Prefix database returned no information for IP address {ns_ip}.', @_;
    },
    CN04_ERROR_PREFIX_DATABASE => sub {
        __x    # CONNECTIVITY:CN04_ERROR_PREFIX_DATABASE
          'Prefix database error. No data to analyze for IP address {ns_ip}.', @_;
    },
    CN04_IPV4_SAME_PREFIX => sub {
        __x    # CONNECTIVITY:CN04_IPV4_SAME_PREFIX
          'The following name server(s) are announced in the same IPv4 prefix ({ip_prefix}): "{ns_list}"', @_;
    },
    CN04_IPV4_DIFFERENT_PREFIX => sub {
        __x    # CONNECTIVITY:CN04_IPV4_DIFFERENT_PREFIX
          'The following name server(s) are announced in unique IPv4 prefix(es): "{ns_list}"', @_;
    },
    CN04_IPV6_SAME_PREFIX => sub {
        __x    # CONNECTIVITY:CN04_IPV6_SAME_PREFIX
          'The following name server(s) are announced in the same IPv6 prefix ({ip_prefix}): "{ns_list}"', @_;
    },
    CN04_IPV6_DIFFERENT_PREFIX => sub {
        __x    # CONNECTIVITY:CN04_IPV6_DIFFERENT_PREFIX
          'The following name server(s) are announced in unique IPv6 prefix(es): "{ns_list}"', @_;
    },
    ERROR_ASN_DATABASE => sub {
        __x    # CONNECTIVITY:ERROR_ASN_DATABASE
          'ASN Database error. No data to analyze for {ns_ip}.', @_;
    },
    EMPTY_ASN_SET => sub {
        __x    # CONNECTIVITY:EMPTY_ASN_SET
          'AS database returned no informations for IP address {ns_ip}.', @_;
    },
    IPV4_SAME_ASN => sub {
        __x    # CONNECTIVITY:IPV4_SAME_ASN
          'All authoritative nameservers have their IPv4 addresses in the same AS set ({asn_list}).', @_;
    },
    IPV4_ONE_ASN => sub {
        __x    # CONNECTIVITY:IPV4_ONE_ASN
          'All authoritative nameservers have their IPv4 addresses in the same AS ({asn}).', @_;
    },
    IPV4_DIFFERENT_ASN => sub {
        __x    # CONNECTIVITY:IPV4_DIFFERENT_ASN
          'At least two IPv4 addresses of the authoritative nameservers are announced by different AS sets. '
          . 'A merged list of all AS: ({asn_list}).', @_;
    },
    IPV6_SAME_ASN => sub {
        __x    # CONNECTIVITY:IPV6_SAME_ASN
          'All authoritative nameservers have their IPv6 addresses in the same AS set ({asn_list}).', @_;
    },
    IPV6_ONE_ASN => sub {
        __x    # CONNECTIVITY:IPV6_ONE_ASN
          'All authoritative nameservers have their IPv6 addresses in the same AS ({asn}).', @_;
    },
    IPV6_DIFFERENT_ASN => sub {
        __x    # CONNECTIVITY:IPV6_DIFFERENT_ASN
          'At least two IPv6 addresses of the authoritative nameservers are announced by different AS sets. '
          . 'A merged list of all AS: ({asn_list}).', @_;
    },
    IPV4_DISABLED => sub {
        __x    # CONNECTIVITY:IPV4_DISABLED
          'IPv4 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IPV6_DISABLED => sub {
        __x    # CONNECTIVITY:IPV6_DISABLED
          'IPv6 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IPV4_ASN => sub {
        __x    # CONNECTIVITY:IPV4_ASN
          'Name servers have IPv4 addresses in the following ASs: {asn}.', @_;
    },
    IPV6_ASN => sub {
        __x    # CONNECTIVITY:IPV6_ASN
          'Name servers have IPv6 addresses in the following ASs: {asn}.', @_;
    },
    ASN_INFOS_RAW => sub {
        __x    # CONNECTIVITY:ASN_INFOS_RAW
          'The ASN data for name server IP address "{ns_ip}" is "{data}".', @_;
    },
    ASN_INFOS_ANNOUNCE_BY => sub {
        __x    # CONNECTIVITY:ASN_INFOS_ANNOUNCE_BY
          'Name server IP address "{ns_ip}" is announced by ASN {asn}.', @_;
    },
    ASN_INFOS_ANNOUNCE_IN => sub {
        __x    # CONNECTIVITY:ASN_INFOS_ANNOUNCE_IN
          'Name server IP address "{ns_ip}" is announced in prefix "{prefix}".', @_;
    },
    TEST_CASE_END => sub {
        __x    # CONNECTIVITY:TEST_CASE_END
          'TEST_CASE_END {testcase}.', @_;
    },
    TEST_CASE_START => sub {
        __x    # CONNECTIVITY:TEST_CASE_START
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

    my $string = version();

Returns a string containing the version of the current module.

=back

=cut

sub version {
    return "$Zonemaster::Engine::Test::Connectivity::VERSION";
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

sub _emit_log { my ( $tag, $argref ) = @_; return Zonemaster::Engine->logger->add( $tag, $argref, 'Connectivity' ); }

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

=over

=item _connectivity_loop()

    _connectivity_loop( $testcase_string, $zone_name, $ns_array_ref, $logentry_array_ref );

Verifies name servers reachability. Used as an helper function for Test Cases L<Connectivity01/connectivity01()>
and L<Connectivity02/connectivity02()>.

Takes a string (test case identifier), a L<Zonemaster::Engine::DNSName> object, a reference to an array of L<Zonemaster::Engine::Nameserver>
objects and a reference to an array of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub _connectivity_loop {
    my ( $testcase, $name, $ns_list, $results ) = @_;

    my ( $testcase_prefix, $use_tcp, $protocol );
    if ( $testcase eq 'connectivity01' ) {
        ( $testcase_prefix, $use_tcp, $protocol ) = ( "CN01", 0, "UDP" );
    } elsif ( $testcase eq 'connectivity02' ) {
        ( $testcase_prefix, $use_tcp, $protocol ) = ( "CN02", 1, "TCP" );
    }

    foreach my $ns ( @$ns_list ) {
        if ( _ip_disabled_message( $results, $ns, qw{SOA NS} ) ) {
            next;
        }

        my %packets = (
            'SOA' => $ns->query( $name, q{SOA}, { usevc => $use_tcp } ),
            'NS'  => $ns->query( $name, q{NS}, { usevc => $use_tcp } )
        );

        if ( not $packets{SOA} and not $packets{NS} ) {
            push @$results, _emit_log( "${testcase_prefix}_NO_RESPONSE_${protocol}" => { ns => $ns->string } );
            next;
        }

        foreach my $qtype ( qw{SOA NS} ) {
            my $pkt = $packets{$qtype};

            if ( not $pkt ) {
                push @$results, _emit_log( "${testcase_prefix}_NO_RESPONSE_${qtype}_QUERY_${protocol}" => { ns => $ns->string } );
            }
            elsif ( $pkt->rcode ne q{NOERROR} ) {
                push @$results, _emit_log( "${testcase_prefix}_UNEXPECTED_RCODE_${qtype}_QUERY_${protocol}" => {
                        ns    => $ns->string,
                        rcode => $pkt->rcode
                    }
                );
            }
            else {
                my ( $rr ) = $pkt->get_records( $qtype, q{answer} );
                if ( not $rr ) {
                    push @$results, _emit_log( "${testcase_prefix}_MISSING_${qtype}_RECORD_${protocol}" => { ns => $ns->string } );
                }
                elsif ( lc($rr->owner) ne lc($name->fqdn) ) {
                    push @$results, _emit_log( "${testcase_prefix}_WRONG_${qtype}_RECORD_${protocol}" => {
                            ns              => $ns->string,
                            domain_found    => lc($rr->owner),
                            domain_expected => lc($name->fqdn)
                        }
                    );
                }
                elsif ( not $pkt->aa ) {
                    push @$results, _emit_log( "${testcase_prefix}_${qtype}_RECORD_NOT_AA_${protocol}" => { ns => $ns->string } );
                }
            }
        }
    }
}

=head1 TESTS

=over

=item connectivity01()

    my @logentry_array = connectivity01( $zone );

Runs the L<Connectivity01 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Connectivity-TP/connectivity01.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub connectivity01 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Connectivity01';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my $name = name( $zone );
    my @ns_list = @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) };

    my @ns_ipv4 = ();
    my @ns_ipv6 = ();
    foreach my $ns ( @ns_list ) {
        if ( $ns->address->version == $IP_VERSION_4 and not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) ) {
            push @ns_ipv4, $ns;
        }
        elsif ( $ns->address->version == $IP_VERSION_6 and not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) ) {
            push @ns_ipv6, $ns;
        }
    }
    if ( @ns_ipv4 ) {
        push @results, _emit_log( "CN01_IPV4_DISABLED" => { ns_list => join( ';', @ns_ipv4 ) } );
    }
    if ( @ns_ipv6 ) {
        push @results, _emit_log( "CN01_IPV6_DISABLED" => { ns_list => join( ';', @ns_ipv6 ) } );
    }

    _connectivity_loop("connectivity01", $name, \@ns_list, \@results);

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub connectivity01

=over

=item connectivity02()

    my @logentry_array = connectivity02( $zone );

Runs the L<Connectivity02 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Connectivity-TP/connectivity02.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub connectivity02 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Connectivity02';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my $name = name( $zone );
    my @ns_list = @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) };

    _connectivity_loop("connectivity02", $name, \@ns_list, \@results);

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub connectivity02

=over

=item connectivity03()

    my @logentry_array = connectivity03( $zone );

Runs the L<Connectivity03 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Connectivity-TP/connectivity03.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub connectivity03 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Connectivity03';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my %ips = ( $IP_VERSION_4 => {}, $IP_VERSION_6 => {} );

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) } ) {
        my $addr = $ns->address;
        $ips{ $addr->version }{ $addr->ip } = $addr;
    }

    my @v4ips = values %{ $ips{$IP_VERSION_4} };
    my @v6ips = values %{ $ips{$IP_VERSION_6} };

    my @v4asns;
    my @v4asnsets;
    my @v6asns;
    my @v6asnsets;

    foreach my $v4ip ( @v4ips ) {
        my ( $asnref, $prefix, $raw, $ret_code ) = Zonemaster::Engine::ASNLookup->get_with_prefix( $v4ip );
        if ( defined $ret_code and ( $ret_code eq q{ERROR_ASN_DATABASE} or $ret_code eq q{EMPTY_ASN_SET} ) ) {
            push @results, _emit_log( $ret_code => { ns_ip => $v4ip->short } );
        }
        else {
            if ( $raw ) {
                push @results,
                  _emit_log(
                    ASN_INFOS_RAW => {
                        ns_ip => $v4ip->short,
                        data  => $raw,
                    }
                  );
            }
            if ( $asnref ) {
                push @results,
                  _emit_log(
                    ASN_INFOS_ANNOUNCE_BY => {
                        ns_ip => $v4ip->short,
                        asn   => join( q{,}, sort @{$asnref} ),
                    }
                  );
                push @v4asns, @{$asnref};
                push @v4asnsets, join( q{,}, sort { $a <=> $b } @{$asnref} );
            }
            if ( $prefix ) {
                push @results,
                  _emit_log(
                    ASN_INFOS_ANNOUNCE_IN => {
                        ns_ip  => $v4ip->short,
                        prefix => sprintf "%s/%d",
                        $prefix->ip, $prefix->prefixlen,
                    }
                  );
            }
        }
    } ## end foreach my $v4ip ( @v4ips )
    foreach my $v6ip ( @v6ips ) {
        my ( $asnref, $prefix, $raw, $ret_code ) = Zonemaster::Engine::ASNLookup->get_with_prefix( $v6ip );
        if ( defined $ret_code and ( $ret_code eq q{ERROR_ASN_DATABASE} or $ret_code eq q{EMPTY_ASN_SET} ) ) {
            push @results, _emit_log( $ret_code => { ns_ip => $v6ip->short } );
        }
        else {
            if ( $raw ) {
                push @results,
                  _emit_log(
                    ASN_INFOS_RAW => {
                        ns_ip => $v6ip->short,
                        data  => $raw,
                    }
                  );
            }
            if ( $asnref ) {
                push @results,
                  _emit_log(
                    ASN_INFOS_ANNOUNCE_BY => {
                        ns_ip => $v6ip->short,
                        asn   => join( q{,}, sort @{$asnref} ),
                    }
                  );
                push @v6asns, @{$asnref};
                push @v6asnsets, join( q{,}, sort { $a <=> $b } @{$asnref} );
            }
            if ( $prefix ) {
                push @results,
                  _emit_log(
                    ASN_INFOS_ANNOUNCE_IN => {
                        ns_ip  => $v6ip->short,
                        prefix => sprintf "%s/%d",
                        $prefix->short, $prefix->prefixlen,
                    }
                  );
            }
        }
    } ## end foreach my $v6ip ( @v6ips )

    @v4asns = uniq sort { $a <=> $b } @v4asns;
    @v4asnsets = uniq sort @v4asnsets;
    @v6asns = uniq sort { $a <=> $b } @v6asns;
    @v6asnsets = uniq sort @v6asnsets;

    if ( scalar @v4asns ) {
        if ( @v4asns == 1 ) {
            push @results, _emit_log( IPV4_ONE_ASN => { asn => $v4asns[0] } );
        }
        elsif ( @v4asnsets == 1 ) {
            push @results, _emit_log( IPV4_SAME_ASN => { asn_list => $v4asnsets[0] } );
        }
        else {
            push @results, _emit_log( IPV4_DIFFERENT_ASN => { asn_list => join( q{,}, @v4asns ) } );
        }
    }

    if ( scalar @v6asns ) {
        if ( @v6asns == 1 ) {
            push @results, _emit_log( IPV6_ONE_ASN => { asn => $v6asns[0] } );
        }
        elsif ( @v6asnsets == 1 ) {
            push @results, _emit_log( IPV6_SAME_ASN => { asn_list => $v6asnsets[0] } );
        }
        else {
            push @results, _emit_log( IPV6_DIFFERENT_ASN => { asn_list => join( q{,}, @v6asns ) } );
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub connectivity03

=over

=item connectivity04()

    my @logentry_array = connectivity04( $zone );

Runs the L<Connectivity04 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Connectivity-TP/connectivity04.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub connectivity04 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Connectivity04';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my %prefixes;

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) } ) {
        my $ip = $ns->address;
        my ( $asnref, $prefix, $raw, $ret_code ) = Zonemaster::Engine::ASNLookup->get_with_prefix( $ip );

        if ( defined $ret_code and ( $ret_code eq q{ERROR_ASN_DATABASE} or $ret_code eq q{EMPTY_ASN_SET} ) ) {
            if ( $ret_code eq 'ERROR_ASN_DATABASE' ) {
                $ret_code = 'CN04_ERROR_PREFIX_DATABASE';
            }
            elsif ( $ret_code eq 'EMPTY_ASN_SET' ) {
                $ret_code = 'CN04_EMPTY_PREFIX_SET';
            }

            push @results, _emit_log( $ret_code => { ns_ip => $ip->short } );
        }
        else {
            if ( $raw ) {
                push @results,
                  _emit_log(
                    CN04_ASN_INFOS_RAW => {
                        ns_ip => $ip->short,
                        data  => $raw,
                    }
                  );
            }

            if ( $prefix ) {
                my $prefix_str;

                if ( $prefix->version == 4 ) {
                    $prefix_str = $prefix->prefix;
                }
                elsif ( $prefix->version == 6 ) {
                    $prefix_str = $prefix->short . '/' . $prefix->prefixlen;
                }
                else {
                    next;
                }

                push @results,
                  _emit_log(
                    CN04_ASN_INFOS_ANNOUNCE_IN => {
                        ns_ip  => $ip->short,
                        prefix => sprintf "%s", $prefix_str,
                    }
                  );

                push @{ $prefixes{$prefix->version}{$prefix_str} }, $ns;
            }
        }
    }

    foreach my $ip_version ( sort keys %prefixes ) {
        my @combined_ns;

        foreach my $prefix ( keys %{ $prefixes{$ip_version} } ) {
            if ( scalar @{ $prefixes{$ip_version}{$prefix} } == 1 ) {
                push @combined_ns, @{ $prefixes{$ip_version}{$prefix} };
            }
            elsif ( scalar @{ $prefixes{$ip_version}{$prefix} } >= 2 ) {
                push @results,
                  _emit_log(
                    "CN04_IPV${ip_version}_SAME_PREFIX" => {
                        ip_prefix => $prefix,
                        ns_list => join( q{;}, sort @{ $prefixes{$ip_version}{$prefix} } )
                    }
                  );
            }
        }

        if ( scalar @combined_ns ) {
            push @results,
              _emit_log(
                "CN04_IPV${ip_version}_DIFFERENT_PREFIX" => {
                    ns_list => join( q{;}, sort @combined_ns )
                }
              );
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub connectivity04

1;
