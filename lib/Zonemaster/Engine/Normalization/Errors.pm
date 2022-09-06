package Zonemaster::Engine::Normalization::Errors;

use strict;
use warnings;

use Carp;
use Readonly;
use Locale::TextDomain qw[Zonemaster-Engine];

use overload '""' => \&string;


Readonly my %ERRORS => (
    AMBIGUOUS_DOWNCASING => {
        message => N__ 'Ambiguous downcaseing of character "{unicode_name}" in the domain name. Use all lower case instead.',
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

sub new {
    my ( $proto, $tag, $params ) = @_;
    my $class = ref $proto || $proto;

    if (!exists $ERRORS{$tag}) {
        croak 'Unknown error tag.';
    }

    my $obj = { tag => $tag, params => {} };

    if (exists $ERRORS{$tag}->{arguments}) {
        foreach my $arg ( @{$ERRORS{$tag}->{arguments}} ) {
            if (!exists $params->{$arg} ) {
                croak "Missing arguments $arg.";
            }
            $obj->{params}->{$arg} = $params->{$arg};
        }
    }

    return bless $obj, $class;
}

sub message {
    my ( $self ) = @_;
    return __x $ERRORS{$self->{tag}}->{message}, %{$self->{params}};
}

sub tag {
    my ( $self ) = @_;

    return $self->{tag};
}

sub string {
    my ( $self ) = @_;

    return $self->message;
}

1;
