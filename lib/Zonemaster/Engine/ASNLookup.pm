package Zonemaster::Engine::ASNLookup;

use 5.014002;

use warnings;

use version; our $VERSION = version->declare( "v1.0.11" );

use Zonemaster::Engine;
use Zonemaster::Engine::Util qw( name );
use Zonemaster::Engine::Nameserver;
use Zonemaster::Engine::Profile;

use IO::Socket;
use IO::Socket::INET;
use Net::IP::XS;
use Scalar::Util qw( looks_like_number );

our @db_sources;
our $db_style;

sub get_with_prefix {
    my ( $class, $ip ) = @_;

    if ( not @db_sources ) {
        $db_style = Zonemaster::Engine::Profile->effective->get( q{asn_db.style} );
        my %db_sources = %{ Zonemaster::Engine::Profile->effective->get( q{asn_db.sources} ) };
        @db_sources = map { name( $_ ) } @{ $db_sources{ $db_style } };
    }

    if ( not ref( $ip ) or not $ip->isa( 'Net::IP::XS' ) ) {
        $ip = Net::IP::XS->new( $ip );
    }

    if ( not @db_sources ) {
        die "ASN database sources undefined";
    }

    my ( $asnref, $prefix, $raw, $ret_code );

    if ( $db_style eq q{cymru} ) {
        ( $asnref, $prefix, $raw, $ret_code ) = _cymru_asn_lookup($ip);
    }
    elsif ( $db_style eq q{ripe} ) {
        ( $asnref, $prefix, $raw, $ret_code ) = _ripe_asn_lookup($ip);
    }
    else {
        if ( not $db_style ) {
            die "ASN database style is [UNDEFINED]";
        }
        else {
            die "ASN database style value [$db_style] is illegal";
        }
    }

    map { looks_like_number( $_ ) || die "ASN lookup value isn't numeric: '$_'" } @$asnref;

    return ( $asnref, $prefix, $raw, $ret_code );

} ## end sub get_with_prefix

sub _cymru_asn_lookup {
    my $ip = shift;
    my @asns = ();

    my $reverse = $ip->reverse_ip;
    my $db_source_nb = 0;
    foreach my $db_source ( @db_sources ) {
        my $domain = $db_source->string;
        my $pair   = {
            'in-addr.arpa.' => "origin.$domain",
            'ip6.arpa.'     => "origin6.$domain",
        };
        $db_source_nb++;
        foreach my $root ( keys %{$pair} ) {
            if ( $reverse =~ s/$root/$pair->{$root}/ix ) {
                my $p = Zonemaster::Engine->recurse( $reverse, 'TXT' );
                my @rr;
                if ( $p ) {
                    @rr = $p->get_records( 'TXT' );
                }
                if ( $p and ( $p->rcode eq q{NXDOMAIN} or ( $p->rcode eq q{NOERROR} and not scalar @rr ) ) ) {
                    return \@asns, undef, q{}, q{EMPTY_ASN_SET};
                }
                if ( not $p or $p->rcode ne q{NOERROR} ) {
                    if ( $db_source_nb == scalar @db_sources ) {
                        return \@asns, undef, q{}, q{ERROR_ASN_DATABASE};
                    }
                    else {
                        last;
                    }
                }

                my $prefix_length = 0;
                my @fields;
                my $str;
                foreach my $rr ( @rr ) {
                    my $_str = $rr->txtdata;
                    my @_fields = split( /[ ][|][ ]?/x, $_str );
                    my @_asns   = split( /\s+/x,        $_fields[0] );
                    my $_prefix_length = ($_fields[1] =~ m!^.*[/](.*)!x)[0];
                    if ( $_prefix_length > $prefix_length ) {
                        $str = $_str;
                        @asns = @_asns;
                        @fields = @_fields;
                        $prefix_length = $_prefix_length;
                    }
                }
                if ( scalar @rr ) {
                    return \@asns, Net::IP::XS->new( $fields[1] ), $str, q{AS_FOUND};
                }
                else {
                    if ( $db_source_nb == scalar @db_sources ) {
                        return \@asns, undef, $str, q{ERROR_ASN_DATABASE};
                    }
                    else {
                        last;
                    }
                }
            }
        }
    } ## end foreach my $db_source ( @db_sources )
    return;
}

sub _ripe_asn_lookup {
    my $ip = shift;
    my @asns = ();

    my $db_source_nb = 0;
    foreach my $db_source ( @db_sources ) {
        $db_source_nb++;
        my $socket = IO::Socket::INET->new( PeerAddr => $db_source->string,
                                            PeerPort => q{43}, 
                                            Proto => q{tcp} );
        unless ( $socket ) { 
            if ( $db_source_nb == scalar @db_sources ) {
                return \@asns, undef, q{}, q{ERROR_ASN_DATABASE};
            }
            else {
                next;
            }
        };

        printf $socket "-F -M %s\n", $ip->short();

        my $data;
        my $str;
        my $has_answer = 0;
        while ( defined ($data = <$socket>) ) {
            $has_answer = 1;
            chop $data;
            if ( $data !~ /^%/x and $data !~ /^\s*$/x ) {
                $str = $data;
                last;
            }
        }
        $socket->close();
        if ( not $has_answer ) {
            if ( $db_source_nb == scalar @db_sources ) {
                return \@asns, undef, q{}, q{ERROR_ASN_DATABASE};
            }
            else {
                next;
            }
        }
        elsif ( $str )  {
            my @fields = split( /\s+/x, $str );
            my @asns   = split( '/',  $fields[0] );
            return \@asns, Net::IP::XS->new( $fields[1] ), $str, q{AS_FOUND};
        }
        else {
            return \@asns, undef, q{}, q{EMPTY_ASN_SET};
        }
    } ## end foreach my $db_source ( @
    return;
}

sub get {
    my ( $class, $ip ) = @_;

    my ( $asnref, $prefix, $raw, $ret_code ) = $class->get_with_prefix( $ip );

    if ( $asnref ) {
        return @{$asnref};
    }
    else {
        return;
    }
}

1;

=head1 NAME

Zonemaster::Engine::ASNLookup - do lookups of ASNs for IP addresses

=head1 SYNOPSIS

   my ( $asnref, $prefix, $raw, $ret_code ) = Zonemaster::Engine::ASNLookup->get_with_prefix( '8.8.4.4' );
   my $asnref = Zonemaster::Engine::ASNLookup->get( '192.168.0.1' );

=head1 FUNCTION

=over

=item get($addr)

As L<get_with_prefix()>, except it returns only the list of AS numbers
for the address, if any.

=item get_with_prefix($addr)

Takes a string (or a L<Net::IP::XS> object) with a single IP address, and
does a lookup in either: a) Cymru-style DNS zone or b) RIPE whois server,
depending on L<Zonemaster::Engine::Profile> setting "asn_db{style}".

Returns a list of a reference to a list of AS numbers, a Net::IP::XS object
of the covering prefix for that AS, a string of the raw query, and a string
of the return code for that query.

=back

=cut
