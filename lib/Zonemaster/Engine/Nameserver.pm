package Zonemaster::Engine::Nameserver;

use version; our $VERSION = version->declare("v1.1.3");

use 5.014002;
use Moose;
use Moose::Util::TypeConstraints;

use Zonemaster::Engine::DNSName;
use Zonemaster;
use Zonemaster::Packet;
use Zonemaster::Engine::Nameserver::Cache;
use Zonemaster::Engine::Recursor;
use Zonemaster::Engine::Constants ':misc';

use Net::LDNS;

use Zonemaster::Engine::Net::IP qw(:PROC);
use Time::HiRes qw[time];
use JSON::PP;
use MIME::Base64;
use Module::Find qw[useall];
use Carp;
use List::Util qw[max min sum];
use POSIX ();

use overload
  '""'  => \&string,
  'cmp' => \&compare;

coerce 'Zonemaster::Engine::Net::IP', from 'Str', via { Zonemaster::Engine::Net::IP->new( $_ ) };

has 'name'    => ( is => 'ro', isa => 'Zonemaster::Engine::DNSName', coerce => 1, required => 0 );
has 'address' => ( is => 'ro', isa => 'Zonemaster::Engine::Net::IP', coerce => 1, required => 1 );

has 'dns'   => ( is => 'ro', isa => 'Net::LDNS',                     lazy_build => 1 );
has 'cache' => ( is => 'ro', isa => 'Zonemaster::Engine::Nameserver::Cache', lazy_build => 1 );
has 'times' => ( is => 'ro', isa => 'ArrayRef',                      default    => sub { [] } );

has 'source_address' =>
  ( is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => sub { return Zonemaster->config->resolver_source } );

has 'fake_delegations' => ( is => 'ro', isa => 'HashRef', default => sub { {} } );
has 'fake_ds'          => ( is => 'ro', isa => 'HashRef', default => sub { {} } );

has 'blacklisted' => ( is => 'rw', isa => 'HashRef', default => sub { {} }, required => 1 );

###
### Variables
###

our %object_cache;

###
### Build methods for attributes
###

around 'new' => sub {
    my $orig = shift;
    my $self = shift;

    my $obj  = $self->$orig( @_ );
    my $name = lc( q{} . $obj->name );
    $name = '$$$NONAME' unless $name;
    if ( not exists $object_cache{$name}{ $obj->address->ip } ) {
        Zonemaster->logger->add( NS_CREATED => { name => $name, ip => $obj->address->ip } );
        $object_cache{$name}{ $obj->address->ip } = $obj;
    }

    return $object_cache{$name}{ $obj->address->ip };
};

sub _build_dns {
    my ( $self ) = @_;

    my $res = Net::LDNS->new( $self->address->ip );
    $res->recurse( 0 );

    my %defaults = %{ Zonemaster->config->resolver_defaults };
    foreach my $flag ( keys %defaults ) {
        $res->$flag( $defaults{$flag} );
    }

    if ( $self->source_address ) {
        $res->source( $self->source_address );
    }

    return $res;
}

sub _build_cache {
    my ( $self ) = @_;

    Zonemaster::Engine::Nameserver::Cache->new( { address => $self->address } );
}

###
### Public Methods (and helpers)
###

