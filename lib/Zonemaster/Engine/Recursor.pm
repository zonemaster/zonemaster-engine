package Zonemaster::Engine::Recursor;

use version; our $VERSION = version->declare("v1.0.10");

use 5.014002;
use warnings;

use Carp;
use Class::Accessor "antlers";
use File::ShareDir qw[dist_file];
use File::Slurp qw( read_file );
use JSON::PP;
use Zonemaster::Engine::Util;
use Zonemaster::Engine::Net::IP;
use Zonemaster::Engine;

my $seed_data;

our %recurse_cache;
our %_fake_addresses_cache;


sub get_default_path {
    state $path =
        length( $ENV{ZONEMASTER_ENGINE_ROOT_HINTS_FILE} )    ? $ENV{ZONEMASTER_ENGINE_ROOT_HINTS_FILE}
      : -e '/etc/zonemaster/root-hints.json'                 ? '/etc/zonemaster/root-hints.json'
      : -e '/usr/local/etc/zonemaster/root-hints.json'       ? '/usr/local/etc/zonemaster/root-hints.json'
      :                                                        eval { dist_file( 'Zonemaster-Engine', 'root-hints.json' ) };
    return $path // croak "File not found: root-hints.json\n";
}

sub add_fake_addresses {
    my ( $self, $domain, $href ) = @_;
    $domain = lc $domain;

    foreach my $name ( keys %{$href} ) {
        my @ips = @{ $href->{$name} };
        $name = lc $name;

        push @{ $_fake_addresses_cache{$domain}{$name} }, ();
        foreach my $ip ( @ips ) {
            push @{ $_fake_addresses_cache{$domain}{$name} }, $ip;
        }
    }

    return;
}

sub has_fake_addresses {
    my ( undef, $domain ) = @_;
    $domain = lc $domain;

    return !!$_fake_addresses_cache{$domain};
}

sub get_fake_addresses {
    my ( undef, $domain, $nsname ) = @_;
    ( defined $domain ) or croak 'Argument must be defined: $domain';

    $domain = lc $domain;
    $nsname = ( defined $nsname ) ? lc $nsname : q{};

    if ( exists $_fake_addresses_cache{$domain}{$nsname} ) {
        return @{ $_fake_addresses_cache{$domain}{$nsname} };
    }
    else {
        return ();
    }
}

sub recurse {
    my ( $self, $name, $type, $class ) = @_;
    $name = name( $name );
    $type  //= 'A';
    $class //= 'IN';

    Zonemaster::Engine->logger->add( RECURSE => { name => $name, type => $type, class => $class } );
    if ( exists $recurse_cache{$name}{$type}{$class} ) {
        return $recurse_cache{$name}{$type}{$class};
    }

    my ( $p, $state ) =
      $self->_recurse( $name, $type, $class,
        { ns => [ root_servers() ], count => 0, common => 0, seen => {}, glue => {} } );
    $recurse_cache{$name}{$type}{$class} = $p;

    return $p;
}

sub parent {
    my ( $self, $name ) = @_;
    $name = name( $name );

    my ( $p, $state ) =
      $self->_recurse( $name, 'SOA', 'IN',
        { ns => [ root_servers() ], count => 0, common => 0, seen => {}, glue => {} } );

    my $pname;
    if ( name( $state->{trace}[0][0] ) eq name( $name ) ) {
        $pname = name( $state->{trace}[1][0] );
    }
    else {
        $pname = name( $state->{trace}[0][0] );
    }

    # Extra check that parent really is parent.
    if ( $name->next_higher ne $pname ) {
        my $source_ns = $state->{trace}[0][1];
        my $source_ip = $state->{trace}[0][2];

        # No $source_ns means we're looking at root taken from priming
        if ( $source_ns ) {
            my $pp;
            if ( $source_ns->can( 'query' ) ) {
                $pp = $source_ns->query( $name->next_higher->string, 'SOA' );
            }
            else {
                my $n = ns( $source_ns, $source_ip );
                $pp = $n->query( $name->next_higher->string, 'SOA' );
            }
            if ( $pp ) {
                my ( $rr ) = $pp->get_records( 'SOA', 'answer' );
                if ( $rr ) {
                    $pname = name( $rr->owner );
                }
            }
        }
    } ## end if ( $name->next_higher...)

    if ( wantarray() ) {
        return ( $pname, $p );
    }
    else {
        return $pname;
    }
} ## end sub parent

