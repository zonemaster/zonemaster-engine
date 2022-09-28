package Zonemaster::Engine::Packet;

use version; our $VERSION = version->declare("v1.0.5");

use 5.014002;
use warnings;

use Moose;
use Zonemaster::Engine::Util;

has 'packet' => (
    is       => 'ro',
    isa      => 'Zonemaster::LDNS::Packet',
    required => 1,
    handles  => [
        qw(
          data
          rcode
          aa
          ra
          tc
          question
          answer
          authority
          additional
          print
          string
          answersize
          unique_push
          timestamp
          type
          edns_size
          edns_rcode
          edns_version
          edns_z
          edns_data
          has_edns
          id
          querytime
          do
          opcode
          get_nsid
          )
    ]
);

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
    my %sec = map { lc( $_ ) => 1 } @section;
    my @raw;

    if ( !@section ) {
        @raw = ( $self->packet->answer, $self->packet->authority, $self->packet->additional );
    }

    if ( $sec{'answer'} ) {
        push @raw, $self->packet->answer;
    }

    if ( $sec{'authority'} ) {
        push @raw, $self->packet->authority;
    }

    if ( $sec{'additional'} ) {
        push @raw, $self->packet->additional;
    }

    @raw = grep { $_->type eq uc( $type ) } @raw;

    return @raw;
} ## end sub get_records

sub get_records_for_name {
    my ( $self, $type, $name, @section ) = @_;

    return grep { name( $_->name ) eq name( $name ) } $self->get_records( $type, @section );
}

sub has_rrs_of_type_for_name {
    my ( $self, $type, $name ) = @_;

    return ( grep { name( $_->name ) eq name( $name ) } $self->get_records( $type ) ) > 0;
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

no Moose;
__PACKAGE__->meta->make_immutable;

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

=head1 METHODS

=over

=item no_such_record

Returns true if the packet represents an existing DNS node lacking any records of the requested type.

=item no_such_name

Returns true if the packet represents a non-existent DNS node.

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

=item has_rrs_of_type_for_name($type, $name)

Returns true if the packet holds any RRs of the specified type for the given name.

=item answerfrom

Wrapper for the underlying packet method, that replaces udnefined values with the string C<E<lt>unknownE<gt>>.

=item TO_JSON

Support method for L<JSON> to be able to serialize these objects.

=back

=head1 METHODS PASSED THROUGH

These methods are passed through transparently to the underlying L<Zonemaster::LDNS::Packet> object.

=over

=item *

data

=item *

rcode

=item *

aa

=item *

ra

=item *

tc

=item *

question

=item *

answer

=item *

authority

=item *

additional

=item *

print

=item *

string

=item *

answersize

=item *

unique_push

=item *

timestamp

=item *

type

=item *

edns_size

=item *

edns_rcode

=item *

edns_version

=item *

edns_z

=item *

edns_data

=item *

has_edns

=item *

id

=item *

querytime

=item *

do

=item *

opcode

=back
