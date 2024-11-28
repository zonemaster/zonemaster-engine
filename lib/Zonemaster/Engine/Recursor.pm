package Zonemaster::Engine::Recursor;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.1.0");

use Carp;
use Class::Accessor "antlers";
use File::ShareDir qw[dist_file];
use File::Slurp qw( read_file );
use JSON::PP;
use Net::IP::XS;
use List::MoreUtils qw[uniq];

use Zonemaster::Engine;
use Zonemaster::Engine::DNSName;
use Zonemaster::Engine::Util qw( name ns parse_hints );
use Zonemaster::Engine::Constants ":cname";

our %recurse_cache;
our %_fake_addresses_cache;

sub init_recursor {
    my $hints_path = dist_file( 'Zonemaster-Engine', 'named.root' );
    my $hints_text = read_file( $hints_path );
    my $hints_data = parse_hints( $hints_text );
    Zonemaster::Engine::Recursor->add_fake_addresses( '.', $hints_data );
}

sub add_fake_addresses {
    my ( $class, $domain, $href ) = @_;
    $domain = lc $domain;

    foreach my $name ( keys %{$href} ) {
        my @ips = uniq @{ $href->{$name} };
        $name = lc $name;

        push @{ $_fake_addresses_cache{$domain}{$name} }, ();
        foreach my $ip ( @ips ) {
            push @{ $_fake_addresses_cache{$domain}{$name} }, $ip;
        }
    }

    return;
}

sub has_fake_addresses {
    my ( $class, $domain ) = @_;
    $domain = lc $domain;

    return !!$_fake_addresses_cache{$domain};
}

