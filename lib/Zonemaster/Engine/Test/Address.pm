package Zonemaster::Engine::Test::Address;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare("v1.0.7");

use Zonemaster::Engine;

use Carp;
use List::MoreUtils qw[none any];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;
use Zonemaster::Engine::Recursor;
use Zonemaster::Engine::Constants qw[:addresses :ip];
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Util;

###
### Entry Points
###

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    push @results, $class->address01( $zone ) if Zonemaster::Engine::Util::should_run_test( q{address01} );
    push @results, $class->address02( $zone ) if Zonemaster::Engine::Util::should_run_test( q{address02} );
    # Perform ADDRESS03 if ADDRESS02 passed
    if ( any { $_->tag eq q{NAMESERVERS_IP_WITH_REVERSE} } @results ) {
        push @results, $class->address03( $zone ) if Zonemaster::Engine::Util::should_run_test( q{address03} );
    }

    return @results;
}

###
### Metadata Exposure
###

sub metadata {
    my ( $class ) = @_;

    return {
        address01 => [
            qw(
              NAMESERVER_IP_PRIVATE_NETWORK
              NO_IP_PRIVATE_NETWORK
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        address02 => [
            qw(
              NAMESERVER_IP_WITHOUT_REVERSE
              NAMESERVERS_IP_WITH_REVERSE
              NO_RESPONSE_PTR_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        address03 => [
            qw(
              NAMESERVER_IP_WITHOUT_REVERSE
              NAMESERVER_IP_PTR_MISMATCH
              NAMESERVER_IP_PTR_MATCH
              NO_RESPONSE_PTR_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    NAMESERVER_IP_WITHOUT_REVERSE => sub {
        __x    # ADDRESS:NAMESERVER_IP_WITHOUT_REVERSE
          'Nameserver {ns} has an IP address ({address}) without PTR configured.', @_;
    },
    NAMESERVER_IP_PTR_MISMATCH => sub {
        __x    # ADDRESS:NAMESERVER_IP_PTR_MISMATCH
          'Nameserver {ns} has an IP address ({address}) with mismatched PTR result ({names}).', @_;
    },
    NAMESERVER_IP_PRIVATE_NETWORK => sub {
        __x    # ADDRESS:NAMESERVER_IP_PRIVATE_NETWORK
          'Nameserver {ns} has an IP address ({address}) '
          . 'with prefix {prefix} referenced in {reference} as a \'{name}\'.',
          @_;
    },
    NO_IP_PRIVATE_NETWORK => sub {
        __x    # ADDRESS:NO_IP_PRIVATE_NETWORK
          'All Nameserver addresses are in the routable public addressing space.', @_;
    },
    NAMESERVERS_IP_WITH_REVERSE => sub {
        __x    # ADDRESS:NAMESERVERS_IP_WITH_REVERSE
          "Reverse DNS entry exists for each Nameserver IP address.", @_;
    },
    NAMESERVER_IP_PTR_MATCH => sub {
        __x    # ADDRESS:NAMESERVER_IP_PTR_MATCH
          "Every reverse DNS entry matches name server name.", @_;
    },
    NO_RESPONSE_PTR_QUERY => sub {
        __x    # ADDRESS:NO_RESPONSE_PTR_QUERY
          'No response from nameserver(s) on PTR query ({reverse}).', @_;
    },
    TEST_CASE_END => sub {
        __x    # ADDRESS:TEST_CASE_END
          'TEST_CASE_END {testcase}.', @_;
    },
    TEST_CASE_START => sub {
        __x    # ADDRESS:TEST_CASE_START
          'TEST_CASE_START {testcase}.', @_;
    },
);

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

sub version {
    return "$Zonemaster::Engine::Test::Address::VERSION";
}

sub find_special_address {
    my ( $class, $ip ) = @_;
    my @special_addresses;

    if ( $ip->version == $IP_VERSION_4 ) {
        @special_addresses = @IPV4_SPECIAL_ADDRESSES;
    }
    elsif ( $ip->version == $IP_VERSION_6 ) {
        @special_addresses = @IPV6_SPECIAL_ADDRESSES;
    }

    foreach my $ip_details ( @special_addresses ) {
        if ( $ip->overlaps( ${$ip_details}{ip} ) ) {
            return $ip_details;
        }
    }

    return;
}

sub address01 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (caller(0))[3] } );
    my %ips;

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $ips{ $local_ns->address->short };

        my $ip_details_ref = $class->find_special_address( $local_ns->address );

        if ( $ip_details_ref ) {
            push @results,
              info(
                NAMESERVER_IP_PRIVATE_NETWORK => {
                    ns        => $local_ns->name->string,
                    address   => $local_ns->address->short,
                    prefix    => ${$ip_details_ref}{ip}->print,
                    name      => ${$ip_details_ref}{name},
                    reference => ${$ip_details_ref}{reference},
                }
              );
        }

        $ips{ $local_ns->address->short }++;

    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar keys %ips and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results, info( NO_IP_PRIVATE_NETWORK => {} );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (caller(0))[3] } ) );
} ## end sub address01

sub address02 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (caller(0))[3] } );

    my %ips;
    my $ptr_query;

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $ips{ $local_ns->address->short };

        my $reverse_ip_query = $local_ns->address->reverse_ip;
        $ptr_query = $reverse_ip_query;

        my $p = Zonemaster::Engine::Recursor->recurse( $ptr_query, q{PTR} );

        # In case of Classless IN-ADDR.ARPA delegation, query returns
        # CNAME records. A PTR query is done on the CNAME.
        if ( $p and $p->rcode eq q{NOERROR} and $p->get_records( q{CNAME}, q{answer} ) ) {
            my ( $cname ) = $p->get_records( q{CNAME}, q{answer} );
            $ptr_query = $cname->cname;
            $p = Zonemaster::Engine::Recursor->recurse( $ptr_query, q{PTR} );
        }

        if ( $p ) {
            if ( $p->rcode ne q{NOERROR} or not $p->get_records( q{PTR}, q{answer} ) ) {
                push @results,
                  info(
                    NAMESERVER_IP_WITHOUT_REVERSE => {
                        ns      => $local_ns->name->string,
                        address => $local_ns->address->short,
                    }
                  );
            }
        }
        else {
            push @results,
              info(
                NO_RESPONSE_PTR_QUERY => {
                    reverse => $ptr_query,
                }
              );
        }

        $ips{ $local_ns->address->short }++;

    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar keys %ips and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results, info( NAMESERVERS_IP_WITH_REVERSE => {} );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (caller(0))[3] } ) );
} ## end sub address02

