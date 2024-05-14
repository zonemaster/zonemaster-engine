package Zonemaster::Engine::Nameserver::Cache;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.0.4");

use Class::Accessor "antlers";

our %object_cache;

has 'data' => ( is => 'ro' );
has 'address' => ( is => 'ro' );

sub get_cache_type {
    my ( $class, $profile ) = @_;
    my $cache_type = 'LocalCache';

    if ( $profile->get( 'cache' ) ) {
        my %cache_config = %{ $profile->get( 'cache' ) };

        if ( exists $cache_config{'redis'} ) {
            $cache_type = 'RedisCache';
        }
    }

    return $cache_type;
}

sub get_cache_class {
    my ( $class, $cache_type ) = @_;

    my $cache_class = "Zonemaster::Engine::Nameserver::Cache::$cache_type";

    require ( "$cache_class.pm" =~ s{::}{/}gr );
    $cache_class->import();

    return $cache_class;
}

sub empty_cache {
    %object_cache = ();

    return;
}

1;

=head1 NAME

Zonemaster::Engine::Nameserver::Cache - shared caches for nameserver objects

=head1 SYNOPSIS

    This class should not be used directly.

=head1 ATTRIBUTES

=over

=item address

A L<Net::IP::XS> object holding the nameserver's address.

=item data

A reference to a hash holding the cache of sent queries. Not meant for external use.

=back

=head1 CLASS METHODS

=over

=item get_cache_type()

    my $cache_type = get_cache_type( Zonemaster::Engine::Profile->effective );

Get the cache type value from the profile, i.e. the name of the cache module to use.

Takes a L<Zonemaster::Engine::Profile> object.

Returns a string.

=item get_cache_class()

    my $cache_class = get_cache_class( 'LocalCache' );

Get the cache adapter class for the given database type.

Takes a string (cache database type).

Returns a string, or throws an exception if the cache adapter class cannot be loaded.

=item empty_cache()

Clear the cache.

=back

=cut
