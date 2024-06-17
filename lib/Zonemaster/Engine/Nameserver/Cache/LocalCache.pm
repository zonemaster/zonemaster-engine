package Zonemaster::Engine::Nameserver::Cache::LocalCache;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.0.4");

use Carp qw( confess );
use Scalar::Util qw( blessed );

use Zonemaster::Engine;
use Zonemaster::Engine::Nameserver::Cache;

use base qw( Zonemaster::Engine::Nameserver::Cache );

our $object_cache = \%Zonemaster::Engine::Nameserver::Cache::object_cache;

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $attrs = shift;

    confess "Attribute \(address\) is required"
        if !exists $attrs->{address};

    # Type coercions
    $attrs->{address} = Net::IP::XS->new( $attrs->{address} )
        if !blessed $attrs->{address} || !$attrs->{address}->isa( 'Net::IP::XS' );

    # Type constraint
    confess "Argument must be coercible into a Net::IP::XS: address"
        if !$attrs->{address}->isa( 'Net::IP::XS' );
    confess "Argument must be a HASHREF: data"
        if exists $attrs->{data} && ref $attrs->{data} ne 'HASH';

    # Default value
    $attrs->{data} //= {};

    my $ip = $attrs->{address}->ip;
    if ( exists $object_cache->{ $ip } ) {
        Zonemaster::Engine->logger->add( CACHE_FETCHED => { ip => $ip } );
        return $object_cache->{ $ip };
    }

    my $obj = Class::Accessor::new( $class, $attrs );

    Zonemaster::Engine->logger->add( CACHE_CREATED => { ip => $ip } );
    $object_cache->{ $ip } = $obj;

    return $obj;
}

sub set_key {
     my ( $self, $idx, $packet ) = @_;
     $self->data->{$idx} = $packet;
}

sub get_key {
    my ( $self, $idx ) = @_;

    if ( exists $self->data->{$idx} ) {
        # cache hit
        return ( 1, $self->data->{$idx} );
    }
    return ( 0, undef );
}

1;

=head1 NAME

Zonemaster::Engine::Nameserver::LocalCache - local shared caches for nameserver objects

=head1 SYNOPSIS

    This class should not be used directly.

=head1 ATTRIBUTES

Subclass of L<Zonemaster::Engine::Nameserver::Cache>.

=head1 CLASS METHODS

=over

=item new

Construct a new Cache object.

=item set_key($idx, $packet)

Store C<$packet> (data) with key C<$idx>.

=item get_key($idx)

Retrieve C<$packet> (data) at key C<$idx>.

=back

=cut
