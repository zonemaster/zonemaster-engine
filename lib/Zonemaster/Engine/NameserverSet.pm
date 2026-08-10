package Zonemaster::Engine::NameserverSet;

use v5.26.0;
use warnings;

use Scalar::Util qw(blessed);

use Zonemaster::Engine::DNSName;
use Zonemaster::Engine::Nameserver;

####
#### Constructors
####

sub new {
    my ( $proto, @initial_items ) = @_;
    my $class = ref $proto || $proto;

    my $self = {
        _names => {},
    };

    bless $self, $class;
    $self->push( @initial_items );

    return $self;
}

####
#### Mutators
####

sub push {
    my ( $self, @items ) = @_;

    for my $item ( @items ) {
        next if not defined $item;
        next if $item eq '';

        if ( $item->isa('Zonemaster::Engine::DNSName') ) {
            if ( not exists $self->{_names}{lc $item} ) {
                $self->{_names}{lc $item} = $item;
            }
        }
        elsif ( $item->isa('Zonemaster::Engine::Nameserver') ) {
            my ( $name, $addr ) = ( $item->name, $item->address->short );

            my $r = \$self->{_names}{lc $name};
            if ( not defined $$r or ref $$r ne 'HASH' ) {
                $$r = {};
            }
            $$r->{$addr} = $item;
        }
        else {
            my $name = Zonemaster::Engine::DNSName->new( "$item" );
            if ( not exists $self->{_names}{lc $name} ) {
                $self->{_names}{lc $item} = $name;
            }
        }
    }

    return $self;
}

####
#### Access to items
####

sub get {
    my ( $self, $name ) = @_;

    if ( not exists $self->{_names}{ lc $name } ) {
        return ();
    }

    my $r = $self->{_names}{ lc $name };
    if ( ref $r eq 'HASH' ) {
        return values %$r;
    }

    return $r;
}

sub get_ips {
    my ( $self, $name ) = @_;

    if ( exists $self->{_names}{ lc $name } ) {
        my $r = $self->{_names}{ lc $name };
        if ( ref $r eq 'HASH' ) {
            return values %$r;
        }
    }

    return ();
}

sub items {
    my ( $self ) = @_;

    my @items;

    for my $k ( keys %{ $self->{_names} } ) {
        my $r = $self->{_names}{$k};
        if ( ref $r eq 'HASH' ) {
            CORE::push( @items, map { $r->{$_} } keys %$r );
        }
        else {
            CORE::push( @items, $r );
        }
    }

    return @items;
}

sub names {
    my ( $self ) = @_;

    my @result;

    for my $k ( keys %{ $self->{_names} } ) {
        my $r = $self->{_names}{$k};
        if ( ref $r eq 'HASH' ) {
            CORE::push( @result, ( values %$r )[0]->name() );
        }
        else {
            CORE::push( @result, $r );
        }
    }

    return @result;
}

sub sorted_items {
    my ( $self ) = @_;

    my @items;

    for my $k ( sort keys %{ $self->{_names} } ) {
        my $r = $self->{_names}{$k};
        if ( ref $r eq 'HASH' ) {
            CORE::push( @items, sort map { $r->{$_} } keys %$r );
        }
        else {
            CORE::push( @items, $r );
        }
    }

    return @items;
}

####
#### Basic operations
####

sub is_empty {
    my ( $self ) = @_;

    return ( scalar %{ $self->{_names} } == 0 );
}

####
#### Set theory operations
####

sub difference {
    my ( $self, $other ) = @_;

    my $only_in_left = __PACKAGE__->new();
    my $only_in_right = __PACKAGE__->new();

    my @left_items = $self->sorted_items();
    my @right_items = $other->sorted_items();

    while ( @left_items and @right_items ) {
        my $cmp = $left_items[0] cmp $right_items[0];
        if ( $cmp < 0 ) {
            $only_in_left->push( shift @left_items );
        }
        elsif ( $cmp == 0 ) {
            shift @left_items;
            shift @right_items;
        }
        elsif ( $cmp > 0 ) {
            $only_in_right->push( shift @right_items );
        }
    }
    $only_in_left->push( @left_items );
    $only_in_right->push( @right_items );

    return ( $only_in_left, $only_in_right );
}

