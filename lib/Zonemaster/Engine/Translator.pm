package Zonemaster::Engine::Translator;

use version; our $VERSION = version->declare("v1.0.8");

use 5.014002;
use strict;
use warnings;

use Zonemaster::Engine;

use Carp;
use Locale::Messages qw[textdomain];
use Locale::TextDomain qw[Zonemaster-Engine];
use POSIX qw[setlocale LC_MESSAGES];
use Readonly;

use Moose;
use MooseX::Singleton;

has 'locale'               => ( is => 'rw', isa => 'Str' );
has 'data'                 => ( is => 'ro', isa => 'HashRef', lazy => 1, builder => '_load_data' );
has 'all_tag_descriptions' => ( is => 'ro', isa => 'HashRef', builder => '_build_all_tag_descriptions' );
has '_last_language'       => ( is => 'rw', isa => 'Str' );

###
### Tag descriptions
###

Readonly my %TAG_DESCRIPTIONS => (
    CANNOT_CONTINUE => sub {
        __x    # SYSTEM:CANNOT_CONTINUE
          "Not enough data about {zone} was found to be able to run tests.", @_;
    },
    PROFILE_FILE => sub {
        __x    # SYSTEM:PROFILE_FILE
          "Profile was read from {name}.", @_;
    },
    DEPENDENCY_VERSION => sub {
        __x    # SYSTEM:DEPENDENCY_VERSION
          "Using prerequisite module {name} version {version}.", @_;
    },
    GLOBAL_VERSION => sub {
        __x    # SYSTEM:GLOBAL_VERSION
          "Using version {version} of the Zonemaster engine.", @_;
    },
    LOGGER_CALLBACK_ERROR => sub {
        __x    # SYSTEM:LOGGER_CALLBACK_ERROR
          "Logger callback died with error: {exception}", @_;
    },
    LOOKUP_ERROR => sub {
        __x    # SYSTEM:LOOKUP_ERROR
          "DNS query to {ns} for {name}/{type}/{class} failed with error: {message}", @_;
    },
    MODULE_ERROR => sub {
        __x    # SYSTEM:MODULE_ERROR
          "Fatal error in {module}: {msg}", @_;
    },
    MODULE_VERSION => sub {
        __x    # SYSTEM:MODULE_VERSION
          "Using module {module} version {version}.", @_;
    },
    MODULE_END => sub {
        __x    # SYSTEM:MODULE_END
          "Module {module} finished running.", @_;
    },
    NO_NETWORK => sub {
        __x    # SYSTEM:NO_NETWORK
          "Both IPv4 and IPv6 are disabled.";
    },
    UNKNOWN_METHOD => sub {
        __x    # SYSTEM:UNKNOWN_METHOD
          "Request to run unknown method {method} in module {module}.", @_;
    },
    UNKNOWN_MODULE => sub {
        __x    # SYSTEM:UNKNOWN_MODULE
          "Request to run {method} in unknown module {module}. Known modules: {known}.", @_;
    },
    SKIP_IPV4_DISABLED => sub {
        __x    # SYSTEM:SKIP_IPV4_DISABLED
          "IPv4 is disabled, not sending query to {ns}.", @_;
    },
    SKIP_IPV6_DISABLED => sub {
        __x    # SYSTEM:SKIP_IPV6_DISABLED
          "IPv6 is disabled, not sending query to {ns}.", @_;
    },
    FAKE_DELEGATION => sub {
        __x    # SYSTEM:FAKE_DELEGATION
          "Followed a fake delegation.";
    },
    ADDED_FAKE_DELEGATION => sub {
        __x    # SYSTEM:ADDED_FAKE_DELEGATION
          "Added a fake delegation for domain {domain} to name server {ns}.", @_;
    },
    FAKE_DELEGATION_TO_SELF => sub {
        __x    # SYSTEM:FAKE_DELEGATION_TO_SELF
          "Name server {ns} not adding fake delegation for domain {domain} to itself.", @_;
    },
    FAKE_DELEGATION_IN_ZONE_NO_IP => sub {
        __x    # SYSTEM:FAKE_DELEGATION_IN_ZONE_NO_IP
          "The fake delegation of domain {domain} includes an in-zone name server {ns} "
          . "without mandatory glue (without IP address).",
          @_;
    },
    FAKE_DELEGATION_NO_IP => sub {
        __x    # SYSTEM:FAKE_DELEGATION_NO_IP
          "The fake delegation of domain {domain} includes a name server {ns} "
          . "that cannot be resolved to any IP address.",
          @_;
    },
    PACKET_BIG => sub {
        __x    # SYSTEM:PACKET_BIG
          "Big packet size ({size}) (try with \"{command}\").", @_;
    },
);

