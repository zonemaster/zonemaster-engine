package Zonemaster::Engine::Nameserver;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.1.16");

use Class::Accessor qw[ antlers ];

use Zonemaster::Engine::DNSName;
use Zonemaster::Engine;
use Zonemaster::Engine::Packet;
use Zonemaster::Engine::Nameserver::Cache;
use Zonemaster::Engine::Recursor;
use Zonemaster::Engine::Constants qw( :ip :misc );
use Zonemaster::LDNS;

use Net::IP::XS;
use Time::HiRes qw[time];
use JSON::PP;
use MIME::Base64;
use Module::Find qw[useall];
use Carp qw( confess croak );
use List::Util qw[max min sum];
use Digest::MD5;
use POSIX ();
use Scalar::Util qw[ blessed ];

our @ISA = qw (Class::Accessor);

use overload
  '""'  => \&string,
  'cmp' => \&compare;

has 'name'    => ( is => 'ro' );
has 'address' => ( is => 'ro' );

has 'dns'   => ( is => 'ro' );
has 'cache' => ( is => 'ro' );
has 'times' => ( is => 'ro' );

has 'fake_delegations' => ( is => 'ro' );
has 'fake_ds'          => ( is => 'ro' );

has 'blacklisted' => ( is => 'rw' );

###
### Variables
###

our %object_cache;
our %address_object_cache;
our %address_repr_cache;

###
### Build methods for attributes
###

sub new {
    my $class = shift;
    my $attrs = shift;

    my %lazy_attrs;
    $lazy_attrs{dns}             = delete $attrs->{dns}             if exists $attrs->{dns};
    $lazy_attrs{cache}           = delete $attrs->{cache}           if exists $attrs->{cache};

    # Required arguments
    confess "Attribute \(address\) is required"
      if !defined $attrs->{address};

    # Type coercions
    $attrs->{name} = Zonemaster::Engine::DNSName->from_string( $attrs->{name} )
      if !blessed $attrs->{name} || !$attrs->{name}->isa( 'Zonemaster::Engine::DNSName' );

    my $name = lc( q{} . $attrs->{name} );
    $name = '$$$NONAME' if $name eq q{};

    my $address;

    # Use a object cache for IP type coercion (don't parse IP unless it is needed)
    if (!blessed $attrs->{address} || !$attrs->{address}->isa( 'Net::IP::XS' )) {
        if (!exists $address_object_cache{$attrs->{address}}) {
            $address_object_cache{$attrs->{address}} = Net::IP::XS->new($attrs->{address});
            $address_repr_cache{$attrs->{address}} = $address_object_cache{$attrs->{address}}->short;
        }
        # Fetch IP object from the address cache (avoid object creation and method call)
        $address = $address_repr_cache{$attrs->{address}};
        $attrs->{address} = $address_object_cache{$attrs->{address}};
    } else {
        $address = $attrs->{address}->short;
    }

    # Return Nameserver object as soon as possible
    if ( exists $object_cache{$name}{$address} ) {
        return $object_cache{$name}{$address};
    }

    # Type constraints
    confess "Argument must be coercible into a Zonemaster::Engine::DNSName: name"
      if !$attrs->{name}->isa( 'Zonemaster::Engine::DNSName' );
    confess "Argument must be coercible into a Net::IP::XS: address"
      if exists $attrs->{address}
      && !$attrs->{address}->isa( 'Net::IP::XS' );
    confess "Argument must be an ARRAYREF: times"
      if exists $attrs->{times}
      && ref $attrs->{times} ne 'ARRAY';
    confess "Argument must be a HASHREF: fake_delegations"
      if exists $attrs->{fake_delegations}
      && ref $attrs->{fake_delegations} ne 'HASH';
    confess "Argument must be a HASHREF: fake_ds"
      if exists $attrs->{fake_ds}
      && ref $attrs->{fake_ds} ne 'HASH';
    confess "Argument must be a HASHREF: blacklisted"
      if exists $attrs->{blacklisted}
      && ref $attrs->{blacklisted} ne 'HASH';
    confess "Argument must be a Zonemaster::LDNS: dns"
      if exists $lazy_attrs{dns}
      && ( !blessed $lazy_attrs{dns} || !$lazy_attrs{dns}->isa( 'Zonemaster::LDNS' ) );
    confess "Argument must be a Zonemaster::Engine::Nameserver::Cache: cache"
      if exists $lazy_attrs{cache}
      && ( !blessed $lazy_attrs{cache} || !$lazy_attrs{cache}->isa( 'Zonemaster::Engine::Nameserver::Cache' ) );

    # Default values
    $attrs->{blacklisted}      //= {};
    $attrs->{fake_delegations} //= {};
    $attrs->{fake_ds}          //= {};
    $attrs->{times}            //= [];

    my $obj = Class::Accessor::new( $class, $attrs );
    $obj->{_dns}             = $lazy_attrs{dns}             if exists $lazy_attrs{dns};
    $obj->{_cache}           = $lazy_attrs{cache}           if exists $lazy_attrs{cache};

    $obj->{_string}          = $name . q{/} . $address;

    Zonemaster::Engine->logger->add( NS_CREATED => { name => $name, ip => $address } );
    $object_cache{$name}{$address} = $obj;

    return $obj;
}

