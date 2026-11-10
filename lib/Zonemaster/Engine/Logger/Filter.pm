package Zonemaster::Engine::Logger::Filter;
use v5.26;
use warnings;

use Exporter        qw( import );
use List::MoreUtils qw( any none );
use Zonemaster::Engine::Logger::Entry;
use Zonemaster::Engine::Profile;

our @EXPORT_OK = qw(
  check_filter
  reset_config
);

my $logfilter;

=head1 SUBROUTINES

=over

=item check_filter

Apply the C<logfilter> defined rules to the entry.

    check_filter( $entry );

See L<Zonemaster::Engine::Profile/"logfilter">.

=cut

sub check_filter {
    my ( $entry ) = @_;

    if ( !defined $logfilter ) {
        $logfilter = Zonemaster::Engine::Profile->effective->get( q{logfilter} );
    }

    if ( $logfilter ) {
        if ( $logfilter->{ uc $entry->module } ) {
            my $match = 0;
            foreach my $rule ( @{ $logfilter->{ uc $entry->module }{ $entry->tag } } ) {
                foreach my $key ( keys %{ $rule->{when} } ) {
                    my $cond = $rule->{when}{$key};
                    if ( ref( $cond ) and ref( $cond ) eq 'ARRAY' ) {
                        if ( any { $_ eq $entry->args->{$key} } @$cond ) {
                            $match = 1;
                        }
                        else {
                            $match = 0;
                            last;
                        }
                    }
                    else {
                        if ( $cond eq $entry->args->{$key} ) {
                            $match = 1;
                        }
                        else {
                            $match = 0;
                            last;
                        }
                    }
                } ## end foreach my $key ( keys %{ $rule...})
                if ( $match ) {
                    $entry->_set_level( $rule->{set} );
                    last;
                }
            } ## end foreach my $rule ( @{ $logfilter...})
        } ## end if ( $logfilter->{ uc ...})
    } ## end if ( $logfilter )
    return;
} ## end sub check_filter

=item reset_config()

Clear the test level cached configuration, and ensure that the
L<logfilter|Zonemaster::Engine::Profile/logfilter> is reloaded from the
L<Zonemaster::Engine::Profile/effective> profile on next call to L</check_filter>.

    use Zonemaster::Engine::Logger::Filter qw( reset_config );

    reset_config();

=back

=cut

sub reset_config {
    $logfilter = undef;
    Zonemaster::Engine::Logger::Entry->reset_config();
    return;
}

1;
