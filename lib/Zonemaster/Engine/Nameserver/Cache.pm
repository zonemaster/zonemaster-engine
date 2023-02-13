package Zonemaster::Engine::Nameserver::Cache;

use version; our $VERSION = version->declare("v1.0.4");

use 5.014002;
use warnings;

use Class::Accessor "antlers";

our %object_cache;

has 'data' => ( is => 'ro' );
has 'address' => ( is => 'ro' );

sub check_cache {
    my ( $self, $cache ) = @_;

    if ( $cache !~ /^LocalCache$/ ) {
        warn "Unknown cache format '$cache', using default 'LocalCache'";
    }
    return "LocalCache";
}

sub get_cache_type {
    my ( $class, $profile ) = @_;
    return 'LocalCache';
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

=item check_cache($cache)

Returns a normalized string based on the supported cache format.
Emits a warning and retun "LocalCache" if the value is not LocalCache.

=item get_cache_type()

Get the cache type value, i.e. the name of the cache module to use.

=item get_cache_class()

Get the cache adapter class for the given database type.

Throws and exception if the cache adapter class cannot be loaded.

=item empty_cache()

Clear the cache.

=back

=cut
