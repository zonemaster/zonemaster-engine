package Zonemaster::Engine::Nameserver::Cache;

use version; our $VERSION = version->declare("v1.0.3");

use 5.014002;
use warnings;

use Moose;
use Zonemaster::Engine;

our %object_cache;

has 'data' => ( is => 'ro', isa => 'HashRef', default => sub { {} } );
has 'address' => ( is => 'ro', isa => 'Zonemaster::Engine::Net::IP', required => 1 );

around 'new' => sub {
    my $orig = shift;
    my $self = shift;

    my $obj = $self->$orig( @_ );

    if ( not exists $object_cache{ $obj->address->ip } ) {
        Zonemaster::Engine->logger->add( CACHE_CREATED => { ip => $obj->address->ip } );
        $object_cache{ $obj->address->ip } = $obj;
    }

    Zonemaster::Engine->logger->add( CACHE_FETCHED => { ip => $obj->address->ip } );
    return $object_cache{ $obj->address->ip };
};

sub empty_cache {
    %object_cache = ();

    return;
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;

=head1 NAME

Zonemaster::Engine::Nameserver::Cache - shared caches for nameserver objects

=head1 SYNOPSIS

    This class should not be used directly.

=head1 ATTRIBUTES

=over

=item address

A L<Zonemaster::Engine::Net::IP> object holding the nameserver's address.

=item data

A reference to a hash holding the cache of sent queries. Not meant for external use.

=back

=head1 CLASS METHODS

=over

=item empty_cache()

Clear the cache.

=back

=cut