sub get_fake_addresses {
    my ( $class, $domain, $nsname ) = @_;
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

sub get_fake_names {
    my ( $class, $domain ) = @_;
    $domain = lc $domain;

    if ( exists $_fake_addresses_cache{$domain} ) {
        return keys %{$_fake_addresses_cache{$domain}};
    }
    else {
        return ();
    }
}

sub remove_fake_addresses {
    my ( $class, $domain ) = @_;
    $domain = lc $domain;

    delete $_fake_addresses_cache{$domain};

    return;
}

sub recurse {
    my ( $class, $name, $type, $dns_class, $ns ) = @_;
    $name = name( $name );
    $type      //= 'A';
    $dns_class //= 'IN';

    Zonemaster::Engine->logger->add( RECURSE => { name => $name, type => $type, class => $dns_class } );
    if ( exists $recurse_cache{$name}{$type}{$dns_class} ) {
        return $recurse_cache{$name}{$type}{$dns_class};
    }

    my %state = ( ns => [ root_servers() ], count => 0, common => 0, seen => {}, glue => {} );
    if ( defined $ns ) {
        ref( $ns ) eq 'ARRAY' or croak 'Argument $ns must be an arrayref';
        $state{ns} = $ns;
    }

    my ( $p, $state ) = $class->_recurse( $name, $type, $dns_class, \%state );
    $recurse_cache{$name}{$type}{$dns_class} = $p;

    return $p;
}

sub parent {
    my ( $class, $name ) = @_;
    $name = name( $name );

    my ( $p, $state ) =
      $class->_recurse( $name, 'SOA', 'IN',
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

sub _resolve_cname {
    my ( $class, $name, $type, $dns_class, $p, $state ) = @_;
    $name = name( $name );
    Zonemaster::Engine->logger->add( CNAME_START => { name => $name, type => $type, dns_class => $dns_class } );

    my @cname_rrs = $p->get_records( 'CNAME', 'answer' );

    # Remove duplicate CNAME RRs
    my ( %duplicate_cname_rrs, @unique_rrs );
    for my $rr ( @cname_rrs ) {
        my $rr_hash = $rr->class . '/CNAME/' . lc($rr->owner) . '/' . lc($rr->cname);

        if ( exists $duplicate_cname_rrs{$rr_hash} ) {
            $duplicate_cname_rrs{$rr_hash}++;
        }
        else {
            $duplicate_cname_rrs{$rr_hash} = 0;
            push @unique_rrs, $rr;
        }
    }

    unless ( scalar @unique_rrs == scalar @cname_rrs ) {
        Zonemaster::Engine->logger->add( CNAME_RECORDS_DUPLICATES => {
                records => join(';', map { "$_ => $duplicate_cname_rrs{$_}" if $duplicate_cname_rrs{$_} > 0 } keys %duplicate_cname_rrs )
            }
        );
        @cname_rrs = @unique_rrs;
    }

    # Break if there are too many records
    if ( scalar @cname_rrs > $CNAME_MAX_RECORDS ) {
        Zonemaster::Engine->logger->add( CNAME_RECORDS_TOO_MANY => { name => $name, count => scalar @cname_rrs, max => $CNAME_MAX_RECORDS } );
        return ( undef, $state );
    }

    my ( %cnames, %seen_targets, %forbidden_targets );
    for my $rr ( @cname_rrs ) {
        my $rr_owner = name( $rr->owner );
        my $rr_target = name( $rr->cname );

        # Multiple CNAME records with same owner name
        if ( exists $forbidden_targets{lc( $rr_owner )} ) {
            Zonemaster::Engine->logger->add( CNAME_RECORDS_MULTIPLE_FOR_NAME => { name => $rr_owner } );
            return ( undef, $state );
        }

        # CNAME owner name is target, or target has already been seen in this response, or owner name cannot be a target
        if ( lc( $rr_owner ) eq lc( $rr_target ) or exists $seen_targets{lc( $rr_target )} or exists $forbidden_targets{lc( $rr_target )} ) {
            Zonemaster::Engine->logger->add( CNAME_LOOP_INNER => { name => join( ';', map { $_->owner } @cname_rrs ), target => join( ';', map { $_->cname } @cname_rrs ) } );
            return ( undef, $state );
        }

        $seen_targets{lc( $rr_target )} = 1;
        $forbidden_targets{lc( $rr_owner )} = 1;
        $cnames{$rr_owner} = $rr_target;
    }

    # Get final CNAME target
    my $target = $name;
    my $cname_counter = 0;
    while ( $cnames{$target} ) {
        return ( undef, $state ) if $cname_counter > $CNAME_MAX_RECORDS; # Loop protection (for good measure only - data in %cnames is sanitized already)
        $target = $cnames{$target};
        $cname_counter++;
    }

    # Make sure that the CNAME chain from the RRs is not broken
    if ( $cname_counter != scalar @cname_rrs ) {
        Zonemaster::Engine->logger->add( CNAME_RECORDS_CHAIN_BROKEN => { name => $name, cname_rrs => scalar @cname_rrs, cname_counter => $cname_counter } );
        return ( undef, $state );
    }

    # Check if there are RRs of queried type (QTYPE) in the answer section of the response;
    if ( scalar $p->get_records( $type, 'answer' ) ) {
        # RR of type QTYPE for CNAME target is already in the response; no need to recurse
        if ( $p->has_rrs_of_type_for_name( $type, $target ) ) {
            Zonemaster::Engine->logger->add( CNAME_FOLLOWED_IN_ZONE => { name => $name, type => $type, target => $target } );
            return ( $p, $state );
        }

        # There is a record of type QTYPE but with different owner name than CNAME target; no need to recurse
        Zonemaster::Engine->logger->add( CNAME_NO_MATCH => { name => $name, type => $type, target => $target, owner_names => join( ';', map { $_->owner } $p->get_records( $type ) ) } );
        return ( undef, $state );
    }

    # CNAME target has already been followed (outer loop); no need to recurse
    if ( $state->{tseen}{lc( $target )}  ) {
        Zonemaster::Engine->logger->add( CNAME_LOOP_OUTER => { name => $name, target => $target, targets_seen => join( ';', keys %{ $state->{tseen} } ) } );
        return ( undef, $state );
    }

    # Safe-guard against anormaly long consecutive CNAME chains; no need to recurse
    $state->{tseen}{lc( $target )} = 1;
    $state->{tcount} += 1;

    if ( $state->{tcount} > $CNAME_MAX_CHAIN_LENGTH ) {
        Zonemaster::Engine->logger->add( CNAME_CHAIN_TOO_LONG => { count => $state->{tcount}, max => $CNAME_MAX_CHAIN_LENGTH } );
        return ( undef, $state );
    }

    # Make sure that the CNAME target is out of zone before making a new recursive lookup for CNAME target
    unless ( $name->is_in_bailiwick( $target ) ) {
        Zonemaster::Engine->logger->add( CNAME_FOLLOWED_OUT_OF_ZONE => { name => $name, target => $target } );
        ( $p, $state ) = $class->_recurse( $target, $type, $dns_class,
            { ns => [ root_servers() ], count => 0, common => 0, seen => {}, tseen => $state->{tseen}, tcount => $state->{tcount}, glue => {} });
    }
    else {
        # What do do here?
    }

    return ( $p, $state );
}

sub _recurse {
    my ( $class, $name, $type, $dns_class, $state ) = @_;
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
                class   => $dns_class,
            }
        );
        my $p = $class->_do_query( $ns, $name, $type, { class => $dns_class }, $state );

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

        if ( $class->_is_answer( $p ) ) {    # Return answer, or resolve CNAME
            if ( not $p->has_rrs_of_type_for_name( $type, $name ) and scalar $p->get_records_for_name( 'CNAME', $name, 'answer' ) ) {
                ( $p, $state ) = $class->_resolve_cname( $name, $type, $dns_class, $p, $state );
            }

            return ( $p, $state );
        }

        # So it's not an error, not an empty response and not an answer

        if ( $p->is_redirect ) {
            my $zname = name( lc( ( $p->get_records( 'ns' ) )[0]->name ) );

            next if $zname eq '.';          # Redirect to root is never right.

            next if $state->{seen}{$zname}; # We followed this redirect before

            $state->{seen}{$zname} = 1;
            my $common = name( $zname )->common( name( $state->{qname} ) );

            next if $common < $state->{common};    # Redirect going up the hierarchy is not OK

            $state->{common} = $common;
            $state->{ns}     = $class->get_ns_from( $p, $state );    # Follow redirect
            $state->{count} += 1;
            if ( $state->{count} > 20 ) {       # Loop protection
                Zonemaster::Engine->logger->add( LOOP_PROTECTION => {
                    caller => 'Zonemaster::Engine::Recursor->_recurse',
                    child_zone_name => $name,
                    name => $zname
                  }
                );

                return ( undef, $state );
            }
            unshift @{ $state->{trace} }, [ $zname, $ns, $p->answerfrom ];

            next;
        } ## end if ( $p->is_redirect )
    } ## end while ( my $ns = pop @{ $state...})
    return ( $state->{candidate}, $state ) if $state->{candidate};

    return ( undef, $state );
} ## end sub _recurse

