package Zonemaster::Engine::Logger::Time;
use v5.26;
use warnings;

use Exporter    qw( import );
use Time::HiRes qw( time );

our @EXPORT_OK = qw(
  get_logger_time
  reset_logger_time
);

our $start_time = time();

sub reset_logger_time {
    $start_time = time();

    return;
}

sub get_logger_time {
    return time() - $start_time;
}

=head1 SUBROUTINES

=over 4

=item reset_logger_time

Set the logger start time to the current time.

    reset_logger_time()

The logger start time is common to all L<Zonemaster::Engine::Logger> objects.

=item get_logger_time

Get the duration in seconds since the logger start time.

    get_logger_time()

=back

=cut

1;