sub _recurse {
    my ( $self, $name, $type, $class, $state ) = @_;
    $name = q{} . name( $name );

    if ( $state->{in_progress}{$name}{$type} ) {
        return;
    }
    $state->{in_progress}{$name}{$type} = 1;

    while ( my $ns = pop @{ $state->{ns} } ) {
        my $nsname    = $ns->can( 'name' )    ? q{} . $ns->name  : q{};
        my $nsaddress = $ns->can( 'address' ) ? $ns->address->ip : q{};
        Zonemaster::Engine->logger->add(
            RECURSE_QUERY => {
                source  => "$ns",
                ns      => $nsname,
                address => $nsaddress,
                name    => $name,
                type    => $type,
                class   => $class
            }
        );
        my $p = $self->_do_query( $ns, $name, $type, { class => $class }, $state );

        next if not $p;    # Ask next server if no response

        if ( $p->rcode eq 'REFUSED' or $p->rcode eq 'SERVFAIL' ) {
            # Respond with these if we can't get a better response
            $state->{candidate} = $p;
            next;
        }

        if ( $p->no_such_record ) {    # Node exists, but not record
            return ( $p, $state );
        }

        if ( $p->no_such_name ) {      # Node does not exist
            return ( $p, $state );
        }

        if ( $self->_is_answer( $p ) ) {    # Return answer
            return ( $p, $state );
        }

        # So it's not an error, not an empty response and not an answer

        if ( $p->is_redirect ) {
            my $zname = name( lc( ( $p->get_records( 'ns' ) )[0]->name ) );

            next if $zname eq '.';          # Redirect to root is never right.

            next if $state->{seen}{$zname}; # We followed this redirect before

            $state->{seen}{$zname} = 1;
            my $common = name( $zname )->common( name( $state->{qname} ) );

            next
              if $common < $state->{common};    # Redirect going up the hierarchy is not OK

            $state->{common} = $common;
            $state->{ns} = $self->get_ns_from( $p, $state );    # Follow redirect
            $state->{count} += 1;
            return ( undef, $state ) if $state->{count} > 20;    # Loop protection
            unshift @{ $state->{trace} }, [ $zname, $ns, $p->answerfrom ];

            next;
        } ## end if ( $p->is_redirect )
    } ## end while ( my $ns = pop @{ $state...})
    return ( $state->{candidate}, $state ) if $state->{candidate};

    return ( undef, $state );
} ## end sub _recurse

sub _do_query {
    my ( $self, $ns, $name, $type, $opts, $state ) = @_;

    if ( ref( $ns ) and $ns->can( 'query' ) ) {
        my $p = $ns->query( $name, $type, $opts );

        if ( $p ) {
            for my $rr ( grep { $_->type eq 'A' or $_->type eq 'AAAA' } $p->answer, $p->additional ) {
                $state->{glue}{ lc( Zonemaster::Engine::DNSName->from_string( $rr->name ) ) }{ $rr->address } = 1;
            }
        }
        return $p;
    }
    elsif ( my $href = $state->{glue}{ lc( name( $ns ) ) } ) {
        foreach my $addr ( keys %$href ) {
            my $realns = ns( $ns, $addr );
            my $p = $self->_do_query( $realns, $name, $type, $opts, $state );
            if ( $p ) {
                return $p;
            }
        }
    }
    else {
        $state->{glue}{ lc( name( $ns ) ) } = {};
        my @addr = $self->get_addresses_for( $ns, $state );
        if ( @addr > 0 ) {
            foreach my $addr ( @addr ) {
                $state->{glue}{ lc( name( $ns ) ) }{ $addr->short } = 1;
                my $new = ns( $ns, $addr->short );
                my $p = $new->query( $name, $type, $opts );
                return $p if $p;
            }
        }
        else {
            return;
        }
    }
} ## end sub _do_query

sub get_ns_from {
    my ( $self, $p, $state ) = @_;
    my ( @new, @extra );

    my @names = sort map { Zonemaster::Engine::DNSName->from_string( lc( $_->nsdname ) ) } $p->get_records( 'ns' );

    $state->{glue}{ lc( Zonemaster::Engine::DNSName->from_string( $_->name ) ) }{ $_->address } = 1
      for ( $p->get_records( 'a' ), $p->get_records( 'aaaa' ) );

    foreach my $name ( @names ) {
        if ( exists $state->{glue}{ lc( $name ) } ) {
            for my $addr ( keys %{ $state->{glue}{ lc( $name ) } } ) {
                push @new, ns( $name, $addr );
            }
        }
        else {
            push @extra, $name;
        }
    }

    @new = sort { $a->name cmp $b->name or $a->address->ip cmp $b->address->ip } @new;
    @extra = sort { $a cmp $b } @extra;

    return [ @new, @extra ];
} ## end sub get_ns_from