sub address03 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (caller(0))[3] } );
    my $ptr_query;

    my %ips;

    foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods->method5( $zone ) } ) {

        next if $ips{ $local_ns->address->short };

        my $reverse_ip_query = $local_ns->address->reverse_ip;
        $ptr_query = $reverse_ip_query;

        my $p = Zonemaster::Engine::Recursor->recurse( $ptr_query, q{PTR} );

        # In case of Classless IN-ADDR.ARPA delegation, query returns
        # CNAME records. A PTR query is done on the CNAME.
        if ( $p and $p->rcode eq q{NOERROR} and $p->get_records( q{CNAME}, q{answer} ) ) {
            my ( $cname ) = $p->get_records( q{CNAME}, q{answer} );
            $ptr_query = $cname->cname;
            $p = Zonemaster::Engine::Recursor->recurse( $ptr_query, q{PTR} );
        }

        if ( $p ) {
            my @ptr = $p->get_records_for_name( q{PTR}, $ptr_query );
            if ( $p->rcode eq q{NOERROR} and scalar @ptr ) {
                if ( none { name( $_->ptrdname ) eq $local_ns->name->string . q{.} } @ptr ) {
                    push @results,
                      info(
                        NAMESERVER_IP_PTR_MISMATCH => {
                            ns      => $local_ns->name->string,
                            address => $local_ns->address->short,
                            names   => join( q{/}, map { $_->ptrdname } @ptr ),
                        }
                      );
                }
            }
            else {
                push @results,
                  info(
                    NAMESERVER_IP_WITHOUT_REVERSE => {
                        ns      => $local_ns->name->string,
                        address => $local_ns->address->short,
                    }
                  );
            }
        } ## end if ( $p )
        else {
            push @results,
              info(
                NO_RESPONSE_PTR_QUERY => {
                    reverse => $ptr_query,
                }
              );
        }

        $ips{ $local_ns->address->short }++;

    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar keys %ips and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results, info( NAMESERVER_IP_PTR_MATCH => {} );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (caller(0))[3] } ) );
} ## end sub address03

1;

=head1 NAME

Zonemaster::Engine::Test::Address - module implementing tests focused on the Address specific test cases of the DNS tests

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Address->all($zone);

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

=item address01($zone)

Verify that IPv4 addresse are not in private networks.

=item address02($zone)

Verify reverse DNS entries exist for nameservers IP addresses.

=item address03($zone)

Verify that reverse DNS entries match nameservers names.

=item find_special_address($ip)

Verify that an address (Net::IP::XS) given is a special (private, reserved, ...) one.

=back

=cut

