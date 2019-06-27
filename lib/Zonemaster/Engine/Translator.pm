package Zonemaster::Engine::Translator;

use version; our $VERSION = version->declare("v1.0.8");

use 5.014002;
use strict;
use warnings;

use Zonemaster::Engine;

use Carp;
use Locale::TextDomain qw[Zonemaster-Engine];
use POSIX qw[setlocale LC_MESSAGES];
use Readonly;

use Moose;

has 'locale' => ( is => 'rw', isa => 'Str' );
has 'data' => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_load_data' );
has 'all_tag_descriptions' => ( is => 'ro', isa => 'HashRef', builder => '_build_all_tag_descriptions' );

###
### Tag descriptions
###

Readonly my %TAG_DESCRIPTIONS => (
    CANNOT_CONTINUE => sub {
        __x "Not enough data about {zone} was found to be able to run tests.", @_;
    },
    PROFILE_FILE => sub {
        __x "Profile was read from {name}.", @_;
    },
    DEPENDENCY_VERSION => sub {
        __x "Using prerequisite module {name} version {version}.", @_;
    },
    GLOBAL_VERSION => sub {
        __x "Using version {version} of the Zonemaster engine.", @_;
    },
    LOGGER_CALLBACK_ERROR => sub {
        __x "Logger callback died with error: {exception}", @_;
    },
    LOOKUP_ERROR => sub {
        __x "DNS query to {ns} for {name}/{type}/{class} failed with error: {message}", @_;
    },
    MODULE_ERROR => sub {
        __x "Fatal error in {module}: {msg}", @_;
    },
    MODULE_VERSION => sub {
        __x "Using module {module} version {version}.", @_;
    },
    MODULE_END => sub {
        __x "Module {module} finished running.", @_;
    },
    NO_NETWORK => sub {
        __x "Both IPv4 and IPv6 are disabled.";
    },
    POLICY_DISABLED => sub {
        __x "The module {name} was disabled by the policy.", @_;
    },
    UNKNOWN_METHOD => sub {
        __x "Request to run unknown method {method} in module {module}.", @_;
    },
    UNKNOWN_MODULE => sub {
        __x "Request to run {method} in unknown module {module}. Known modules: {known}.", @_;
    },
    SKIP_IPV4_DISABLED => sub {
        __x "IPv4 is disabled, not sending query to {ns}.", @_;
    },
    SKIP_IPV6_DISABLED => sub {
        __x "IPv6 is disabled, not sending query to {ns}.", @_;
    },
    FAKE_DELEGATION => sub {
        __x "Followed a fake delegation.";
    },
    ADDED_FAKE_DELEGATION => sub {
        __x "Added a fake delegation for domain {domain} to name server {ns}.", @_;
    },
    FAKE_DELEGATION_TO_SELF => sub {
        __x "Name server {ns} not adding fake delegation for domain {domain} to itself.", @_;
    },
    FAKE_DELEGATION_IN_ZONE_NO_IP => sub {
        __x "The fake delegation of domain {domain} includes an in-zone name server {ns} without mandatory glue (without IP address).", @_;
    },
    FAKE_DELEGATION_NO_IP => sub {
        __x
          "The fake delegation of domain {domain} includes a name server {ns} that cannot be resolved to any IP address.",
          @_;
    },
    PACKET_BIG => sub {
        __x "Packet size ({size}) exceeds common maximum size of {maxsize} bytes (try with \"{command}\").", @_;
    },
);

###
### Builder Methods
###

sub BUILD {
    my ( $self ) = @_;

    my $locale = $self->{locale} // _get_locale();
    $self->locale( $locale );

    return $self;
}

# Get the program's underlying LC_MESSAGES.
#
# Side effect: Updates the program's underlying LC_MESSAGES to the returned
# value.
sub _get_locale {
    my $locale = setlocale( LC_MESSAGES, "" );

    # C locale is not an option since our msgid and msgstr strings are sometimes
    # different in C and en_US.UTF-8.
    if ( $locale eq 'C' ) {
        $locale = 'en_US.UTF-8';
    }

    return $locale;
}

sub _load_data {
    my $self = shift;

    my $old_locale = $self->locale;

    $self->locale( 'C' );

    my %data;
    for my $mod ( keys %{ $self->all_tag_descriptions } ) {
        for my $tag ( keys %{ $self->all_tag_descriptions->{$mod} } ) {
            $data{$mod}{$tag} = $self->_translate_tag( $mod, $tag, {} );
        }
    }

    $self->locale( $old_locale );

    return \%data;
}

sub _build_all_tag_descriptions {
    my %all_tag_descriptions;

    $all_tag_descriptions{SYSTEM} = \%TAG_DESCRIPTIONS;
    foreach my $mod ( 'Basic', Zonemaster::Engine->modules ) {
        my $module = 'Zonemaster::Engine::Test::' . $mod;
        $all_tag_descriptions{ uc( $mod ) } = $module->tag_descriptions;
    }

    return \%all_tag_descriptions;
}

###
### Method modifiers
###

after 'locale' => sub {
    my ( $self ) = @_;

    setlocale( LC_MESSAGES, $self->{locale} );
};

###
### Working methods
###

sub to_string {
    my ( $self, $entry ) = @_;

    return sprintf( "%7.2f %-9s %s", $entry->timestamp, $entry->level, $self->translate_tag( $entry ) );
}

sub translate_tag {
    my ( $self, $entry ) = @_;

    return $self->_translate_tag( $entry->module, $entry->tag, $entry->printable_args );
}

sub _translate_tag {
    my ( $self, $module, $tag, $args ) = @_;

    # Partial workaround for FreeBSD 11. It works once, but then translation
    # gets stuck on that locale.
    local $ENV{LC_ALL} = $self->{locale};

    return $self->all_tag_descriptions->{ $module }{ $tag }->( %{ $args } );
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Zonemaster::Engine::Translator - translation support for Zonemaster

=head1 SYNOPSIS

    my $trans = Zonemaster::Engine::Translator->new({ locale => 'sv_SE.UTF-8' });
    say $trans->to_string($entry);

A side effect of constructing an object of this class is that the program's
underlying locale for message catalogs (a.k.a. LC_MESSAGES) is updated.

It does not make sense to create more than one object of this class because of
the globally stateful nature of the locale attribute.

=head1 ATTRIBUTES

=over

=item locale

The locale that should be used to find translation data. If not
explicitly provided, defaults to (in order) the contents of the
environment variable LANG, LC_ALL, LC_MESSAGES or, if none of them are
set, to C<en_US.UTF-8>.

Updating this attribute also causes an analogous update of the program's
underlying LC_MESSAGES.

=item data

A reference to a hash with translation data. This is unlikely to be useful to
end-users.

=back

=head1 METHODS

=over

=item to_string($entry)

Takes a L<Zonemaster::Engine::Logger::Entry> object as its argument and returns a translated string with the timestamp, level, message and arguments in the
entry.

=item translate_tag

Takes a L<Zonemaster::Engine::Logger::Entry> object as its argument and returns a translation of its tag and arguments.

=item BUILD

Internal method that's only mentioned here to placate L<Pod::Coverage>.

=back

=cut
