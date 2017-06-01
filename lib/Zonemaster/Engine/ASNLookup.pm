package Zonemaster::Engine::ASNLookup;

use version; our $VERSION = version->declare("v1.0.3");

use 5.014002;
use warnings;

use Zonemaster::Engine::Net::IP;

use Zonemaster;
use Zonemaster::Engine::Nameserver;

our @roots;

sub get_with_prefix {
    my ( $class, $ip ) = @_;

    if ( not @roots ) {
        @roots = map { Zonemaster->zone( $_ ) } @{ Zonemaster->config->asnroots };
    }

    if ( not ref( $ip ) or not $ip->isa( 'Zonemaster::Engine::Net::IP' ) ) {
        $ip = Zonemaster::Engine::Net::IP->new( $ip );
    }

    my $reverse = $ip->reverse_ip;
    foreach my $zone ( @roots ) {
        my $domain = $zone->name->string;
        my $pair   = {
            'in-addr.arpa.' => "origin.$domain",
            'ip6.arpa.'     => "origin6.$domain",
        };
        foreach my $root ( keys %{$pair} ) {
            if ( $reverse =~ s/$root/$pair->{$root}/ix ) {
                my $p = $zone->query_persistent( $reverse, 'TXT' );
                next if not $p;

                my ( $rr ) = $p->get_records( 'TXT' );
                return if not $rr;

                my $str = $rr->txtdata;
                $str =~ s/"([^"]+)"/$1/x;
                my @fields = split( /[ ]\|[ ]?/x, $str );
                my @asns   = split( /\s+/x,       $fields[0] );

                return \@asns, Zonemaster::Engine::Net::IP->new( $fields[1] ), $str;
            }
        }
    } ## end foreach my $zone ( @roots )
    return;
} ## end sub get_with_prefix

sub get {
    my ( $class, $ip ) = @_;

    my ( $asnref, $prefix, $raw ) = $class->get_with_prefix( $ip );

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

   my ($asnref, $prefix) = Zonemaster::Engine::ASNLookup->get_with_prefix( '8.8.4.4' );
   my $asnref = Zonemaster::Engine::ASNLookup->get( '192.168.0.1' );

=head1 FUNCTION

=over

=item get($addr)

Takes a string (or a L<Net::IP> object) with a single IP address, does a lookup
in a Cymru-style DNS zone and returns a list of AS numbers for the address, if
any can be found.

=item get_with_prefix($addr)

As L<get()>, except it returns a list of a reference to a list with the AS
numbers, and a Net::IP object representing the prefix of the AS.

=back

=cut
