package Zonemaster::Test::Basic;

use version; our $VERSION = version->declare("v1.0.4");

use strict;
use warnings;

use 5.014002;

use Zonemaster;
use Zonemaster::Util;
use Zonemaster::TestMethods;
use Zonemaster::Test::Address;
use Zonemaster::Test::Syntax;
use Zonemaster::Constants qw[:ip :name];
use List::MoreUtils qw[any none];

use Carp;

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

        # Perform BASIC2 if BASIC1 passed
        if ( any { $_->tag eq q{HAS_GLUE} } @results ) {
            push @results, $class->basic02( $zone );
        }
        else {
            push @results, info( NO_GLUE_PREVENTS_NAMESERVER_TESTS => {} );
        }

        # Perform BASIC3 if BASIC2 failed
        if ( none { $_->tag eq q{HAS_NAMESERVERS} } @results ) {
            push @results, $class->basic03( $zone ) if Zonemaster->config->should_run( 'basic03' );
        }
        else {
            push @results,
              info(
                HAS_NAMESERVER_NO_WWW_A_TEST => {
                    zname => $zone->name,
                }
              );
        }

        push @results, $class->basic04( $zone ) if Zonemaster->config->should_run( 'basic04' );
    } ## end if ( none { $_->tag eq...})

    return @results;
} ## end sub all

sub can_continue {
    my ( $class, @results ) = @_;
    my %tag = map { $_->tag => 1 } @results;

    if ( $tag{HAS_GLUE} and $tag{HAS_NAMESERVERS} ) {
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
              )
        ],
        basic01 => [
            qw(
              NO_PARENT
              HAS_GLUE
              NO_GLUE
              NO_DOMAIN
              PARENT_REPLIES
              NO_PARENT_RESPONSE
              NOT_A_ZONE
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
              )
        ],
        basic03 => [
            qw(
              NO_NAMESERVER_PREVENTS_WWW_A_TEST
              HAS_A_RECORDS
              IPV4_DISABLED
              IPV6_DISABLED
              IPV4_ENABLED
              IPV6_ENABLED
              A_QUERY_NO_RESPONSES
              )
        ],
        basic04 => [
            qw(
              HAS_RECORDS_TTL
              NO_RECORDS
              )
        ],
    };
} ## end sub metadata

sub translation {
    return {
        "DOMAIN_NAME_LABEL_TOO_LONG"    => "Domain name ({dname}) has a label ({dlabel}) too long ({dlength}/{max}).",
        "DOMAIN_NAME_ZERO_LENGTH_LABEL" => "Domain name ({dname}) has a zero length label.",
        "DOMAIN_NAME_TOO_LONG"          => "Domain name is too long ({fqdnlength}/{max}).",
        'NO_PARENT'                     => 'No parent domain could be found for the tested domain.',
        'NO_GLUE'       => 'Nameservers for "{pname}" provided no NS records for tested zone. RCODE given was {rcode}.',
        'HAS_A_RECORDS' => 'Nameserver {ns} returned A record(s) for {dname}.',
        'NO_A_RECORDS'  => 'Nameserver {ns} did not return A record(s) for {dname}.',
        'HAS_RECORDS_TTL' => 'Found an {rr} type record for {dname}/{address}/{ttl}',
        'NO_RECORDS'      => 'No A/AAAA records for {dname} or www.{dname}.',
        'NO_DOMAIN'     => 'Nameserver for zone {pname} responded with NXDOMAIN to query for glue.',
        'HAS_NAMESERVERS'    => 'Nameserver {ns} listed these servers as glue: {nsnlist}.',
        'PARENT_REPLIES'     => 'Nameserver for zone {pname} replies when trying to fetch glue.',
        'NO_PARENT_RESPONSE' => 'No response from nameserver for zone {pname} when trying to fetch glue.',
        'NO_GLUE_PREVENTS_NAMESERVER_TESTS' => 'No NS records for tested zone from parent. NS tests aborted.',
        'NS_FAILED'                    => 'Nameserver {ns}/{address} did not return NS records. RCODE was {rcode}.',
        'NS_NO_RESPONSE'               => 'Nameserver {ns}/{address} did not respond to NS query.',
        'A_QUERY_NO_RESPONSES'         => 'Nameservers did not respond to A query.',
        'HAS_NAMESERVER_NO_WWW_A_TEST' => 'Functional nameserver found. "A" query for www.{zname} test aborted.',
        'HAS_GLUE'                     => 'Nameserver for zone {pname} listed these nameservers as glue: {nsnlist}.',
        'IPV4_DISABLED'                => 'IPv4 is disabled, not sending "{rrtype}" query to {ns}/{address}.',
        'IPV4_ENABLED'                 => 'IPv4 is enabled, can send "{rrtype}" query to {ns}/{address}.',
        'IPV6_DISABLED'                => 'IPv6 is disabled, not sending "{rrtype}" query to {ns}/{address}.',
        'IPV6_ENABLED'                 => 'IPv6 is enabled, can send "{rrtype}" query to {ns}/{address}.',
        'NOT_A_ZONE'                   => '{zname} is not a zone.',
    };
} ## end sub translation

sub version {
    return "$Zonemaster::Test::Basic::VERSION";
}

###
### Tests
###

