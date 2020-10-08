package Zonemaster::Engine::Test::Connectivity;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare("v1.0.17");

use Zonemaster::Engine;

use Carp;
use List::MoreUtils qw[uniq];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::ASNLookup;
use Zonemaster::Engine::Constants qw[:ip];
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Util;

###
### Entry Points
###

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

    return @results;
}

###
### Metadata Exposure
###

sub metadata {
    my ( $class ) = @_;

    return {
        connectivity01 => [
            qw(
              NAMESERVER_HAS_UDP_53
              NAMESERVER_NO_UDP_53
              IPV4_DISABLED
              IPV6_DISABLED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        connectivity02 => [
            qw(
              NAMESERVER_HAS_TCP_53
              NAMESERVER_NO_TCP_53
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
              IPV4_DISABLED
              IPV4_DIFFERENT_ASN
              IPV4_ONE_ASN
              IPV4_SAME_ASN
              IPV6_DISABLED
              IPV6_DIFFERENT_ASN
              IPV6_ONE_ASN
              IPV6_SAME_ASN
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    ERROR_ASN_DATABASE => sub {
        __x    # CONNECTIVITY:ERROR_ASN_DATABASE
          'AS Database error. No data to analyze.', @_;
    },
    EMPTY_ASN_SET => sub {
        __x    # CONNECTIVITY:EMPTY_ASN_SET
          'AS database returned no informations for IP address {ns_ip}.', @_;
    },
    IPV4_SAME_ASN => sub {
        __x    # CONNECTIVITY:IPV4_SAME_ASN
          'All nameservers in the delegation have IPv4 addresses in the same AS set ({asn_list}).', @_;
    },
    IPV4_ONE_ASN => sub {
        __x    # CONNECTIVITY:IPV4_ONE_ASN
          'All nameservers in the delegation have IPv4 addresses in the same AS ({asn}).', @_;
    },
    IPV4_DIFFERENT_ASN => sub {
        __x    # CONNECTIVITY:IPV4_DIFFERENT_ASN
          'Authoritative IPv4 nameservers are in more than one AS ({asn_list}).', @_;
    },
    IPV6_SAME_ASN => sub {
        __x    # CONNECTIVITY:IPV6_SAME_ASN
          'All nameservers in the delegation have IPv6 addresses in the same AS set ({asn_list}).', @_;
    },
    IPV6_ONE_ASN => sub {
        __x    # CONNECTIVITY:IPV6_ONE_ASN
          'All nameservers in the delegation have IPv6 addresses in the same AS ({asn}).', @_;
    },
    IPV6_DIFFERENT_ASN => sub {
        __x    # CONNECTIVITY:IPV6_DIFFERENT_ASN
          'Authoritative IPv6 nameservers are in more than one AS ({asn_list}).', @_;
    },
    NAMESERVER_HAS_TCP_53 => sub {
        __x    # CONNECTIVITY:NAMESERVER_HAS_TCP_53
          'Nameserver {ns} accessible over TCP on port 53.', @_;
    },
    NAMESERVER_HAS_UDP_53 => sub {
        __x    # CONNECTIVITY:NAMESERVER_HAS_UDP_53
          'Nameserver {ns} accessible over UDP on port 53.', @_;
    },
    NAMESERVER_NO_TCP_53 => sub {
        __x    # CONNECTIVITY:NAMESERVER_NO_TCP_53
          'Nameserver {ns} not accessible over TCP on port 53.', @_;
    },
    NAMESERVER_NO_UDP_53 => sub {
        __x    # CONNECTIVITY:NAMESERVER_NO_UDP_53
          'Nameserver {ns} not accessible over UDP on port 53.', @_;
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

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

sub version {
    return "$Zonemaster::Engine::Test::Connectivity::VERSION";
}

###
### Tests
###

sub connectivity01 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my $query_type = q{SOA};

    my %ips;

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

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

        next if $ips{ $local_ns->address->short };

        my $p = $local_ns->query( $zone->name, $query_type, { usevc => 0 } );

        if ( $p ) {
            push @results, info( NAMESERVER_HAS_UDP_53 => { ns => $local_ns->string } );
        }
        else {
            push @results, info( NAMESERVER_NO_UDP_53 => { ns => $local_ns->string } );
        }

        $ips{ $local_ns->address->short }++;

    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub connectivity01

sub connectivity02 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my %ips;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

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

        next if $ips{ $local_ns->address->short };

        my $p = $local_ns->query( $zone->name, $query_type, { usevc => 1 } );

        if ( $p ) {
            push @results, info( NAMESERVER_HAS_TCP_53 => { ns => $local_ns->string } );
        }
        else {
            push @results, info( NAMESERVER_NO_TCP_53 => { ns => $local_ns->string } );
        }

        $ips{ $local_ns->address->short }++;

    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub connectivity02

sub connectivity03 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my %ips = ( $IP_VERSION_4 => {}, $IP_VERSION_6 => {} );

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) } ) {
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
            push @results, info( $ret_code => { ns_ip => $v4ip->short } );
        }
        else {
            if ( $raw ) {
                push @results,
                  info(
                    ASN_INFOS_RAW => {
                        ns_ip => $v4ip->short,
                        data  => $raw,
                    }
                  );
            }
            if ( $asnref ) {
                push @results,
                  info(
                    ASN_INFOS_ANNOUNCE_BY => {
                        ns_ip => $v4ip->short,
                        asn   => join( q{,}, sort @{$asnref} ),
                    }
                  );
                push @v4asns, @{$asnref};
                push @v4asnsets, join( q{,}, sort @{$asnref} );
            }
            if ( $prefix ) {
                push @results,
                  info(
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
            push @results, info( $ret_code => { ns_ip => $v6ip->short } );
        }
        else {
            if ( $raw ) {
                push @results,
                  info(
                    ASN_INFOS_RAW => {
                        ns_ip => $v6ip->short,
                        data  => $raw,
                    }
                  );
            }
            if ( $asnref ) {
                push @results,
                  info(
                    ASN_INFOS_ANNOUNCE_BY => {
                        ns_ip => $v6ip->short,
                        asn   => join( q{,}, sort @{$asnref} ),
                    }
                  );
                push @v6asns, @{$asnref};
                push @v6asnsets, join( q{,}, sort @{$asnref} );
            }
            if ( $prefix ) {
                push @results,
                  info(
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
    @v4asnsets = uniq sort { $a <=> $b } @v4asnsets;
    @v6asns = uniq sort { $a <=> $b } @v6asns;
    @v6asnsets = uniq sort { $a <=> $b } @v6asnsets;

    if ( scalar @v4asns ) {
        if ( @v4asns == 1 ) {
            push @results, info( IPV4_ONE_ASN => { asn => $v4asns[0] } );
        }
        elsif ( @v4asnsets == 1 ) {
            push @results, info( IPV4_SAME_ASN => { asn_list => $v4asnsets[0] } );
        }
        else {
            push @results, info( IPV4_DIFFERENT_ASN => { asn_list => join( q{,}, @v4asns ) } );
        }
    }

    if ( scalar @v6asns ) {
        if ( @v6asns == 1 ) {
            push @results, info( IPV6_ONE_ASN => { asn => $v6asns[0] } );
        }
        elsif ( @v6asnsets == 1 ) {
            push @results, info( IPV6_SAME_ASN => { asn_list => $v6asnsets[0] } );
        }
        else {
            push @results, info( IPV6_DIFFERENT_ASN => { asn_list => join( q{,}, @v6asns ) } );
        }
    }


    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub connectivity03

1;

=head1 NAME

Zonemaster::Engine::Test::Connectivity - module implementing tests of nameservers reachability

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Connectivity->all($zone);

=head1 METHODS

=over

=item all($zone)

Runs the default set of tests and returns a list of log entries made by the tests

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

=item connectivity01($zone)

Verify nameservers UDP port 53 reachability.

=item connectivity02($zone)

Verify nameservers TCP port 53 reachability.

=item connectivity03($zone)

Verify that all nameservers do not belong to the same AS.

=back

=cut
