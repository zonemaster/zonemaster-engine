package Zonemaster::Engine::Logger::Global;
use v5.26;
use warnings;

use Exporter qw( import );
use Zonemaster::Engine::Logger;

our @EXPORT_OK = qw(
  global_logger
);

sub global_logger {
    state $logger = Zonemaster::Engine::Logger->new;

    return $logger;
}

=head1 SUBROUTINES

=over

=item global_logger

Returns the global L<Zonemaster::Engine::Logger> object.

    use Zonemaster::Engine::Logger::Global qw( global_logger );

    global_logger()

=back

=cut

1;