sub basic00 {
    my ( $class, $zone ) = @_;
    my $name = name( $zone );
    my @results;

    foreach my $local_label ( @{ $name->labels } ) {
        if ( length $local_label > $LABEL_MAX_LENGTH ) {
            push @results,
              info(
                q{DOMAIN_NAME_LABEL_TOO_LONG} => {
                    dname   => "$name",
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
                    dname => "$name",
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

    return @results;

} ## end sub basic00

sub basic01 {
    my ( $class, $zone ) = @_;
    my @results;
    my $parent = $zone->parent;

    if ( not $parent ) {
        return info( NO_PARENT => { zone => $zone->name->string } );
    }

    my $p = $parent->query_persistent( $zone->name, q{NS} );
    if ( not $p ) {
        $p = $parent->query_one( $zone->name, q{NS} );
    }

    if ( $p ) {
        push @results,
          info(
            PARENT_REPLIES => {
                pname => $parent->name->string,
            }
          );
    }
    else {
        push @results,
          info(
            NO_PARENT_RESPONSE => {
                pname => $parent->name->string,
            }
          );
        return @results;
    }

    if ( $p->rcode eq q{NXDOMAIN} ) {
        push @results,
          info(
            NO_DOMAIN => {
                pname => $parent->name->string,
            }
          );
    }
    else {
        if ( $p->has_rrs_of_type_for_name( q{NS}, $zone->name ) ) {
            push @results,
              info(
                HAS_GLUE => {
                    pname   => $parent->name->string,
                    nsnlist => join( q{,}, sort map { $_->nsdname } $p->get_records_for_name( q{NS}, $zone->name ) ),
                }
              );
        }
        else {
            push @results,
              info(
                NO_GLUE => {
                    pname => $parent->name->string,
                    rcode => $p->rcode,
                }
              );
            if ( $p->aa and ( grep { $_->type eq 'SOA' } $p->authority ) ) {
                push @results, info( NOT_A_ZONE => { zname => $zone->name->string } );
            }
        }
    } ## end else [ if ( $p->rcode eq q{NXDOMAIN})]

    return @results;
} ## end sub basic01

sub basic02 {
    my ( $class, $zone ) = @_;
    my @results;
    my $query_type = q{NS};

    foreach my $ns ( @{ Zonemaster::TestMethods->method4( $zone ) } ) {
        if ( not Zonemaster->config->ipv4_ok and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }
        elsif ( Zonemaster->config->ipv4_ok and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_ENABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype  => $query_type,
                }
              );
        }

        if ( not Zonemaster->config->ipv6_ok and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }
        elsif ( Zonemaster->config->ipv6_ok and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_ENABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype  => $query_type,
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
                        ns      => $ns->name->string,
                        address => $ns->address->short,
                    }
                  );
            }
            else {
                push @results,
                  info(
                    NS_FAILED => {
                        ns      => $ns->name->string,
                        address => $ns->address->short,
                        rcode   => $p->rcode,
                    }
                  );
            }
        } ## end if ( $p )
        else {
            push @results,
              info(
                NS_NO_RESPONSE => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                }
              );
        }
    } ## end foreach my $ns ( @{ Zonemaster::TestMethods...})

    return @results;
} ## end sub basic02

sub basic03 {
    my ( $class, $zone ) = @_;
    my @results;
    my $query_type = q{A};

    my $name        = q{www.} . $zone->name;
    my $response_nb = 0;
    foreach my $ns ( @{ Zonemaster::TestMethods->method4( $zone ) } ) {
        if ( not Zonemaster->config->ipv4_ok and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }
        elsif ( Zonemaster->config->ipv4_ok and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_ENABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype  => $query_type,
                }
              );
        }

        if ( not Zonemaster->config->ipv6_ok and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }
        elsif ( Zonemaster->config->ipv6_ok and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_ENABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype  => $query_type,
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
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    dname   => $name,
                }
              );
        }
        else {
            push @results,
              info(
                NO_A_RECORDS => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    dname   => $name,
                }
              );
        }
    } ## end foreach my $ns ( @{ Zonemaster::TestMethods...})

    if ( scalar( @{ Zonemaster::TestMethods->method4( $zone ) } ) and not $response_nb ) {
        push @results, info( A_QUERY_NO_RESPONSES => {} );
    }

    return @results;
} ## end sub basic03

sub basic04 {
    my ( $class, $zone ) = @_;
    my @results;
    my $response_nb = 0;

    foreach my $query_type ( 'A', 'AAAA' ) {
        foreach my $prefix ( '', 'www.' ) {
            my $name = $prefix . $zone->name;
            my $p = $zone->query_one( $name, $query_type );

            foreach my $a ( $p->answer() ) {
                $response_nb++;
                push @results,
                  info(
                    HAS_RECORDS_TTL => {
                        rr      => $query_type,
                        dname   => $name,
                        address => $a->address(),
                        ttl     => $a->ttl(),
                    }
                  );
            }
        }
    } ## end foreach my $query_type ( 'A'...)

    if ( not $response_nb ) {
        push @results, info( NO_RECORDS => { dname => $zone->name->string } );
    }

    return @results;
} ## end sub basic04

1;

1;

=head1 NAME

Zonemaster::Test::Basic - module implementing test for very basic domain functionality

=head1 SYNOPSIS

    my @results = Zonemaster::Test::Basic->all($zone);

=head1 METHODS

=over

=item all($zone)

Runs between one and three tests, depending on the zone. If L<basic01> passes, L<basic02> and L<basic04> is run. If L<basic02> fails, L<basic03> is run.

=item metadata()

Returns a reference to a hash, the keys of which are the names of all test methods in the module, and the corresponding values are references to
lists with all the tags that the method can use in log entries.

=item translation()

Returns a refernce to a hash with translation data. Used by the builtin translation system.

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

Checks if at least one of the nameservers pointed out by the parent zone gives a useful response when sent an A/AAAA query for both the root and
the C<www> label in the tested zone (that is, if we're testing C<example.org> this test will as for A/AAAA records for C<example.com> and
C<www.example.org>).

=back

=cut
