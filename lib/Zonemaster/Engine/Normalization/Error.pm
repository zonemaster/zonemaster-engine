package Zonemaster::Engine::Normalization::Error;

use v5.16.0;
use warnings;

use Carp;
use Readonly;
use Locale::TextDomain qw[Zonemaster-Engine];

use overload '""' => \&string;


=head1 NAME

Zonemaster::Engine::Normalization::Error - normalization error class


=head1 SYNOPSIS

    use Zonemaster::Engine::Normalization::Error;

    my $error = Zonemaster::Engine::Normalization::Error->new(LABEL_TOO_LONG => {label => $label});

=cut


Readonly my %ERRORS => (
    AMBIGUOUS_DOWNCASING => {
        message => N__ 'Ambiguous downcasing of character "{unicode_name}" in the domain name. Use all lower case instead.',
        arguments => [ 'unicode_name' ]
    },
    DOMAIN_NAME_TOO_LONG => {
        message => N__ 'Domain name is too long (more than 253 characters with no final dot).',
    },
    EMPTY_DOMAIN_NAME => {
        message => N__ 'Domain name is empty.'
    },
    INITIAL_DOT => {
        message => N__ 'Domain name starts with dot.'
    },
    INVALID_ASCII => {
        message => N__ 'Domain name has an ASCII label ("{label}") with a character not permitted.',
        arguments => [ 'label' ]
    },
    INVALID_U_LABEL => {
        message => N__ 'Domain name has a non-ASCII label ("{label}") which is not a valid U-label.',
        arguments => [ 'label' ]
    },
    REPEATED_DOTS => {
        message => N__ 'Domain name has repeated dots.'
    },
    LABEL_TOO_LONG => {
        message => N__ 'Domain name has a label that is too long (more than 63 characters), "{label}".',
        arguments => [ 'label' ]
    },
);

=head1 ATTRIBUTES

=over

=item tag

The message tag associated to the error.

=item params

The error message parameters to use in the message string.

=back

=head1 METHODS

=over

=item new($tag, $params)

Creates and returns a new error object.
This function will croak if there is a missing parameter for the given tag.

=cut

sub new {
    my ( $proto, $tag, $params ) = @_;
    my $class = ref $proto || $proto;

    if ( !exists $ERRORS{$tag} ) {
        croak 'Unknown error tag.';
    }

    my $obj = { tag => $tag, params => {} };

    if ( exists $ERRORS{$tag}->{arguments} ) {
        foreach my $arg ( @{$ERRORS{$tag}->{arguments}} ) {
            if ( !exists $params->{$arg} ) {
                croak "Missing arguments $arg.";
            }
            $obj->{params}->{$arg} = $params->{$arg};
        }
    }

    return bless $obj, $class;
}


=item message

Returns the translated error message using the parameters given when creating the object.

=cut

sub message {
    my ( $self ) = @_;
    return __x $ERRORS{$self->{tag}}->{message}, %{$self->{params}};
}


=item tag

Returns the message tag associated to the error.

=cut

sub tag {
    my ( $self ) = @_;

    return $self->{tag};
}

=item string

Returns a string representation of the error object. Equivalent to message().

=cut

sub string {
    my ( $self ) = @_;

    return $self->message;
}


=back

=cut

1;
