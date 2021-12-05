package Zonemaster::Engine::DNSName;

use version; our $VERSION = version->declare("v1.0.3");

use 5.014002;
use warnings;
use Carp;
use Scalar::Util qw( blessed );

use Class::Accessor "antlers";

use overload
  '""'  => \&string,
  'cmp' => \&str_cmp;

has 'labels' => ( is => 'ro' );

sub from_string {
    my ( $class, $domain ) = @_;

    confess 'Argument must be a string: $domain'
      if !defined $domain || ref $domain ne '';

    return $class->_new( { labels => [ split( /[.]/x, $domain ) ] } );
}

sub new {
    my $proto = shift;
    confess "must be called with a single argument"
      if scalar( @_ ) != 1;
    my $input = shift;

    my $attrs = {};
    if ( !defined $input ) {
        $attrs->{labels} = [];
    }
    elsif ( blessed $input && $input->isa( 'Zonemaster::Engine::DNSName' ) ) {
        $attrs->{labels} = \@{ $input->labels };
    }
    elsif ( blessed $input && $input->isa( 'Zonemaster::Engine::Zone' ) ) {
        $attrs->{labels} = [ split( /[.]/x, $input->name ) ];
    }
    elsif ( ref $input eq '' ) {
        $attrs->{labels} = [ split( /[.]/x, $input ) ];
    }
    elsif ( ref $input eq 'HASH' ) {
        confess "Attribute \(labels\) is required"
          if !exists $input->{labels};

        confess "Argument must be an ARRAYREF: labels"
          if exists $input->{labels}
          && ref $input->{labels} ne 'ARRAY';

        $attrs->{labels} = $input->{labels};
    }
    else {
        my $what =
          ( blessed $input )
          ? "blessed(" . blessed $input . ")"
          : "ref(" . ref $input . ")";
        confess "Unrecognized argument: " . $what;
    }

    # Type constraints
    confess "Argument must be an ARRAYREF: labels"
      if exists $attrs->{labels}
      && ref $attrs->{labels} ne 'ARRAY';

    my $class = ref $proto || $proto;
    return $class->_new( $attrs );
}

sub _new {
    my $class = shift;
    my $attrs = shift;

    my $obj = Class::Accessor::new( $class, $attrs );

    return $obj;
}

sub string {
    my $self = shift;

    my $name = join( '.', @{ $self->labels } );
    $name = '.' if $name eq q{};

    return $name;
}

sub fqdn {
    my ( $self ) = @_;

    return join( '.', @{ $self->labels } ) . '.';
}

sub str_cmp {
    my ( $self, $other ) = @_;
    $other //= q{};    # Treat undefined value as root

    $other =~ s/(.+)[.]\z/$1/x;

    return ( uc( "$self" ) cmp uc( $other ) );
}

sub next_higher {
    my $self = shift;
    my @l    = @{ $self->labels };
    if ( @l ) {
        shift @l;
        return Zonemaster::Engine::DNSName->new({ labels => \@l });
    }
    else {
        return;
    }
}

sub common {
    my ( $self, $other ) = @_;

    my @me   = reverse @{ $self->labels };
    my @them = reverse @{ $other->labels };

    my $count = 0;
    while ( @me and @them ) {
        my $m = shift @me;
        my $t = shift @them;
        if ( uc( $m ) eq uc( $t ) ) {
            $count += 1;
            next;
        }
        else {
            last;
        }
    }

    return $count;
} ## end sub common

sub is_in_bailiwick {
    my ( $self, $other ) = @_;

    return scalar( @{ $self->labels } ) == $self->common( $other );
}

sub prepend {
    my ( $self, $label ) = @_;
    my @labels = ( $label, @{ $self->labels } );

    return $self->new( { labels => \@labels } );
}

sub TO_JSON {
    my ( $self ) = @_;

    return $self->string;
}

1;

=head1 NAME

Zonemaster::Engine::DNSName - class representing DNS names

=head1 SYNOPSIS

    my $name1 = Zonemaster::Name->new('www.example.org');
    my $name2 = Zonemaster::Name->new('ns.example.org');
    say "Yay!" if $name1->common($name2) == 2;

=head1 ATTRIBUTES

=over

=item labels

A reference to a list of strings, being the labels the DNS name is made up from.

=back

=head1 METHODS

=over

=item new($input) _or_ new({ labels => \@labellist})

The constructor can be called with either a single argument or with a reference
to a hash as in the example above.

If there is a single argument, it must be either a non-reference, a
L<Zonemaster::Engine::DNSName> object or a L<Zonemaster::Engine::Zone> object.

If it's a non-reference, it will be split at period characters (possibly after
stringification) and the resulting list used as the name's labels.

If it's a L<Zonemaster::Engine::DNSName> object it will simply be returned.

If it's a L<Zonemaster::Engine::Zone> object, the value of its C<name> attribute will
be returned.

=item from_string($domain)

A specialized constructor that must be called with a string.

=item string()

Returns a string representation of the name. The string representation is created by joining the labels with dots. If there are no labels, a
single dot is returned. The names created this way do not have a trailing dot.

The stringification operator is overloaded to this function, so it should rarely be necessary to call it directly.

=item fqdn()

Returns the name as a string complete with a trailing dot.

=item str_cmp($other)

Overloads string comparison. Comparison is made after converting the names to upper case, and ignores any trailing dot on the other name.

=item next_higher()

Returns a new L<Zonemaster::Engine::DNSName> object, representing the name of the called one with the leftmost label removed.

=item common($other)

Returns the number of labels from the rightmost going left that are the same in both names. Used by the recursor to check for redirections going
up the DNS tree.

=item is_in_bailiwick($other)

Returns true if $other is in-bailiwick of $self, and false otherwise.
See also L<https://tools.ietf.org/html/rfc7719#section-6>.

=item prepend($label)

Returns a new L<Zonemaster::Engine::DNSName> object, representing the called one with the given label prepended.

=item TO_JSON

Helper method for JSON encoding.

=back

=cut