sub dns {
    my $self = shift;

    # Lazy default value
    if ( !exists $self->{_dns} ) {
        $self->{_dns} = $self->_build_dns();
    }

    return $self->{_dns};
}

sub cache {
    my $self = shift;

    # Lazy default value
    if ( !exists $self->{_cache} ) {
        $self->{_cache} = $self->_build_cache();
    }

    return $self->{_cache};
}

sub _build_dns {
    my ( $self ) = @_;

    my $res = Zonemaster::LDNS->new( $self->address->ip );

    $res->recurse( 0 );
    $res->dnssec( 0 );
    $res->edns_size( 0 );

    $res->retry( Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.retry} ) );
    $res->retrans( Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.retrans} ) );
    $res->usevc( Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.usevc} ) );
    $res->igntc( Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.igntc} ) );
    $res->recurse( Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.recurse} ) );
    $res->debug( Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.debug} ) );
    $res->timeout( Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.timeout} ) );

    my $src_address = $self->source_address();
    if ( defined( $src_address ) ) {
        $res->source( $src_address );
    }

    return $res;
}

sub _build_cache {
    my ( $self ) = @_;

    my $cache_type = Zonemaster::Engine::Nameserver::Cache->get_cache_type( Zonemaster::Engine::Profile->effective );
    my $cache_class = Zonemaster::Engine::Nameserver::Cache->get_cache_class( $cache_type );

    $cache_class->new( { address => $self->address } );
}

###
### Public Methods (and helpers)
###