sub query {
    my ( $self, $name, $type, $href ) = @_;
    $type //= 'A';

    if ( $self->address->version == 4 and not Zonemaster->config->ipv4_ok ) {
        Zonemaster->logger->add( IPV4_BLOCKED => { ns => $self->string } );
        return;
    }

    if ( $self->address->version == 6 and not Zonemaster->config->ipv6_ok ) {
        Zonemaster->logger->add( IPV6_BLOCKED => { ns => $self->string } );
        return;
    }

    Zonemaster->logger->add(
        'query',
        {
            name  => "$name",
            type  => $type,
            flags => $href,
            ip    => $self->address->short
        }
    );

    my %defaults = %{ Zonemaster->config->resolver_defaults };

    my $class     = $href->{class}     // 'IN';
    my $dnssec    = $href->{dnssec}    // $defaults{dnssec};
    my $usevc     = $href->{usevc}     // $defaults{usevc};
    my $recurse   = $href->{recurse}   // $defaults{recurse};
    my $edns_size = $href->{edns_size} // $defaults{edns_size};

    # Fake a DS answer
    if ( $type eq 'DS' and $class eq 'IN' and $self->fake_ds->{ lc( $name ) } ) {
        my $p = Net::LDNS::Packet->new( $name, $type, $class );
        $p->aa( 1 );
        $p->do( $dnssec );
        $p->rd( $recurse );
        foreach my $rr ( @{ $self->fake_ds->{ lc( $name ) } } ) {
            $p->unique_push( 'answer', $rr );
        }
        my $res = Zonemaster::Packet->new( { packet => $p } );
        Zonemaster->logger->add( FAKE_DS_RETURNED => { name => "$name", from => "$self" } );
        return $res;
    }

    # Fake a delegation
    foreach my $fname ( sort keys %{ $self->fake_delegations } ) {
        if ( $name =~ m/([.]|\A)\Q$fname\E\z/xi ) {
            my $p = Net::LDNS::Packet->new( $name, $type, $class );

            if ( lc( $name ) eq lc( $fname ) and $type eq 'NS' ) {
                my $name = $self->fake_delegations->{$fname}{authority};
                my $addr = $self->fake_delegations->{$fname}{additional};
                $p->unique_push( 'answer',     $_ ) for @{$name};
                $p->unique_push( 'additional', $_ ) for @{$addr};
            }
            else {
                while ( my ( $section, $aref ) = each %{ $self->fake_delegations->{$fname} } ) {
                    $p->unique_push( $section, $_ ) for @{$aref};
                }
            }

            $p->aa( 0 );
            $p->do( $dnssec );
            $p->rd( $recurse );
            $p->answerfrom( $self->address->ip );
            Zonemaster->logger->add(
                'FAKE_DELEGATION',
                {
                    name  => "$name",
                    type  => $type,
                    class => $class,
                    from  => "$self",
                }
            );

            my $res = Zonemaster::Packet->new( { packet => $p } );
            Zonemaster->logger->add( FAKED_RETURN => { packet => $res->string } );
            return $res;
        } ## end if ( $name =~ m/([.]|\A)\Q$fname\E\z/xi)
    } ## end foreach my $fname ( sort keys...)

    if ( not exists( $self->cache->data->{"$name"}{"\U$type"}{"\U$class"}{$dnssec}{$usevc}{$recurse}{$edns_size} ) ) {
        $self->cache->data->{"$name"}{"\U$type"}{"\U$class"}{$dnssec}{$usevc}{$recurse}{$edns_size} =
          $self->_query( $name, $type, $href );
    }

    my $p = $self->cache->data->{"$name"}{"\U$type"}{"\U$class"}{$dnssec}{$usevc}{$recurse}{$edns_size};
    Zonemaster->logger->add( CACHED_RETURN => { packet => ( $p ? $p->string : 'undef' ) } );

    return $p;
} ## end sub query

sub add_fake_delegation {
    my ( $self, $domain, $href ) = @_;
    my %delegation;

    $domain = q{} . Zonemaster::Engine::DNSName->new( $domain );
    foreach my $name ( keys %{$href} ) {
        push @{ $delegation{authority} }, Net::LDNS::RR->new( sprintf( '%s IN NS %s', $domain, $name ) );
        foreach my $ip ( @{ $href->{$name} } ) {
            if ( Zonemaster::Engine::Net::IP->new( $ip )->ip eq $self->address->ip ) {
                Zonemaster->logger->add(
                    FAKE_DELEGATION_TO_SELF => { ns => "$self", domain => $domain, data => $href } );
                return;
            }

            push @{ $delegation{additional} },
              Net::LDNS::RR->new( sprintf( '%s IN %s %s', $name, ( Zonemaster::Engine::Net::IP::ip_is_ipv6( $ip ) ? 'AAAA' : 'A' ), $ip ) );
        }
    }

    $self->fake_delegations->{$domain} = \%delegation;
    Zonemaster->logger->add( ADDED_FAKE_DELEGATION => { ns => "$self", domain => $domain, data => $href } );

    # We're changing the world, so the cache can't be trusted
    Zonemaster::Engine::Recursor->clear_cache;

    return;
} ## end sub add_fake_delegation

