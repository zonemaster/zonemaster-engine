package Zonemaster::Engine::Translator;
use 5.014002;
use warnings;
use version; our $VERSION = version->declare("v1.0.8");

use Carp qw[confess croak];
use Locale::Messages qw[textdomain];
use Locale::TextDomain qw[Zonemaster-Engine];
use POSIX qw[setlocale LC_MESSAGES];
use Readonly;
use Zonemaster::Engine::Test;

###
### Tag descriptions
###

Readonly my %TAG_DESCRIPTIONS => (
    CANNOT_CONTINUE => sub {
        __x    # SYSTEM:CANNOT_CONTINUE
          "Not enough data about {domain} was found to be able to run tests.", @_;
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
          "DNS query to {ns} for {domain}/{type}/{class} failed with error: {message}", @_;
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
          "Request to run unknown method {testcase} in module {module}.", @_;
    },
    UNKNOWN_MODULE => sub {
        __x    # SYSTEM:UNKNOWN_MODULE
          "Request to run {testcase} in unknown module {module}. Known modules: {module_list}.", @_;
    },
    SKIP_IPV4_DISABLED => sub {
        __x    # SYSTEM:SKIP_IPV4_DISABLED
          "IPv4 is disabled, not sending \"{rrtype}\" query to {ns}.", @_;
    },
    SKIP_IPV6_DISABLED => sub {
        __x    # SYSTEM:SKIP_IPV6_DISABLED
          "IPv6 is disabled, not sending \"{rrtype}\" query to {ns}.", @_;
    },
    FAKE_DELEGATION_TO_SELF => sub {
        __x    # SYSTEM:FAKE_DELEGATION_TO_SELF
          "Name server {ns} not adding fake delegation for domain {domain} to itself.", @_;
    },
    FAKE_DELEGATION_IN_ZONE_NO_IP => sub {
        __x    # SYSTEM:FAKE_DELEGATION_IN_ZONE_NO_IP
          "The fake delegation of domain {domain} includes an in-zone name server {nsname} "
          . "without mandatory glue (without IP address).",
          @_;
    },
    FAKE_DELEGATION_NO_IP => sub {
        __x    # SYSTEM:FAKE_DELEGATION_NO_IP
          "The fake delegation of domain {domain} includes a name server {nsname} "
          . "that cannot be resolved to any IP address.",
          @_;
    },
    PACKET_BIG => sub {
        __x    # SYSTEM:PACKET_BIG
          "Big packet size ({size}) (try with \"{command}\").", @_;
    },
);

###
### Construction
###

my $instance;

sub new {
    my ( $class, %attrs ) = @_;

    $class->initialize( %attrs );

    return $class->instance;
}

sub instance {
    my ( $class ) = @_;

    if ( !defined $instance ) {
        $instance = $class->initialize();
    }

    return $instance;
}

sub initialize {
    my ( $class, %attrs ) = @_;

    if ( defined $instance ) {
        confess "already initialized";
    }

    my $locale;
    if ( exists $attrs{locale} ) {
        $locale = delete $attrs{locale};

        if ( !defined $locale || ref $locale ne '' ) {
            confess "argument 'locale' must not be a defined scalar";
        }
    }

    my $obj = {
        _locale               => $locale // _init_locale(),
        _all_tag_descriptions => _build_all_tag_descriptions(),
        _last_language        => _build_last_language(),
    };

    $instance = bless $obj, $class;

    return;
}

###
### Builder Methods
###

# Get the program's underlying LC_MESSAGES and make sure it can be effectively
# updated down the line.
#
# If the underlying LC_MESSAGES is invalid, it attempts to second guess Perls
# fallback locale.
#
# Side effects:
# * Updates the program's underlying LC_MESSAGES to the returned value.
# * Unsets LC_ALL.
sub _init_locale {
    my $locale = setlocale( LC_MESSAGES, "" );

    delete $ENV{LC_ALL};

    if ( !defined $locale ) {
        my $language = $ENV{LANGUAGE} // "";
        for my $value ( split /:/, $language ) {
            if ( $value ne "" && $value !~ /[.]/ ) {
                $value .= ".UTF-8";
            }
            $locale = setlocale( LC_MESSAGES, $value );
            if ( defined $locale ) {
                last;
            }
        }
        $locale //= "C";
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

    $all_tag_descriptions{System} = \%TAG_DESCRIPTIONS;
    foreach my $mod ( Zonemaster::Engine::Test->modules ) {
        my $module = 'Zonemaster::Engine::Test::' . $mod;
        $all_tag_descriptions{ $mod } = $module->tag_descriptions;
    }

    return \%all_tag_descriptions;
}

sub _build_last_language {
    return $ENV{LANGUAGE} // '';
}

###
### Instance methods
###

sub data {
    my ( $self ) = @_;

    if ( !exists $self->{_data} ) {
        $self->{_data} = $self->_load_data;
    }

    return $self->{_data};
}

sub all_tag_descriptions {
    my ( $self ) = @_;

    return $self->{_all_tag_descriptions};
}

sub locale {
    my ( $self, @args ) = @_;

    if ( @args ) {
        my $new_locale = shift @args;

        # On some systems gettext takes its locale from setlocale().
        if ( !defined setlocale( LC_MESSAGES, $new_locale ) ) {
            return;
        }

        $self->_last_language( $ENV{LANGUAGE} // '' );

        # On some systems gettext takes its locale from %ENV.
        $ENV{LC_MESSAGES} = $new_locale;

        # On some systems gettext refuses to switch over to another locale unless
        # the textdomain is reset.
        textdomain( 'Zonemaster-Engine' );

        if ( !defined $new_locale || ref $new_locale ne '' ) {
            croak "locale must be a defined scalar";
        }

        $self->{_locale} = $new_locale;
    } ## end if ( @args )

    return $self->{_locale};
};

sub to_string {
    my ( $self, $entry ) = @_;

    return sprintf( "%7.2f %-9s %s", $entry->timestamp, $entry->level, $self->translate_tag( $entry ) );
}

sub translate_tag {
    my ( $self, $entry ) = @_;

    return $self->_translate_tag( $entry->module, $entry->tag, $entry->printable_args ) // $entry->string;
}


sub test_case_description {
    my ( $self, $test_name ) = @_;

    my $module = $test_name;
    $module =~ s/\d+$//;

    return $self->_translate_tag( $module, uc $test_name, {} ) // $test_name;
}

sub _last_language {
    my $self = shift;

    if ( @_ ) {
        my $last_language = shift;
        if ( !defined $last_language || ref $last_language ne '' ) {
            croak "_last_language must be a defined scalar";
        }
        $self->{_last_language} = $last_language;
    }

    return $self->{_last_language};
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

1;

=head1 NAME

Zonemaster::Engine::Translator - translation support for Zonemaster

=head1 SYNOPSIS

    Zonemaster::Engine::Translator->initialize( { locale => 'sv_SE.UTF-8' } );

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

=item all_tag_descriptions

=back

=head1 METHODS

=over

=item initialize(%args)

Provide initial values for the single instance of this class.

    Zonemaster::Engine::Translator->initialize( { locale => 'sv_SE.UTF-8' } );

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

=item translate_tag($entry)

Takes a L<Zonemaster::Engine::Logger::Entry> object as its argument and returns a translation of its tag and arguments.

=item test_case_description($testcase)

Takes a string (test case ID) and returns the translated test case description.

=item BUILD

Internal method that's only mentioned here to placate L<Pod::Coverage>.

=back

=cut
