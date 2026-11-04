package Zonemaster::Engine::Nameserver::Functions;
use v5.26;
use warnings;

use Exporter qw( import );
use Zonemaster::Engine::Nameserver;

our @EXPORT_OK = qw(
  ns
);

sub ns {
    my ( $name, $address ) = @_;

    return Zonemaster::Engine::Nameserver->new( { name => $name, address => $address } );
}

=head1 SUBROUTINES

=over

=item ns($name, $address)

Creates and returns a nameserver object with the given name and address.

=back

=cut

1;