sub add_fake_ds {
    my ( $self, $domain, $aref ) = @_;
    my @ds;

    if ( not ref $domain ) {
        $domain = Zonemaster::Engine::DNSName->new( $domain );
    }

    Zonemaster->logger->add( FAKE_DS => { domain => lc( "$domain" ), data => $aref, ns => "$self" } );
    foreach my $href ( @{$aref} ) {
        push @ds,
          Net::LDNS::RR->new(
            sprintf(
                '%s IN DS %d %d %d %s',
                "$domain", $href->{keytag}, $href->{algorithm}, $href->{type}, $href->{digest}
            )
          );
    }

    $self->fake_ds->{ lc( "$domain" ) } = \@ds;

    # We're changing the world, so the cache can't be trusted
    Zonemaster::Engine::Recursor->clear_cache;

    return;
} ## end sub add_fake_ds

sub _query {
    my ( $self, $name, $type, $href ) = @_;
    my %flags;

    $type //= 'A';
    $href->{class} //= 'IN';

    if ( Zonemaster->config->no_network ) {
        croak sprintf
          "External query for %s, %s attempted to %s while running with no_network",
          $name, $type, $self->string;
    }

    Zonemaster->logger->add(
        'external_query',
        {
            name  => "$name",
            type  => $type,
            flags => $href,
            ip    => $self->address->short
        }
    );

    my %defaults = %{ Zonemaster->config->resolver_defaults };

    # Make sure we have a value for each flag
    foreach my $flag ( keys %defaults ) {
        $flags{$flag} = $href->{$flag} // $defaults{$flag};
    }

    # Set flags for this query
    foreach my $flag ( keys %flags ) {
        $self->dns->$flag( $flags{$flag} );
    }

    my $before = time();
    my $res;
    if ( $self->blacklisted->{ $flags{usevc} }{ $flags{dnssec} } ) {
        Zonemaster->logger->add(
            IS_BLACKLISTED => {
                message => "Server transport has been blacklisted due to previous failure",
                ns      => "$self",
                name    => "$name",
                type    => $type,
                class   => $href->{class},
                proto   => $flags{usevc} ? q{TCP} : q{UDP},
                dnssec  => $flags{dnssec}
            }
        );
    }
    else {
        $res = eval { $self->dns->query( "$name", $type, $href->{class} ) };
        if ( $@ ) {
            my $msg = "$@";
            chomp( $msg );
            Zonemaster->logger->add( LOOKUP_ERROR =>
                  { message => $msg, ns => "$self", name => "$name", type => $type, class => $href->{class} } );
            $self->blacklisted->{ $flags{usevc} }{ $flags{dnssec} } = 1;
            if ( !$flags{dnssec} ) {
                $self->blacklisted->{ $flags{usevc} }{ !$flags{dnssec} } = 1;
            }
        }
    }
    push @{ $self->times }, ( time() - $before );

    # Reset to defaults
    foreach my $flag ( keys %flags ) {
        $self->dns->$flag( $defaults{$flag} );
    }

    if ( $res ) {
        my $p = Zonemaster::Packet->new( { packet => $res } );
        my $size = length( $p->data );
        if ( $size > $UDP_COMMON_EDNS_LIMIT ) {
            my $command = sprintf q{dig @%s %s%s %s}, $self->address->short, $flags{dnssec} ? q{+dnssec } : q{},
              "$name", $type;
            Zonemaster->logger->add(
                PACKET_BIG => { size => $size, maxsize => $UDP_COMMON_EDNS_LIMIT, command => $command } );
        }
        Zonemaster->logger->add( EXTERNAL_RESPONSE => { packet => $p->string } );
        return $p;
    }
    else {
        Zonemaster->logger->add( EMPTY_RETURN => {} );
        return;
    }
} ## end sub _query

sub string {
    my ( $self ) = @_;

    return $self->name->string . q{/} . $self->address->short;
}

sub compare {
    my ( $self, $other, $reverse ) = @_;

    return $self->string cmp $other->string;
}

