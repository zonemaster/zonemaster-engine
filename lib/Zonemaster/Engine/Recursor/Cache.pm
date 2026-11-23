package Zonemaster::Engine::Recursor::Cache;
use v5.26;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw(
  recursor_cache_clear
  recursor_cache_get
  recursor_cache_has
  recursor_cache_set
);

my %cache;

sub recursor_cache_clear {
    %cache = ();

    return;
}

sub recursor_cache_has {
    my ( $key ) = @_;

    return exists $cache{$key};
}

sub recursor_cache_set {
    my ( $key, $value ) = @_;

    $cache{$key} = $value;

    return;
}

sub recursor_cache_get {
    my ( $key ) = @_;

    return $cache{$key};
}

=head1 SUBROUTINES

=head2 recursor_cache_clear

Empty the cache of responses to recursive queries (but not the ones for fake delegations).

    recursor_cache_clear();

Does not affect fake delegation data.

=head2 recursor_cache_get

Get the cached value associated with the given key.

    my $value = recursor_cache_get( $key );

Returns the value, or C<undef> if no entry exists.

=head2 recursor_cache_has

Check if the cache contains a given key.

    if ( recursor_cache_has( $key ) ) {
        say "entry is present";
    }

Returns a boolean.

=head2 recursor_cache_set

Store a given value at a given key.

    recursor_cache_set( $key, $value );

=cut

1;
