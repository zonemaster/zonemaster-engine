package Zonemaster::Engine::Recursor::Global;
use v5.26;
use warnings;

use Exporter qw( import );
use Zonemaster::Engine::Recursor;

our @EXPORT_OK = qw(
  global_recursor
);

sub global_recursor {
    state $recursor = Zonemaster::Engine::Recursor->new;

    return $recursor;
}

=head1 SUBROUTINES

=head2 global_recursor

Returns the global L<Zonemaster::Engine::Recursor> object.

    use Zonemaster::Engine::Recursor::Global qw( global_recursor );

    my $recursor = global_recursor()

=cut

1;