sub get_addresses_for {
    my ( $self, $name, $state ) = @_;
    my @res;
    $state //=
      { ns => [ root_servers() ], count => 0, common => 0, seen => {} };

    my ( $pa ) = $self->_recurse(
        "$name", 'A', 'IN',
        {
            ns          => [ root_servers() ],
            count       => $state->{count},
            common      => 0,
            in_progress => $state->{in_progress},
            glue        => $state->{glue}
        }
    );

    # Name does not exist, just stop
    if ( $pa and $pa->no_such_name ) {
        return;
    }

    my ( $paaaa ) = $self->_recurse(
        "$name", 'AAAA', 'IN',
        {
            ns          => [ root_servers() ],
            count       => $state->{count},
            common      => 0,
            in_progress => $state->{in_progress},
            glue        => $state->{glue}
        }
    );

    my @rrs;
    my %cname;
    if ( $pa ) {
        push @rrs, $pa->get_records( 'a' );
        $cname{ $_->cname } = 1 for $pa->get_records_for_name( 'CNAME', $name );
    }
    if ( $paaaa ) {
        push @rrs, $paaaa->get_records( 'aaaa' );
        $cname{ $_->cname } = 1 for $paaaa->get_records_for_name( 'CNAME', $name );
    }

    foreach my $rr ( sort { $a->address cmp $b->address } @rrs ) {
        if ( name( $rr->name ) eq $name or $cname{ $rr->name } ) {
            push @res, Zonemaster::Engine::Net::IP->new( $rr->address );
        }
    }
    return @res;
} ## end sub get_addresses_for

sub _is_answer {
    my ( $self, $packet ) = @_;

    return ( $packet->type eq 'answer' );
}

sub clear_cache {
    %recurse_cache = ();
}

sub root_servers {
    my $path = get_default_path();
    my $json = read_file $path;
    {
        local $/;
        $seed_data = decode_json $json;
    }

    return croak "File not valid: $path\n" unless $seed_data;

    return map { Zonemaster::Engine::Util::ns( $_->{name}, $_->{address} ) }
      sort { $a->{name} cmp $b->{name} } @{ $seed_data->{'.'} };
}

1;

=head1 NAME

Zonemaster::Engine::Recursor - recursive resolver for Zonemaster

=head1 SYNOPSIS

    my $packet = Zonemaster::Engine::Recursor->recurse($name, $type, $class);
    my $pname = Zonemaster::Engine::Recursor->parent('example.org');

=head1 CLASS VARIABLES

=over

=item %recurse_cache

Will cache result of previous queries.

=item %_fake_addresses_cache

A hash of hashrefs of arrayrefs.
The keys of the top level hash are domain names.
The keys of the second level hashes are name server names (normalized to lower
case).
The elements of the third level arrayrefs are IP addresses.

The IP addresses are those of the nameservers which are used in case of fake
delegations (pre-publication tests).

=back

=head1 METHODS

=head2 get_default_path

Determine the path for the default root-hints.json file.
A list of values and locations are checked and the first match is returned.
If all places are checked and no file is found, an exception is thrown.

This procedure is idempotent - i.e. if you call this procedure multiple times
the same value is returned no matter if environment variables or the file system
have changed.

The following checks are made in order:

=over 4

=item $ZONEMASTER_ENGINE_ROOT_HINTS_FILE

If this environment variable is set ot a truthy value, that path is returned.

=item /etc/zonemaster/root-hints.json

If a file exists at this path, it is returned.

=item /usr/local/etc/zonemaster/root-hints.json

If a file exists at such a path, it is returned.

=item DIST_DIR/root-hints.json

If a file exists at this path, it is returned.
DIST_DIR is wherever File::ShareDir installs the Zonemaster-Engine dist.

=back

=head2 Other mothods

=over

=item recurse($name, $type, $class)

Does a recursive resolution from the root servers down for the given triplet.

=item parent($name)

Does a recursive resolution from the root down for the given name (using type C<SOA> and class C<IN>). If the resolution is successful, it returns
the domain name of the second-to-last step. If the resolution is unsuccessful, it returns the domain name of the last step.

=item get_ns_from($packet, $state)

Internal method. Takes a packet and a recursion state and returns a list of ns objects. Used to follow redirections.

=item get_addresses_for($name[, $state])

Takes a name and returns a (possibly empty) list of IP addresses for
that name (in the form of L<Zonemaster::Engine::Net::IP> objects). When used
internally by the recursor it's passed a recursion state as its second
argument.

=item add_fake_addresses($domain, $data)

Class method to create fake adresses for fake delegations for a specified domain from data provided.

=item has_fake_addresses($domain)

Check if there is at least one fake nameserver specified for the given domain.

=item get_fake_addresses($domain, $nsname)

Returns a list of all cached fake addresses for the given domain and name server name.
Returns an empty list if no data is cached for the given arguments.

=item clear_cache()

Class method to empty the cache of responses to recursive queries (but not the ones for fake delegations).

=item root_servers()

Returns a list of ns objects representing the root servers. The list of root servers is found in an external
file.

=back

=cut