###
### Builder Methods
###

sub BUILD {
    my ( $self ) = @_;

    my $locale = $self->{locale} // _get_locale();

    # Make sure LC_MESSAGES can be effectively set down the line.
    delete $ENV{LC_ALL};

    $self->locale( $locale );

    return $self;
}

# Get the program's underlying LC_MESSAGES.
#
# Side effect: Updates the program's underlying LC_MESSAGES to the returned
# value.
sub _get_locale {
    return setlocale( LC_MESSAGES, "" );
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

around 'locale' => sub {
    my $next = shift;
    my ( $self, @args ) = @_;

    return $self->$next()
      unless @args;

    my $new_locale = shift @args;

    # On some systems gettext takes its locale from setlocale().
    defined setlocale( LC_MESSAGES, $new_locale )
      or return;

    $self->_last_language( $ENV{LANGUAGE} // '' );

    # On some systems gettext takes its locale from %ENV.
    $ENV{LC_MESSAGES} = $new_locale;

    # On some systems gettext refuses to switch over to another locale unless
    # the textdomain is reset.
    textdomain( 'Zonemaster-Engine' );

    $self->$next( $new_locale );

    return $new_locale;
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

    return $self->_translate_tag( $entry->module, $entry->tag, $entry->printable_args ) // $entry->string;
}

sub _translate_tag {
    my ( $self, $module, $tag, $args ) = @_;

    if ( $ENV{LANGUAGE} // '' ne $self->_last_language ) {
        $self->locale( $self->locale );
    }

    my $code = $self->all_tag_descriptions->{$module}{$tag};

    if ( $code ) {
        return $code->( %{$args} );
    }
    else {
        return undef;
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Zonemaster::Engine::Translator - translation support for Zonemaster

=head1 SYNOPSIS

    Zonemaster::Engine::Translator->initialize({ locale => 'sv_SE.UTF-8' });

    my $trans = Zonemaster::Engine::Translator->instance;
    say $trans->to_string($entry);

This is a singleton class.

The instance of this class requires exclusive control over C<$ENV{LC_MESSAGES}>
and the program's underlying LC_MESSAGES.
At times it resets gettext's textdomain.
On construction it unsets C<$ENV{LC_ALL}> and from then on it must remain unset.

On systems that support C<$ENV{LANGUAGE}>, this variable overrides the locale()
attribute unless the locale() attribute is set to C<"C">.

=head1 ATTRIBUTES

=over

=item locale

The locale used for localized messages.

    say $translator->locale();
    if ( !$translator->locale( 'sv_SE.UTF-8' ) ) {
        say "failed to update locale";
    }

The value of this attribute is mirrored in C<$ENV{LC_MESSAGES}>.

When writing to this attribute, a request is made to update the program's
underlying LC_MESSAGES.
If this request fails, the attribute value remains unchanged and an empty list
is returned.

As a side effect when successfully updating this attribute gettext's textdomain
is reset.

=item data

A reference to a hash with translation data. This is unlikely to be useful to
end-users.

=back

=head1 METHODS

=over

=item initialize(%args)

Provide initial values for the single instance of this class.

    Zonemaster::Engine::Translator->initialize( locale => 'sv_SE.UTF-8' );

This method must be called at most once and before the first call to instance().

=item instance()

Returns the single instance of this class.

    my $translator = Zonemaster::Engine::Translator->instance;

If initialize() has not been called prior to the first call to instance(), it
is the same as if initialize() had been called without arguments.

=item new(%args)

Use of this method is deprecated.

See L<MooseX::Singleton->new|MooseX::Singleton/"Singleton->new">.

=over

=item locale

If no initial value is provided to the constructor, one is determined by calling
setlocale( LC_MESSAGES, "" ).

=back

=item to_string($entry)

Takes a L<Zonemaster::Engine::Logger::Entry> object as its argument and returns a translated string with the timestamp, level, message and arguments in the
entry.

=item translate_tag

Takes a L<Zonemaster::Engine::Logger::Entry> object as its argument and returns a translation of its tag and arguments.

=item BUILD

Internal method that's only mentioned here to placate L<Pod::Coverage>.

=back

=cut
