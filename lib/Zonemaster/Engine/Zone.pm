package Zonemaster::Engine::Zone;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare("v1.1.9");

use Carp qw( confess croak );
use List::MoreUtils qw[uniq];
use Zonemaster::Engine::DNSName;
use Zonemaster::Engine::Recursor;
use Zonemaster::Engine::NSArray;
use Zonemaster::Engine::Constants qw[:ip];

sub new {
    my ( $class, $attrs ) = @_;

    my $name = delete $attrs->{name} // confess "required argument 'name' not found";
    if ( %$attrs ) {
        confess "unexpected arguments: " . join ', ', sort keys %$attrs;
    }

    if ( blessed $name ne 'Zonemaster::Engine::DNSName' ) {
        confess "argument 'name' must be a Zonemaster::Engine::DNSName";
    }

    my $obj = { _name => $name };

    return bless $obj, $class;
}

sub name {
    my ( $self ) = @_;

    return $self->{_name};
}

sub parent {
    my ( $self ) = @_;

    if ( !exists $self->{_parent} ) {
        $self->{_parent} = $self->_build_parent;
    }

    return $self->{_parent};
}

sub glue_names {
    my ( $self ) = @_;

    if ( !exists $self->{_glue_names} ) {
        $self->{_glue_names} = $self->_build_glue_names;
    }

    return $self->{_glue_names};
}

sub glue {
    my ( $self ) = @_;

    if ( !exists $self->{_glue} ) {
        $self->{_glue} = $self->_build_glue;
    }

    return $self->{_glue};
}

sub ns_names {
    my ( $self ) = @_;

    if ( !exists $self->{_ns_names} ) {
        $self->{_ns_names} = $self->_build_ns_names;
    }

    return $self->{_ns_names};
}

sub ns {
    my ( $self ) = @_;

    if ( !exists $self->{_ns} ) {
        $self->{_ns} = $self->_build_ns;
    }

    return $self->{_ns};
}

sub glue_addresses {
    my ( $self ) = @_;

    if ( !exists $self->{_glue_addresses} ) {
        $self->{_glue_addresses} = $self->_build_glue_addresses;
    }

    return $self->{_glue_addresses};
}

###
### Builders
###

sub _build_parent {
    my ( $self ) = @_;

    if ( $self->name eq '.' ) {
        return $self;
    }

    my $pname = Zonemaster::Engine::Recursor->parent( q{} . $self->name );
    return if not $pname;
    ## no critic (Modules::RequireExplicitInclusion)
    return __PACKAGE__->new( { name => $pname } );
}

sub _build_glue_names {
    my ( $self ) = @_;

    if ( not $self->parent ) {
        return [];
    }

    my $p = $self->parent->query_persistent( $self->name, 'NS' );

    return [] if not defined $p;

    return [ uniq sort map { Zonemaster::Engine::DNSName->new( lc( $_->nsdname ) ) }
          $p->get_records_for_name( 'ns', $self->name->string ) ];
}

sub _build_glue {
    my ( $self ) = @_;
    my @glue_names = @{ $self->glue_names };
    my $zname = $self->name->string;

    if ( Zonemaster::Engine::Recursor->has_fake_addresses( $zname ) ) {
        my @ns_list;
        foreach my $ns ( @glue_names ) {
            foreach my $ip ( Zonemaster::Engine::Recursor->get_fake_addresses( $zname, $ns ) ) {
                push @ns_list, Zonemaster::Engine::Nameserver->new( { name => $ns, address => $ip } );
            }
        }
        return \@ns_list;
    }
    else {

        my $aref = [];
        tie @$aref, 'Zonemaster::Engine::NSArray', @glue_names;

        return $aref;
    }
}

sub _build_ns_names {
    my ( $self ) = @_;

    if ( $self->name eq '.' ) {
        my %u;
        $u{$_} = $_ for map { $_->name } @{ $self->ns };
        return [ sort values %u ];
    }

    my $p;
    my $i = 0;
    while ( my $s = $self->glue->[$i] ) {
        $p = $s->query( $self->name, 'NS' );
        last if ( defined( $p ) and ( $p->type eq 'answer' ) and ( $p->rcode eq 'NOERROR' ) );
        $i += 1;
    }
    return [] if not defined $p;

    return [ uniq sort map { Zonemaster::Engine::DNSName->new( lc( $_->nsdname ) ) }
          $p->get_records_for_name( 'ns', $self->name->string ) ];
} ## end sub _build_ns_names