sub equals {
    my ( $self, $other ) = @_;

    my @left_items = $self->sorted_items();
    my @right_items = $other->sorted_items();

    while ( @left_items and @right_items ) {
        if ( shift @left_items ne shift @right_items ) {
            return 0;
        }
    }

    return ( scalar @left_items == 0 and scalar @right_items == 0 );
}

1;

=encoding UTF-8

=head1 NAME

Zonemaster::Engine::NameserverSet - a set supporting DNS name/IP pairs and plain DNS names

=head1 SYNOPSIS

    use Zonemaster::Engine::NameserverSet;

    my $set = Zonemaster::Engine::NameserverSet->new();

    my $ns1 = Zonemaster::Engine::Nameserver->new({ name => 'ns.nic.example', address => '2001:db8::8:53' });
    my $ns2 = Zonemaster::Engine::Nameserver->new({ name => 'ns.nic.example', address => '2001:db8::9:53' });
    $set->push( $ns1, $ns2 );

    my $name = Zonemaster::Engine::DNSName->new( 'ns2.nic.example' );
    $set->push( $name );

    $set->get( 'ns.nic.example' );  # returns $ns1 and $ns2 in list context
    $set->get( 'ns2.nic.example' ); # returns $name in list context

    # Retrieve items
    my @items = $set->items; # or $set->sorted_items

=head1 DESCRIPTION

Zonemaster::Engine::NameserverSet implements a collection type that is
specialized for holding a mix of name/IP pairs (represented as
L<Zonemaster::Engine::Nameserver> objects) and bare domain names (represented
as L<Zonemaster::Engine::DNSName> objects).

In other words, it is a collection type that stores mappings of name server
names to zero, one or more IP addresses.

=head1 METHODS

=over

=item new()

Constructs a new empty name server set.

=item push( $name_or_ns )

Adds an item to the set, which can either be a L<Zonemaster::Engine::DNSName>
or a L<Zonemaster::Engine::Nameserver> object.

This method obeys the following rules:

=over

=item *

If C<$name_or_ns> is a L<Zonemaster::Engine::DNSName>, it is added to the set
if and only if the set contains no L<Zonemaster::Engine::DNSName> object with
the same name nor any L<Zonemaster::Engine::Nameserver> objects with the same
name.

=item *

If C<$name_or_ns> is a L<Zonemaster::Engine::Nameserver>, it is added to
the set if and only if the set contains no other
L<Zonemaster::Engine::Nameserver> with the same name and address.

=item *

If C<$name_or_ns> is a L<Zonemaster::Engine::Nameserver> and the set already
contains a L<Zonemaster::Engine::DNSName> object with the same name, the
nameserver object replaces the plain DNS name in the set.

=back

=item get( $name )

Returns a list of all items whose name is equivalent to C<$name>, or an empty
list if no match.

If only a L<Zonemaster::Engine::DNSName> is stored in the set, that name
as a single return value (or a singleton list in list context).

If one or more L<Zonemaster::Engine::Nameserver> objects with matching C<$name> are
stored in the set, returns a list comprising of those objects.

=item get_ips( $name )

Returns a list of all L<Zonemaster::Engine::Nameserver> objects with matching
C<$name> that are stored in the set.

If only a L<Zonemaster::Engine::DNSName> of the same C<$name> is stored in the
set, this function returns undef.

=item items()

Returns the entire contents of the set as a list, in an unspecified order.

=item names()

Returns the unique list of names associated with the objects stored in the
set, both plain L<Zonemaster::Engine::DNSName> objects or the names of
L<Zonemaster::Engine::Nameserver> objects.

All names are returned as L<Zonemaster::Engine::DNSName> objects.

=item sorted_items()

Returns the entire contents of the set as a list, in a deterministic order.

Items are sorted lexicographically based on their names, and if multiple
L<Zonemaster::Engine::Nameserver> objects have the same name, these are sorted
on IP addresses such that IPv4 addresses are sorted before IPv6 addresses, and
within an address family, each address is sorted based on their integer
values.

=item is_empty()

Returns true if and only ef the set contains no items.

=item difference( $other_set )

Computes the difference between two sets. Returns a pair of sets: the first
one contains the items only occurring in the left set (i.e. left minus right),
the second one the items only in the right set (i.e. right minus left).

=item equals( $other_set )

Returns true if and only if the set is equal to C<$other_set>.

=back
