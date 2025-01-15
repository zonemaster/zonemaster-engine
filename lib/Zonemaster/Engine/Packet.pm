package Zonemaster::Engine::Packet;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.0.5");

use Class::Accessor 'antlers';
use Carp qw( confess );
use Zonemaster::Engine::Util;

has 'packet' => (
    is  => 'ro',
    isa => 'Zonemaster::LDNS::Packet',
);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my $attrs = shift;

    my $packet = delete $attrs->{packet};
    if ( %$attrs ) {
        confess "unexpected arguments: " . join ', ', sort keys %$attrs;
    }

    return Class::Accessor::new( $class, { packet => $packet } );
}

sub timestamp    { my ( $self, $time )    = @_; return $self->packet->timestamp( $time       // () ); }
sub querytime    { my ( $self, $value )   = @_; return $self->packet->querytime( $value      // () ); }
sub id           { my ( $self, $id )      = @_; return $self->packet->id( $id                // () ); }
sub opcode       { my ( $self, $string )  = @_; return $self->packet->opcode( $string        // () ); }
sub rcode        { my ( $self, $string )  = @_; return $self->packet->rcode( $string         // () ); }
sub edns_version { my ( $self, $version ) = @_; return $self->packet->edns_version( $version // () ); }

sub type       { my ( $self ) = @_; return $self->packet->type; }
sub string     { my ( $self ) = @_; return $self->packet->string; }
sub data       { my ( $self ) = @_; return $self->packet->data; }
sub aa         { my ( $self ) = @_; return $self->packet->aa; }
sub do         { my ( $self ) = @_; return $self->packet->do; }
sub ra         { my ( $self ) = @_; return $self->packet->ra; }
sub tc         { my ( $self ) = @_; return $self->packet->tc; }
sub question   { my ( $self ) = @_; return $self->packet->question; }
sub authority  { my ( $self ) = @_; return $self->packet->authority; }
sub answer     { my ( $self ) = @_; return $self->packet->answer; }
sub additional { my ( $self ) = @_; return $self->packet->additional; }
sub edns_size  { my ( $self ) = @_; return $self->packet->edns_size; }
sub edns_rcode { my ( $self ) = @_; return $self->packet->edns_rcode; }
sub edns_data  { my ( $self ) = @_; return $self->packet->edns_data; }
sub edns_z     { my ( $self ) = @_; return $self->packet->edns_z; }
sub has_edns   { my ( $self ) = @_; return $self->packet->has_edns; }

sub unique_push {
    my ( $self, $section, $rr ) = @_;
    return $self->packet->unique_push( $section, $rr );
}

sub no_such_record {
    my ( $self ) = @_;

    if ( $self->type eq 'nodata' ) {
        my ( $q ) = $self->question;
        Zonemaster::Engine::Util::info( NO_SUCH_RECORD => { name => Zonemaster::Engine::Util::name( $q->name ), type => $q->type } );

        return 1;
    }
    else {
        return;
    }
}

sub no_such_name {
    my ( $self ) = @_;

    if ( $self->type eq 'nxdomain' ) {
        my ( $q ) = $self->question;
        info( NO_SUCH_NAME => { name => name( $q->name ), type => $q->type } );

        return 1;
    }
    else {
        return;
    }
}

sub is_redirect {
    my ( $self ) = @_;

    if ( $self->type eq 'referral' ) {
        my ( $q ) = $self->question;
        my ( $a ) = $self->authority;
        Zonemaster::Engine::Util::info(
            IS_REDIRECT => {
                name => Zonemaster::Engine::DNSName->from_string( $q->name ),
                type => $q->type,
                to   => Zonemaster::Engine::DNSName->from_string( $a->name )
            }
        );

        return 1;
    }
    else {
        return;
    }
} ## end sub is_redirect

sub get_records {
    my ( $self, $type, @section ) = @_;
    @section = qw(answer authority additional) if !@section;
    my %sec = map { lc( $_ ) => 1 } @section;
    my @raw;
    $type = uc( $type );

    if ( $sec{'answer'} ) {
        push @raw, grep { $_->type eq $type } $self->packet->answer;
    }

    if ( $sec{'authority'} ) {
        push @raw, grep { $_->type eq $type } $self->packet->authority;
    }

    if ( $sec{'additional'} ) {
        push @raw, grep { $_->type eq $type } $self->packet->additional;
    }

    return @raw;
} ## end sub get_records

sub get_records_for_name {
    my ( $self, $type, $name, @section ) = @_;

    # Make sure $name is a Zonemaster::Engine::DNSName
    $name = name( $name );

    return grep { name( $_->name ) eq $name } $self->get_records( $type, @section );
}

sub has_rrs_of_type_for_name {
    my ( $self, $type, $name, @section ) = @_;

    # Make sure $name is a Zonemaster::Engine::DNSName
    $name = name( $name );

    return ( grep { name( $_->name ) eq $name } $self->get_records( $type, @section ) ) > 0;
}

sub answerfrom {
    my ( $self, @args ) = @_;

    if ( @args ) {
        $self->packet->answerfrom( @args );
    }

    my $from = $self->packet->answerfrom // '<unknown>';

    return $from;
}

sub TO_JSON {
    my ( $self ) = @_;

    return { 'Zonemaster::Engine::Packet' => $self->packet };
}

1;

=head1 NAME

Zonemaster::Engine::Packet - wrapping object for L<Zonemaster::LDNS::Packet> objects

=head1 SYNOPSIS

    my $packet = $ns->query('iis.se', 'NS');
    my @rrs = $packet->get_records('ns');

=head1 ATTRIBUTES

=over

=item packet

Holds the L<Zonemaster::LDNS::Packet> the object is wrapping.

=back

=head1 CONSTRUCTORS

=over

=item new

Construct a new instance.

=back

=head1 METHODS

=over

=item no_such_record

Returns true if the packet represents an existing DNS node lacking any records of the requested type.

=item no_such_name

Returns true if the packet represents a nonexistent DNS node.

=item is_redirect

Returns true if the packet is a redirect to another set of nameservers.

=item get_records($type[, @section])

Returns the L<Zonemaster::LDNS::RR> objects of the requested type in the packet.
If the optional C<@section> argument is given, and is a list of C<answer>,
C<authority> and C<additional>, only RRs from those sections are returned.

=item get_records_for_name($type, $name[, @section])

Returns all L<Zonemaster::LDNS::RR> objects for the given name in the packet.
If the optional C<@section> argument is given, and is a list of C<answer>,
C<authority> and C<additional>, only RRs from those sections are returned.

=item has_rrs_of_type_for_name($type, $name[, @section])

Returns true if the packet holds any RRs of the specified type for the given name.
If the optional C<@section> argument is given, and is a list of C<answer>,
C<authority> and C<additional>, only RRs from those sections are returned.

=item answerfrom

Wrapper for the underlying packet method, that replaces undefined values with the string C<E<lt>unknownE<gt>>.

=item TO_JSON

Support method for L<JSON> to be able to serialize these objects.

=back

=head1 METHODS PASSED THROUGH

These methods are passed through transparently to the underlying L<Zonemaster::LDNS::Packet> object.

=over

=item data

=item rcode

=item aa

=item ra

=item tc

=item question

=item answer

=item authority

=item additional

=item string

=item unique_push

=item timestamp

=item type

=item edns_size

=item edns_rcode

=item edns_version

=item edns_z

=item edns_data

=item has_edns

=item id

=item querytime

=item do

=item opcode

=back
