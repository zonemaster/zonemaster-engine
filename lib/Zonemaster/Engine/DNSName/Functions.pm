package Zonemaster::Engine::DNSName::Functions;
use v5.26;
use warnings;

use Exporter qw( import );
use Zonemaster::Engine::DNSName;

our @EXPORT_OK = qw( name );

## no critic (Subroutines::RequireArgUnpacking)
sub name {
    # We do not unpack @_ here for performance reasons.
    # If we did, the calling convention is: my ( $name ) = @_.
    return Zonemaster::Engine::DNSName->new( @_ );
}

1;

=head1 SUBROUTINES

=over

=item name($string_name_or_zone)

Creates and returns a L<Zonemaster::Engine::DNSName> object for the given argument.

=back

=cut