sub _do_query {
    my ( $class, $ns, $name, $type, $opts, $state ) = @_;

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
            my $p      = $class->_do_query( $realns, $name, $type, $opts, $state );
            if ( $p ) {
                return $p;
            }
        }
        return;
    }
    else {
        $state->{glue}{ lc( name( $ns ) ) } = {};
        my @addr = $class->get_addresses_for( $ns, $state );
        if ( @addr > 0 ) {
            foreach my $addr ( @addr ) {
                $state->{glue}{ lc( name( $ns ) ) }{ $addr->short } = 1;
                my $new = ns( $ns, $addr->short );
                my $p = $new->query( $name, $type, $opts );
                return $p if $p;
            }
            return;
        }
        else {
            return;
        }
    }
} ## end sub _do_query

sub get_ns_from {
    my ( $class, $p, $state ) = @_;
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
    my ( $class, $name, $state ) = @_;
    my @res;
    $state //=
      { ns => [ root_servers() ], count => 0, common => 0, seen => {} };

    my ( $pa ) = $class->_recurse(
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

    my ( $paaaa ) = $class->_recurse(
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
            push @res, Net::IP::XS->new( $rr->address );
        }
    }
    return @res;
} ## end sub get_addresses_for

sub _is_answer {
    my ( $class, $packet ) = @_;

    return ( $packet->type eq 'answer' );
}

sub clear_cache {
    %recurse_cache = ();
    return;
}

sub root_servers {
    my $root_addresses = $_fake_addresses_cache{'.'};

    my @servers;
    for my $name ( sort keys %{ $root_addresses } ) {
        for my $address ( @{ $root_addresses->{$name} } ) {
            push @servers, ns( $name, $address );
        }
    }

    return @servers;
}

1;

=head1 NAME

Zonemaster::Engine::Recursor - recursive resolver for Zonemaster

=head1 SYNOPSIS

    my $packet = Zonemaster::Engine::Recursor->recurse( $name, $type, $dns_class );
    my $pname  = Zonemaster::Engine::Recursor->parent( 'example.org' );

=head1 CLASS VARIABLES

=head2 %recurse_cache

Will cache result of previous queries.

=head2 %_fake_addresses_cache

A hash of hashrefs of arrayrefs.
The keys of the top level hash are domain names.
The keys of the second level hashes are name server names (normalized to lower
case).
The elements of the third level arrayrefs are IP addresses.

The IP addresses are those of the nameservers which are used in case of fake
delegations (pre-publication tests).

=head1 CLASS METHODS

=head2 init_recursor()

Initialize the recursor by loading the root hints.

=head2 recurse($name[, $type, $class, $ns])

