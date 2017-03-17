package Zonemaster::Net::IP;

use version; our $VERSION = version->declare("v0.0.5");

no strict 'refs';
use warnings;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

require Exporter;

@ISA = qw(Exporter);

my $p_class;

eval {
# Still does not work that way...
#    require Net::IP::XS;
#    use Net::IP::XS qw(:PROC);
#    $p_class = q{Net::IP::XS};
    0;
  } or do {
    require Net::IP;
    use Net::IP qw(:PROC);
    $p_class = q{Net::IP};
  };

if ( $p_class ) {
    push @ISA, ( $p_class );
    push @EXPORT_OK, @{ $p_class . '::EXPORT_OK' };
    %EXPORT_TAGS = (PROC => [@EXPORT_OK],);
} else {
    die "Both Net::IP and Net::IP::XS missing ?\n";
}

sub new {
    my ($class) = shift @_;
    my $self = {};
    $self = $class->SUPER::new( @_ );
    bless($self, $class);
    return $self;
}

1;

=head1 NAME

Zonemaster::Net::IP - Net::IP/Net::IP::XS Wrapper (STILL EXPERIMENTAL)

=head1 SYNOPSIS

    my $ip = Zonemaster::Net::IP->new( q{0.0.0.0/8} );

=head1 METHODS

=over

=item new

Constructor of object.

=back

=cut