sub _build_ns {
    my ( $self ) = @_;

    if ( $self->name eq '.' ) {    # Root is a special case
        return [ Zonemaster::Engine::Recursor->root_servers ];
    }

    my $aref = [];
    tie @$aref, 'Zonemaster::Engine::NSArray', @{ $self->ns_names };

    return $aref;
}

sub _build_glue_addresses {
    my ( $self ) = @_;

    if ( not $self->parent ) {
        return [];
    }

    my $p = $self->parent->query_one( $self->name, 'NS' );
    croak "Failed to get glue addresses" if not defined( $p );

    return [ $p->get_records( 'a' ), $p->get_records( 'aaaa' ) ];
}

sub _is_ip_version_disabled {
    my ( $ns, $type ) = @_;

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
        Zonemaster::Engine->logger->add(
            SKIP_IPV4_DISABLED => {
                ns     => $ns->string,
                rrtype => $type
            }
        );
        return 1;
    }

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
        Zonemaster::Engine->logger->add(
            SKIP_IPV6_DISABLED => {
                ns     => $ns->string,
                rrtype => $type
            }
        );
        return 1;
    }

    return 0;
}

###
### Public Methods
###

sub query_one {
    my ( $self, $name, $type, $flags ) = @_;

    # Return response from the first server that gives one
    my $i = 0;
    while ( my $ns = $self->ns->[$i] ) {
        if ( _is_ip_version_disabled( $ns, $type ) ) {
            next;
        }

        my $p = $ns->query( $name, $type, $flags );
        return $p if defined( $p );
    }
    continue {
        $i += 1;
    }

    return;
} ## end sub query_one

sub query_all {
    my ( $self, $name, $type, $flags ) = @_;

    my @servers = @{ $self->ns };

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) ) {
        my @nope = grep { $_->address->version == $IP_VERSION_4 } @servers;
        @servers = grep { $_->address->version == $IP_VERSION_6 } @servers;
        map {
            Zonemaster::Engine->logger->add(
               SKIP_IPV4_DISABLED => {
                   ns     => $_->string,
                   rrtype => $type
               }
            )
            } @nope;
        }

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) ) {
        my @nope = grep { $_->address->version == $IP_VERSION_6 } @servers;
        @servers = grep { $_->address->version == $IP_VERSION_4 } @servers;
        map {
            Zonemaster::Engine->logger->add(
                SKIP_IPV6_DISABLED => {
                    ns     => $_->string,
                    rrtype => $type
                }
            )
        } @nope;
    }

    return [ map { $_->query( $name, $type, $flags ) } @servers ];
}

sub query_auth {
    my ( $self, $name, $type, $flags ) = @_;

    # Return response from the first server that replies with AA set
    my $i = 0;
    while ( my $ns = $self->ns->[$i] ) {
        if ( _is_ip_version_disabled( $ns, $type ) ) {
            next;
        }

        my $p = $ns->query( $name, $type, $flags );
        if ( $p and $p->aa ) {
            return $p;
        }
    }
    continue {
        $i += 1;
    }

    return;
} ## end sub query_auth

sub query_persistent {
    my ( $self, $name, $type, $flags ) = @_;

    # Return response from the first server that has a record like the one asked for
    my $i = 0;
    while ( my $ns = $self->ns->[$i] ) {
        if ( _is_ip_version_disabled( $ns, $type ) ) {
            next;
        }

        my $p = $ns->query( $name, $type, $flags );
        if ( $p and scalar( $p->get_records_for_name( $type, $name ) ) > 0 ) {
            return $p;
        }
    }
    continue {
        $i += 1;
    }

    return;
} ## end sub query_persistent

sub is_in_zone {
    my ( $self, $name ) = @_;

    if ( not ref( $name ) or ref( $name ) ne 'Zonemaster::Engine::DNSName' ) {
        $name = Zonemaster::Engine::DNSName->new( $name );
    }

    if ( scalar( @{ $self->name->labels } ) != $self->name->common( $name ) ) {
        return 0;    # Zone name cannot be a suffix of tested name
    }

    my $p = $self->query_auth( "$name", 'SOA' );
    if ( not $p ) {
        return;
    }

    if ( $p->is_redirect ) {
        return 0;    # Authoritative servers redirect us, so name must be out-of-zone
    }

    my ( $soa ) = $p->get_records( 'SOA' );

    if ( not $soa ) {
        return 0;    # Auth server is broken, call it a "no".
    }

    if ( Zonemaster::Engine::DNSName->new( $soa->name ) eq $self->name ) {
        return 1;
    }
    else {
        return 0;
    }
} ## end sub is_in_zone