Does a recursive resolution for the given name down from the root servers (or for the given name server(s), if any).
Only the first argument is mandatory. The rest are optional and default to, respectively: 'A', 'IN', and L</root_servers()>.

Takes a string or a L<Zonemaster::Engine::DNSName> object (name); and optionally a string (query type), a string (query class),
and an arrayref of L<Zonemaster::Engine::Nameserver> objects.

Returns a L<Zonemaster::Engine::Packet> object (which can be C<undef>).

=head2 parent($name)

Does a recursive resolution from the root down for the given name (using type C<SOA> and class C<IN>). If the resolution is successful, it returns
the domain name of the second-to-last step. If the resolution is unsuccessful, it returns the domain name of the last step.

=head2 get_ns_from($packet, $state)

Internal method. Takes a packet and a recursion state and returns a list of ns objects. Used to follow redirections.

=head2 get_addresses_for($name[, $state])

Takes a name and returns a (possibly empty) list of IP addresses for
that name (in the form of L<Net::IP::XS> objects). When used
internally by the recursor it's passed a recursion state as its second
argument.

=head2 add_fake_addresses($domain, $data)

Class method to create fake addresses for fake delegations for a specified domain from data provided.

=head2 has_fake_addresses($domain)

Check if there is at least one fake nameserver specified for the given domain.

=head2 get_fake_addresses($domain, $nsname)

Returns a list of all cached fake addresses for the given domain and name server name.
Returns an empty list if no data is cached for the given arguments.

=head2 get_fake_names($domain)

Returns a list of all cached fake name server names for the given domain.
Returns an empty list if no data is cached for the given argument.

=head2 remove_fake_addresses($domain)

Remove fake delegation data for a specified domain.

=head2 clear_cache()

Class method to empty the cache of responses to recursive queries (but not the ones for fake delegations).

N.B. This method does not affect fake delegation data.

=head2 root_servers()

Returns a list of ns objects representing the root servers.

    my @name_servers = Zonemaster::Engine::Recursor->root_servers();

The default list of root servers is read from a file installed in the shared data directory.
This list can be replaced like so:

    Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
    Zonemaster::Engine::Recursor->add_fake_addresses(
        '.',
        {
            'ns1.example' => ['192.0.2.1'],
            'ns2.example' => ['192.0.2.2'],
        }
    );

=head1 INTERNAL METHODS

=head2 _recurse()

    my ( $p, $state_hash ) = _recurse( $name, $type_string, $dns_class_string, $p, $state_hash );

Performs a recursive lookup resolution for the given arguments. Used by the L<recursive lookup|/recurse($name, $type, $class)> method in this module.

Takes a L<Zonemaster::Engine::DNSName> object, a string (query type), a string (DNS class), a L<Zonemaster::Engine::Packet> object, and a reference to a hash.
The mandatory keys for that hash are 'ns' (arrayref), 'count' (integer), 'common' (integer), 'seen' (hash), 'glue' (hash) and optional keys are 'in_progress'
(hash), 'candidate' (L<Zonemaster::Engine::Packet> object or C<undef>), 'trace' (array), 'tseen' (hash), 'tcount' (integer).

Returns a L<Zonemaster::Engine::Packet> (or C<undef>) and a hash.

=head2 _resolve_cname()

    my ( $p, $state_hash ) = _resolve_cname( $name, $type_string, $dns_class_string, $p, $state_hash );

Performs CNAME resolution for the given arguments. Used by the L<recursive lookup|/_recurse()> helper method in this module.
If CNAMEs are successfully resolved, a L<packet|Zonemaster::Engine::Packet> (which could be C<undef>) is returned and
one of the following message tags is logged:

=over

=item CNAME_FOLLOWED_IN_ZONE

=item CNAME_FOLLOWED_OUT_OF_ZONE

=back

Note that CNAME records are also validated and, in case of an error, an empty (C<undef>) L<packet|Zonemaster::Engine::Packet>
is returned and one of the following message tags will be logged:

=over

=item CNAME_CHAIN_TOO_LONG

=item CNAME_LOOP_INNER

=item CNAME_LOOP_OUTER

=item CNAME_NO_MATCH

=item CNAME_RECORDS_CHAIN_BROKEN

=item CNAME_RECORDS_MULTIPLE_FOR_NAME

=item CNAME_RECORDS_TOO_MANY

=back

Takes a L<Zonemaster::Engine::DNSName> object, a string (query type), a string (DNS class), a L<Zonemaster::Engine::Packet>, and a reference to a hash.

Returns a L<Zonemaster::Engine::Packet> (or C<undef>) and a reference to a hash.

=cut