sub save {
    my ( $class, $filename ) = @_;

    my $old = POSIX::setlocale( POSIX::LC_ALL, 'C' );
    my $json = JSON::PP->new->allow_blessed->convert_blessed;
    open my $fh, '>', $filename or die "Cache save failed: $!";
    foreach my $name ( keys %object_cache ) {
        foreach my $addr ( keys %{ $object_cache{$name} } ) {
            say $fh "$name $addr " . $json->encode( $object_cache{$name}{$addr}->cache->data );
        }
    }

    close $fh or die $!;

    Zonemaster->logger->add( SAVED_NS_CACHE => { file => $filename } );

    POSIX::setlocale( POSIX::LC_ALL, $old );
    return;
}

sub restore {
    my ( $class, $filename ) = @_;

    useall 'Net::LDNS::RR';
    my $decode = JSON::PP->new->filter_json_single_key_object(
        'Net::LDNS::Packet' => sub {
            my ( $ref ) = @_;
            ## no critic (Modules::RequireExplicitInclusion)
            my $obj = Net::LDNS::Packet->new_from_wireformat( decode_base64( $ref->{data} ) );
            $obj->answerfrom( $ref->{answerfrom} );
            $obj->timestamp( $ref->{timestamp} );

            return $obj;
        }
      )->filter_json_single_key_object(
        'Zonemaster::Packet' => sub {
            my ( $ref ) = @_;

            return Zonemaster::Packet->new( { packet => $ref } );
        }
      );

    open my $fh, '<', $filename or die "Failed to open restore data file: $!\n";
    while ( my $line = <$fh> ) {
        my ( $name, $addr, $data ) = split( / /, $line, 3 );
        my $ref = $decode->decode( $data );
        my $ns  = Zonemaster::Engine::Nameserver->new(
            {
                name    => $name,
                address => $addr,
                cache   => Zonemaster::Engine::Nameserver::Cache->new( { data => $ref, address => Zonemaster::Engine::Net::IP->new( $addr ) } )
            }
        );
    }
    close $fh;

    Zonemaster->logger->add( RESTORED_NS_CACHE => { file => $filename } );

    return;
} ## end sub restore

sub max_time {
    my ( $self ) = @_;

    return max( @{ $self->times } ) // 0;
}

sub min_time {
    my ( $self ) = @_;

    return min( @{ $self->times } ) // 0;
}

sub sum_time {
    my ( $self ) = @_;

    return sum( @{ $self->times } ) // 0;
}

sub average_time {
    my ( $self ) = @_;

    return 0 if @{ $self->times } == 0;

    return ( $self->sum_time / scalar( @{ $self->times } ) );
}

sub median_time {
    my ( $self ) = @_;

    my @t = sort { $a <=> $b } @{ $self->times };
    my $c = scalar( @t );
    if ( $c == 0 ) {
        return 0;
    }
    elsif ( $c % 2 == 0 ) {
        return ( $t[ $c / 2 ] + $t[ ( $c / 2 ) - 1 ] ) / 2;
    }
    else {
        return $t[ int( $c / 2 ) ];
    }
}

sub stddev_time {
    my ( $self ) = @_;

    my $avg = $self->average_time;
    my $c   = scalar( @{ $self->times } );

    return 0 if $c == 0;

    return sqrt( sum( map { ( $_ - $avg )**2 } @{ $self->times } ) / $c );
}

sub all_known_nameservers {
    my @res;

    foreach my $n ( values %object_cache ) {
        push @res, values %{$n};
    }

    return @res;
}

sub axfr {
    my ( $self, $domain, $callback, $class ) = @_;
    $class //= 'IN';

    if ( Zonemaster->config->no_network ) {
        croak sprintf
          "External AXFR query for %s attempted to %s while running with no_network",
          $domain, $self->string;
    }

    if ( $self->address->version == 4 and not Zonemaster->config->ipv4_ok ) {
        Zonemaster->logger->add( IPV4_BLOCKED => { ns => $self->string } );
        return;
    }

    if ( $self->address->version == 6 and not Zonemaster->config->ipv6_ok ) {
        Zonemaster->logger->add( IPV6_BLOCKED => { ns => $self->string } );
        return;
    }

    return $self->dns->axfr( $domain, $callback, $class );
} ## end sub axfr