1;

=head1 NAME

Zonemaster::Engine::Zone - Object representing a DNS zone

=head1 SYNOPSIS

    my $zone = Zonemaster::Engine::Zone->new({ name => 'nic.se' });
    my $packet = $zone->parent->query_one($zone->name, 'NS');


=head1 DESCRIPTION

Objects of this class represent zones in DNS. As far as possible, test
implementations should access information about zones via these
objects. Doing so will provide lazy-loading of the information,
well-defined methods in which the information is fetched, logging and
the ability to do things like testing zones that have not yet been
delegated.

=head1 CONSTRUCTORS

=over

=item new

Construct a new instance.

=back

=head1 ATTRIBUTES

=over

=item name

A L<Zonemaster::Engine::DNSName> object representing the name of the zone.

=item parent

A L<Zonemaster::Engine::Zone> object for this domain's parent domain. As a
special case, the root zone is considered to be its own parent (so
look for that if you recurse up the tree).

=item ns_names

A reference to an array of L<Zonemaster::Engine::DNSName> objects, holding the
names of the nameservers for the domain, as returned by the first
responding nameserver in the glue list.

=item ns

A reference to an array of L<Zonemaster::Engine::Nameserver> objects for the
domain, built by taking the list returned from L<ns_names()> and
looking up addresses for the names. One element will be added to this
list for each unique name/IP pair. Names for which no addresses could
be found will not be in this list. The list is lazy-loading, so take
care to only look at as many entries as you really need. There are
zones with more than 20 nameserver, and looking up the addresses of
them all can take som considerable time.

=item glue_names

A reference to a an array of L<Zonemaster::Engine::DNSName> objects, holding the names
of this zones nameservers as listed at the first responding nameserver of the
parent zone.

=item glue

A reference to an array of L<Zonemaster::Engine::Nameserver> objects for the
domain, built by taking the list returned from L<glue_names()> and
looking up addresses for the names. One element will be added to this
list for each unique name/IP pair. Names for which no addresses could
be found will not be in this list. In this case, the list is lazy-loading, so take
care to only look at as many entries as you really need. In case of 
undelegated tests and fake delegation the IP associated with name servers
for the tested zone will be the ones set by users (saved in 
%Zonemaster::Engine::Recursor::fake_addresses_cache), instead of the ones
found recursively.

=item glue_addresses

A list of L<Zonemaster::LDNS::RR::A> and L<Zonemaster::LDNS::RR::AAAA> records returned in
the Additional section of an NS query to the first listed nameserver for the
parent domain.

=back

=head1 METHODS

=over

=item query_one($name[, $type[, $flags]])

Sends (or retrieves from cache) a query for the given name, type and flags sent to the first nameserver in the zone's ns list. If there is a
response, it will be returned in a L<Zonemaster::Engine::Packet> object. If the type arguments is not given, it defaults to 'A'. If the flags are not given, they default to C<class> IN and C<dnssec>, C<usevc> and C<recurse> according to configuration (which is by default off on all three).

=item query_persistent($name[, $type[, $flags]])

Identical to L<query_one>, except that instead of returning the packet from the
first server that returns one, it returns the first packet that actually
contains a resource record matching the requested name and type.

=item query_auth($name[, $type[, $flags]])

Identical to L<query_one>, except that instead of returning the packet from the
first server that returns one, it returns the first packet that has the AA flag set.

=item query_all($name, $type, $flags)

Sends (or retrieves from cache) queries to all the nameservers listed in the zone's ns list, and returns a reference to an array with the
responses. The responses can be either L<Zonemaster::Engine::Packet> objects or C<undef> values. The arguments are the same as for L<query_one>.

=item is_in_zone($name)

Returns true if the given name is in the zone, false if not. If it could not be
determined with a sufficient degree of certainty if the name is in the zone or
not, C<undef> is returned.

=back

=cut