sub query {
    my ( $self, $name, $type, $href ) = @_;
    $type //= 'A';

    my $address = $self->address;
    my $profile = Zonemaster::Engine::Profile->effective;

    if ( $address->version == 4 and not $profile->get( q{net.ipv4} ) ) {
        Zonemaster::Engine->logger->add( IPV4_BLOCKED => { ns => $self->string } );
        return;
    }

    if ( $address->version == 6 and not $profile->get( q{net.ipv6} ) ) {
        Zonemaster::Engine->logger->add( IPV6_BLOCKED => { ns => $self->string } );
        return;
    }

    Zonemaster::Engine->logger->add(
        'QUERY',
        {
            name  => "$name",
            type  => $type,
            flags => $href,
            ip    => $address->short
        }
    );

    my $class     = $href->{class}     // 'IN';
    my $dnssec    = $href->{dnssec}    // 0;
    my $usevc     = $href->{usevc}     // $profile->get( q{resolver.defaults.usevc} );
    my $recurse   = $href->{recurse}   // $profile->get( q{resolver.defaults.recurse} );

    if ( exists $href->{edns_details} and exists $href->{edns_details}{do} ) {
        $dnssec = $href->{edns_details}{do};
    }

    my $edns_size = $href->{edns_size} // ( $dnssec ? $EDNS_UDP_PAYLOAD_DNSSEC_DEFAULT : 0 );

    # Fake a DS answer
    if ( $type eq 'DS' and $class eq 'IN' and $self->fake_ds->{ lc( $name ) } ) {
        my $p = Zonemaster::LDNS::Packet->new( $name, $type, $class );

        $p->qr( 1 );
        $p->aa( 1 );
        $p->do( $dnssec );
        $p->rd( $recurse );

        foreach my $rr ( @{ $self->fake_ds->{ lc( $name ) } } ) {
            $p->unique_push( 'answer', $rr );
        }

        my $res = Zonemaster::Engine::Packet->new( { packet => $p } );
        Zonemaster::Engine->logger->add( FAKE_DS_RETURNED => { name => "$name", type  => $type, class => $class, from => "$self" } );
        Zonemaster::Engine->logger->add( FAKE_PACKET_RETURNED => { packet => $res->string } );
        return $res;
    }

    # Fake a delegation
    foreach my $fname ( sort keys %{ $self->fake_delegations } ) {
        if ( $name =~ m/([.]|\A)\Q$fname\E\z/xi ) {
            my $p = Zonemaster::LDNS::Packet->new( $name, $type, $class );

            if ( lc( $name ) eq lc( $fname ) and $type eq 'NS' ) {
                my $name = $self->fake_delegations->{$fname}{authority};
                my $addr = $self->fake_delegations->{$fname}{additional};
                $p->unique_push( 'answer',     $_ ) for @{$name};
                $p->unique_push( 'additional', $_ ) for @{$addr};
            }
            elsif ( $type eq 'DS' ) {
                $p->aa( 1 );
            }
            else {
                while ( my ( $section, $aref ) = each %{ $self->fake_delegations->{$fname} } ) {
                    $p->unique_push( $section, $_ ) for @{$aref};
                }
            }

            $p->aa( 0 ) unless ( $type eq 'DS' );
            $p->qr( 1 );
            $p->do( $dnssec );
            $p->rd( $recurse );
            $p->answerfrom( $address->ip );

            Zonemaster::Engine->logger->add( FAKE_DELEGATION_RETURNED => { name  => "$name", type  => $type, class => $class, from  => "$self" } );

            my $res = Zonemaster::Engine::Packet->new( { packet => $p } );
            Zonemaster::Engine->logger->add( FAKE_PACKET_RETURNED => { packet => $res->string } );
            return $res;
        } ## end if ( $name =~ m/([.]|\A)\Q$fname\E\z/xi)
    } ## end foreach my $fname ( sort keys...)

    my $md5 = Digest::MD5->new;

    $md5->add( q{NAME}    , $name,
               q{TYPE}    , "\U$type",
               q{CLASS}   , "\U$class",
               q{DNSSEC}  , $dnssec,
               q{USEVC}   , $usevc,
               q{RECURSE} , $recurse );

    if ( exists $href->{edns_details} ) {
        $md5->add( q{EDNS_VERSION}        , $href->{edns_details}{version} // 0,
                   q{EDNS_Z}              , $href->{edns_details}{z} // 0,
                   q{EDNS_EXTENDED_RCODE} , $href->{edns_details}{rcode} // 0,
                   q{EDNS_DATA}           , $href->{edns_details}{data} // q{} );
        $edns_size = $href->{edns_details}{size} // ( $href->{edns_size} // ( $dnssec ? $EDNS_UDP_PAYLOAD_DNSSEC_DEFAULT : $EDNS_UDP_PAYLOAD_DEFAULT ) );
    }

    croak "edns_size (or edns_details->size) parameter must be a value between 0 and 65535" if $edns_size > 65535 or $edns_size < 0;

    $md5->add( q{EDNS_UDP_SIZE} , $edns_size );

    my $idx = $md5->b64digest();

    my ( $in_cache, $p ) = $self->cache->get_key( $idx );
    if ( not $in_cache ) {
        $p = $self->_query( $name, $type, $href );
        $self->cache->set_key( $idx, $p );
    }

    Zonemaster::Engine->logger->add( CACHED_RETURN => { packet => ( $p ? $p->string : 'undef' ) } );

    return $p;
} ## end sub query

sub add_fake_delegation {
    my ( $self, $domain, $href ) = @_;
    my %delegation;

    $domain = q{} . Zonemaster::Engine::DNSName->new( $domain );
    foreach my $name ( keys %{$href} ) {
        push @{ $delegation{authority} }, Zonemaster::LDNS::RR->new( sprintf( '%s IN NS %s', $domain, $name ) );
        foreach my $ip ( @{ $href->{$name} } ) {
            if ( Net::IP::XS->new( $ip )->ip eq $self->address->ip ) {
                Zonemaster::Engine->logger->add( FAKE_DELEGATION_TO_SELF => { ns => "$self", domain => $domain, data => $href } );
                return;
            }

            push @{ $delegation{additional} },
              Zonemaster::LDNS::RR->new( sprintf( '%s IN %s %s', $name, ( Net::IP::XS::ip_is_ipv6( $ip ) ? 'AAAA' : 'A' ), $ip ) );
        }
    }

    $self->fake_delegations->{$domain} = \%delegation;
    Zonemaster::Engine->logger->add( FAKE_DELEGATION_ADDED => { ns => "$self", domain => $domain, data => $href } );

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

    foreach my $href ( @{$aref} ) {
        push @ds,
          Zonemaster::LDNS::RR->new(
            sprintf(
                '%s IN DS %d %d %d %s',
                "$domain", $href->{keytag}, $href->{algorithm}, $href->{type}, $href->{digest}
            )
          );
    }

    $self->fake_ds->{ lc( "$domain" ) } = \@ds;
    Zonemaster::Engine->logger->add( FAKE_DS_ADDED => { domain => lc( "$domain" ), data => $aref, ns => "$self" } );

    # We're changing the world, so the cache can't be trusted
    Zonemaster::Engine::Recursor->clear_cache;

    return;
} ## end sub add_fake_ds

sub _query {
    my ( $self, $name, $type, $href ) = @_;
    my %flags;

    $type //= 'A';
    $href->{class} //= 'IN';

    if ( Zonemaster::Engine::Profile->effective->get( q{no_network} ) ) {
        croak sprintf
          "External query for %s, %s attempted to %s while running with no_network",
          $name, $type, $self->string;
    }

    Zonemaster::Engine->logger->add(
        'external_query',
        {
            name  => "$name",
            type  => $type,
            flags => $href,
            ip    => $self->address->short
        }
    );

    # Make sure we have a value for each flag
    $flags{q{retry}}     = $href->{q{retry}}     // Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.retry} );
    $flags{q{retrans}}   = $href->{q{retrans}}   // Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.retrans} );
    $flags{q{dnssec}}    = $href->{q{dnssec}}    // 0;
    $flags{q{usevc}}     = $href->{q{usevc}}     // Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.usevc} );
    $flags{q{igntc}}     = $href->{q{igntc}}     // Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.igntc} );
    $flags{q{fallback}}  = $href->{q{fallback}}  // Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.fallback} );
    $flags{q{recurse}}   = $href->{q{recurse}}   // Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.recurse} );
    $flags{q{timeout}}   = $href->{q{timeout}}   // Zonemaster::Engine::Profile->effective->get( q{resolver.defaults.timeout} );

    if ( exists $href->{edns_details} ) {
        $flags{q{dnssec}}    = $href->{edns_details}{do} // $flags{q{dnssec}};
        $flags{q{edns_size}} = $href->{edns_details}{size} // ( $href->{q{edns_size}} // ( $flags{q{dnssec}} ? $EDNS_UDP_PAYLOAD_DNSSEC_DEFAULT : $EDNS_UDP_PAYLOAD_DEFAULT ) );
    }
    else {
        $flags{q{edns_size}} = $href->{q{edns_size}} // ( $flags{q{dnssec}} ? $EDNS_UDP_PAYLOAD_DNSSEC_DEFAULT : 0 );
    }

    # Set flags for this query
    foreach my $flag ( keys %flags ) {
        $self->dns->$flag( $flags{$flag} );
    }

    my $before = time();
    my $res;
    if ( $BLACKLISTING_ENABLED and $self->blacklisted->{ $flags{usevc} }{ $flags{dnssec} } ) {
        Zonemaster::Engine->logger->add(
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
        if ( exists $href->{edns_details} ) {
            my $pkt = Zonemaster::LDNS::Packet->new("$name", $type, $href->{class} );
            $pkt->set_edns_present();

            if ( exists $href->{edns_details}{version} ) {
                $pkt->edns_version($href->{edns_details}{version});
            }
    	    if ( exists $href->{edns_details}{z} ) {
                $pkt->edns_z($href->{edns_details}{z});
            }
    	    if ( exists $href->{edns_details}{do} ) {
                $pkt->do($href->{edns_details}{do});
            }
            elsif ( $flags{q{dnssec}} ) {
                $pkt->do($flags{q{dnssec}});
            }
    	    if ( exists $href->{edns_details}{size} ) {
                $pkt->edns_size($href->{edns_details}{size});
            }
    	    if ( exists $href->{edns_details}{rcode} ) {
                $pkt->edns_rcode($href->{edns_details}{rcode});
            }
            if ( exists $href->{edns_details}{data} ) {
                $pkt->edns_data($href->{edns_details}{data});
            }

    	    $res = eval { $self->dns->query_with_pkt( $pkt ) };
        }
        else {
            $res = eval { $self->dns->query( "$name", $type, $href->{class} ) };
        }

        if ( $@ ) {
            my $msg = "$@";
            my $trailing_info = " at ".__FILE__;
            chomp( $msg );
            $msg =~ s/$trailing_info.*/\./;
            Zonemaster::Engine->logger->add( LOOKUP_ERROR =>
                  { message => $msg, ns => "$self", domain => "$name", type => $type, class => $href->{class} } );
            if ( not $href->{q{blacklisting_disabled}} ) {
                $self->blacklisted->{ $flags{usevc} }{ $flags{dnssec} } = 1;
                if ( !$flags{dnssec} ) {
                    $self->blacklisted->{ $flags{usevc} }{ !$flags{dnssec} } = 1;
                }
            }
        }
    }

    push @{ $self->times }, ( time() - $before );

    if ( $res ) {
        my $p = Zonemaster::Engine::Packet->new( { packet => $res } );
        my $size = length( $p->data );
        if ( $size > $EDNS_UDP_PAYLOAD_COMMON_LIMIT ) {
            my $command = sprintf q{dig @%s %s%s %s}, $self->address->short, $flags{dnssec} ? q{+dnssec } : q{},
              "$name", $type;
            Zonemaster::Engine->logger->add(
                PACKET_BIG => { size => $size, command => $command } );
        }
        Zonemaster::Engine->logger->add( EXTERNAL_RESPONSE => { packet => $p->string } );
        return $p;
    }
    else {
        Zonemaster::Engine->logger->add( EMPTY_RETURN => {} );
        return;
    }
} ## end sub _query

sub string {
    return $_[0]->{_string};
}

sub compare {
    my ( $self, $other, $reverse ) = @_;

    return $self->string cmp $other->string;
}

sub save {
    my ( $class, $filename ) = @_;

    my $old = POSIX::setlocale( POSIX::LC_ALL, 'C' );
    my $json = JSON::PP->new->allow_blessed->convert_blessed;
    $json = $json->canonical( 1 );

    open my $fh, '>', $filename or die "Cache save failed: $!";
    foreach my $name ( sort keys %object_cache ) {
        foreach my $addr ( sort keys %{ $object_cache{$name} } ) {
            say $fh "$name $addr " . $json->encode( $object_cache{$name}{$addr}->cache->data );
        }
    }

    close $fh or die $!;

    Zonemaster::Engine->logger->add( SAVED_NS_CACHE => { file => $filename } );

    POSIX::setlocale( POSIX::LC_ALL, $old );
    return;
}

sub restore {
    my ( $class, $filename ) = @_;

    useall 'Zonemaster::LDNS::RR';
    my $decode = JSON::PP->new->filter_json_single_key_object(
        'Zonemaster::LDNS::Packet' => sub {
            my ( $ref ) = @_;
            ## no critic (Modules::RequireExplicitInclusion)
            my $obj = Zonemaster::LDNS::Packet->new_from_wireformat( decode_base64( $ref->{data} ) );
            $obj->answerfrom( $ref->{answerfrom} );
            $obj->timestamp( $ref->{timestamp} );

            return $obj;
        }
      )->filter_json_single_key_object(
        'Zonemaster::Engine::Packet' => sub {
            my ( $ref ) = @_;

            return Zonemaster::Engine::Packet->new( { packet => $ref } );
        }
      );

    my $cache_type = Zonemaster::Engine::Nameserver::Cache->get_cache_type( Zonemaster::Engine::Profile->effective );
    my $cache_class = Zonemaster::Engine::Nameserver::Cache->get_cache_class( $cache_type );

    open my $fh, '<', $filename or die "Failed to open restore data file: $!\n";
    while ( my $line = <$fh> ) {
        my ( $name, $addr, $data ) = split( / /, $line, 3 );
        my $ref = $decode->decode( $data );
        my $ns  = Zonemaster::Engine::Nameserver->new(
            {
                name    => $name,
                address => Net::IP::XS->new($addr),
                cache   => $cache_class->new( { data => $ref, address => Net::IP::XS->new( $addr ) } )
            }
        );
    }
    close $fh;

    Zonemaster::Engine->logger->add( RESTORED_NS_CACHE => { file => $filename } );

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

    if ( Zonemaster::Engine::Profile->effective->get( q{no_network} ) ) {
        croak sprintf
          "External AXFR query for %s attempted to %s while running with no_network",
          $domain, $self->string;
    }

    if ( $self->address->version == 4 and not Zonemaster::Engine::Profile->effective->get( q{net.ipv4} ) ) {
        Zonemaster::Engine->logger->add( IPV4_BLOCKED => { ns => $self->string } );
        return;
    }

    if ( $self->address->version == 6 and not Zonemaster::Engine::Profile->effective->get( q{net.ipv6} ) ) {
        Zonemaster::Engine->logger->add( IPV6_BLOCKED => { ns => $self->string } );
        return;
    }

    return $self->dns->axfr( $domain, $callback, $class );
} ## end sub axfr

sub source_address {
    my ( $self ) = @_;

    my $src_address = Zonemaster::Engine::Profile->effective->get( "resolver.source" . Net::IP::XS::ip_get_version( $self->address->ip ) );

    return $src_address eq '' ? undef : $src_address;
}

sub empty_cache {
    %object_cache = ();
    %address_object_cache = ();
    %address_repr_cache = ();

    Zonemaster::Engine::Nameserver::Cache::empty_cache();

    return;
}

1;

=head1 NAME

Zonemaster::Engine::Nameserver - object representing a DNS nameserver

=head1 SYNOPSIS

    my $ns = Zonemaster::Engine::Nameserver->new({ name => 'ns.nic.se', address => '212.247.7.228' });
    my $p = $ns->query('www.iis.se', 'AAAA');

=head1 DESCRIPTION

This is a very central object in the L<Zonemaster::Engine> framework. All DNS
communications with the outside world pass through here, so we can do
things like synthesizing and recording traffic. All the objects are
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

A L<Net::IP::XS> object holding the nameserver's address.

=item dns

The L<Zonemaster::LDNS> object used to actually send and receive DNS queries.

=item cache

A reference to a L<Zonemaster::Engine::Nameserver::Cache> object holding the cache of sent queries. Not meant for external use.

=item times

A reference to a list with elapsed time values for the queries made through this nameserver.

=back

=head1 CLASS METHODS

=over

=item new

Construct a new object.

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
The available flags are as follows. All but 'class' and 'edns_details' directly correspond to methods in the L<Zonemaster::LDNS> object.

=over

=item class

Defaults to 'IN' if not set.

=item usevc

Send the query via TCP (only).

=item retrans

The retransmission interval.

=item dnssec

Set the DO flag in the query. Defaults to false.

If set to true, it becomes an EDNS query.
Value overridden by C<edns_details{do}> (if also given). More details in L<edns_details> below.

=item debug

Set the debug flag in the resolver, producing output on STDERR as the query process proceeds.

=item recurse

Set the RD flag in the query.

=item timeout

Set the timeout for the outgoing sockets. May or may not be observed by the underlying network stack.

=item retry

Set the number of times the query is tried.

=item igntc

If set to true, incoming response packets with the TC flag set are not automatically retried over TCP.

=item fallback

If set to true, incoming response packets with the TC flag set fall back to EDNS and/or TCP.

=item blacklisting_disabled

If set to true, prevents a server to be black-listed on a query in case there is no answer OR rcode is REFUSED.

=item edns_size

Set the EDNS0 UDP maximum size. The value must be comprised between 0 and 65535.
Defaults to 0, or 512 if the query is a non-DNSSEC EDNS query, or 1232 if the query is a DNSSEC query.

Setting a value other than 0 will also implicitly enable EDNS for the query.
Value overridden by C<edns_details-E<gt>{size}> (if also given). More details in L<edns_details> below.

=item edns_details

A hash. An empty hash or a hash with any keys below will enable EDNS for the query.

The currently supported keys are 'version', 'z', 'do', 'rcode', 'size' and 'data'.
See L<Zonemaster::LDNS::Packet> for more details (key names prefixed with 'edns_').

Note that flag L<edns_size> also exists (see above) and has the same effect as C<edns_details-E<gt>{size}>, although the value of the
latter will take precedence if both are given.

Similarly, note that flag L<dnssec> also exists (see above) and has the same effect as C<edns_details-E<gt>{do}>, although the value of the
latter will take precedence if both are given.

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
same arguments as the similarly named method in L<Zonemaster::Engine>. This is
primarily used for internal information, and using it directly will likely give
confusing results (but may be useful to model certain kinds of
misconfigurations).

=item add_fake_ds($domain, $data)

Adds fake DS information to this nameserver object. Takes the same arguments as
the similarly named method in L<Zonemaster::Engine>.

=item axfr( $domain, $callback, $class )

Does an AXFR for the requested domain from the nameserver. The callback
function will be called once for each received RR, with that RR as its only
argument. To continue getting more RRs, the callback must return a true value.
If it returns a true value, the AXFR will be aborted. See L<Zonemaster::LDNS::axfr>
for more details.

=item source_address()

    my $src_address = source_address();

Returns the configured IPv4 or IPv6 source address to be used by the underlying DNS resolver for sending queries,
or C<undef> if the source address is the empty string.

=item empty_cache()

Clears the caches of Zonemaster::Engine::Nameserver (name server names and IP addresses) and Zonemaster::Engine::Nameserver::Cache (query and response packets) objects.

=back

=cut
