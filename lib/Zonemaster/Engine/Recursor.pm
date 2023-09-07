package Zonemaster::Engine::Recursor;
use strict;
use warnings;
use 5.014002;

use version; our $VERSION = version->declare("v1.1.0");

use Carp;
use Class::Accessor "antlers";
use File::ShareDir qw[dist_file];
use File::Slurp qw( read_file );
use JSON::PP;
use Net::IP::XS;

use Zonemaster::Engine;
use Zonemaster::Engine::DNSName;
use Zonemaster::Engine::Util qw( name ns parse_hints );

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
    my ( $class, $name, $type, $dns_class ) = @_;
    $name = name( $name );
    $type      //= 'A';
    $dns_class //= 'IN';

    Zonemaster::Engine->logger->add( RECURSE => { name => $name, type => $type, class => $dns_class } );
    if ( exists $recurse_cache{$name}{$type}{$dns_class} ) {
        return $recurse_cache{$name}{$type}{$dns_class};
    }

    my ( $p, $state ) =
      $class->_recurse( $name, $type, $dns_class,
        { ns => [ root_servers() ], count => 0, common => 0, seen => {}, cseen => {}, glue => {} } );
    $recurse_cache{$name}{$type}{$dns_class} = $p;

    return $p;
}

sub parent {
    my ( $class, $name ) = @_;
    $name = name( $name );

    my ( $p, $state ) =
      $class->_recurse( $name, 'SOA', 'IN',
        { ns => [ root_servers() ], count => 0, common => 0, seen => {}, cseen => {}, glue => {} } );

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

        if ( $class->_is_answer( $p ) ) {    # Return answer, or follow CNAME
            if ( not $p->has_rrs_of_type_for_name( $type, $name ) and $p->has_rrs_of_type_for_name( 'CNAME', $name ) ) {
                if ( scalar $p->get_records_for_name( 'CNAME', $name, 'answer') > 1 ) { # Multiple CNAME records with QNAME as owner name
                    Zonemaster::Engine->logger->add( CNAME_MULTIPLE_FOR_NAME => { name => $name } );
                    return ( undef, $state );
                }
                else {
                    my ( %cnames, %tseen );

                    for my $rr ( $p->get_records( 'CNAME', 'answer' ) ) {
                        my $rr_owner = name( $rr->owner );
                        my $rr_target = name( $rr->cname );

                        if ( scalar $p->get_records_for_name( 'CNAME', $rr_owner, 'answer' ) > 1 ) { # Multiple CNAME records with same owner name
                            Zonemaster::Engine->logger->add( CNAME_MULTIPLE_FOR_NAME => { name => $rr_owner->string } );
                            return ( undef, $state );
                        }

                        if ( lc( $rr_owner ) eq lc( $rr_target ) or exists $tseen{lc( $rr_target )} ) { # CNAME owner name is target, or target has already been seen in this response
                            Zonemaster::Engine->logger->add( CNAME_LOOP_INNER => { name => $rr_owner->string, target => $rr_target->string } );
                            return ( undef, $state );
                        }

                        $tseen{lc( $rr_target )} = 1;
                        $cnames{$rr_owner} = $rr_target;
                    }

                    my $target = $name;
                    $target = $cnames{$target} while $cnames{$target};

                    if ( $state->{cseen}{lc( $target )}  ) { # CNAME target has already been followed (outer loop)
                        Zonemaster::Engine->logger->add( CNAME_LOOP_OUTER => { name => $name, target => $target, cnames => join( ';', keys %{ $state->{cseen} } ) } );
                        return ( undef, $state );
                    }

                    $state->{cseen}{lc( $target )} = 1;

                    if ( lc( $target ) eq lc( $name ) ) { # CNAME target is QNAME (inner loop)
                        Zonemaster::Engine->logger->add( CNAME_LOOP_INNER => { name => $name, target => $target } );
                        return ( undef, $state );
                    }

                    $state->{count} += 1;
                    return ( undef, $state ) if $state->{count} > 100; # Loop protection

                    if ( $p->has_rrs_of_type_for_name( $type, $target ) ) { # RR for CNAME target is in response
                        return ( $p, $state );
                    }

                    # Otherwise, make a new recursive query for CNAME target
                    ( $p, $state ) = $class->_recurse( $target, $type, $dns_class,
                        { ns => [ root_servers() ], count => $state->{count}, common => 0, seen => {}, cseen => $state->{cseen}, glue => {} });

                    return ( $p, $state );
                }
            }
            else {
                return ( $p, $state );
            }
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
            $state->{ns}     = $class->get_ns_from( $p, $state );    # Follow redirect
            $state->{count} += 1;
            return ( undef, $state ) if $state->{count} > 20;        # Loop protection
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
      { ns => [ root_servers() ], count => 0, common => 0, seen => {}, cseen => {} };

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

=head2 recurse($name, $type, $class)

Does a recursive resolution from the root servers down for the given triplet.

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

Class method to create fake adresses for fake delegations for a specified domain from data provided.

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

=cut