sub empty_cache {
    %object_cache = ();

    Zonemaster::Engine::Nameserver::Cache::empty_cache();

    return;
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;

=head1 NAME

Zonemaster::Engine::Nameserver - object representing a DNS nameserver

=head1 SYNOPSIS

    my $ns = Zonemaster::Engine::Nameserver->new({ name => 'ns.nic.se', address => '212.247.7.228' });
    my $p = $ns->query('www.iis.se', 'AAAA');

=head1 DESCRIPTION

This is a very central object in the L<Zonemaster> framework. All DNS
communications with the outside world pass through here, so we can do
things like synthezising and recording traffic. All the objects are
also unique per name/IP pair, and creating a new one with an already
existing pair will return the existing object instead of creating a
new one. Queries and their responses are cached by IP address, so that
a specific query will only be sent once to each address (even if there
are multiple objects for that address with different names).

Class methods on this class allows saving and loading cache contents.

=head1 ATTRIBUTES

=over

=item name

A L<Zonemaster::Engine::DNSName> object holding the nameserver's name.

=item address

A L<Zonemaster::Engine::Net::IP> object holding the nameserver's address.

=item dns

The L<Net::LDNS> object used to actually send and recieve DNS queries.

=item cache

A reference to a L<Zonemaster::Engine::Nameserver::Cache> object holding the cache of sent queries. Not meant for external use.

=item times

A reference to a list with elapsed time values for the queries made through this nameserver.

=back

=head1 CLASS METHODS

=over

=item save($filename)

Save the entire object cache to the given filename, using the
byte-order-independent Storable format.

=item restore($filename)

Replace the entire object cache with the contents of the named file.

=item all_known_nameservers()

Class method that returns a list of all nameserver objects in the global cache.

=item empty_cache()

Remove all cached nameserver objects and queries.

=back

=head1 INSTANCE METHODS

=over

=item query($name, $type, $flagref)

Send a DNS query to the nameserver the object represents. C<$name> and C<$type> are the name and type that will be queried for (C<$type> defaults
to 'A' if it's left undefined). C<$flagref> is a reference to a hash, the keys of which are flags and the values are their corresponding values.
The available flags are as follows. All but the first directly correspond to methods in the L<Net::LDNS::Resolver> object.

=over

=item class

Defaults to 'IN' if not set.

=item usevc

Send the query via TCP (only).

=item retrans

The retransmission interval

=item dnssec

Set the DO flag in the query.

=item debug

Set the debug flag in the resolver, producing output on STDERR as the query process proceeds.

=item recurse

Set the RD flag in the query.

=item udp_timeout

Set the UDP timeout for the outgoing UDP socket. May or may not be observed by the underlying network stack.

=item tcp_timeout

Set the TCP timeout for the outgoing TCP socket. May or may not be observed by the underlying network stack.

=item retry

Set the number of times the query is tried.

=item igntc

If set to true, incoming response packets with the TC flag set are not automatically retried over TCP.

=back

=item string()

Returns a string representation of the object. Normally this is just the name and IP address separated by a slash.

=item compare($other)

Used for overloading comparison operators.

=item sum_time()

Returns the total time spent sending queries and waiting for responses.

=item min_time()

Returns the shortest time spent on a query.

=item max_time()

Returns the longest time spent on a query.

=item average_time()

Returns the average time spent on queries.

=item median_time()

Returns the median query time.

=item stddev_time()

Returns the standard deviation for the whole set of query times.

=item add_fake_delegation($domain,$data)

Adds fake delegation information to this specific nameserver object. Takes the
same arguments as the similarly named method in L<Zonemaster>. This is
primarily used for internal information, and using it directly will likely give
confusing results (but may be useful to model certain kinds of
misconfigurations).

=item add_fake_ds($domain, $data)

Adds fake DS information to this nameserver object. Takes the same arguments as
the similarly named method in L<Zonemaster>.

=item axfr( $domain, $callback, $class )

Does an AXFR for the requested domain from the nameserver. The callback
function will be called once for each received RR, with that RR as its only
argument. To continue getting more RRs, the callback must return a true value.
If it returns a true value, the AXFR will be aborted. See L<Net::LDNS::axfr>
for more details.

=back

=cut
