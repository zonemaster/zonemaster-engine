package Zonemaster::Engine::Logger::Entry;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare("v1.1.8");

use Carp qw( confess );
use Time::HiRes qw[time];
use JSON::PP;
use Class::Accessor;

use Zonemaster::Engine::Profile;

use base qw(Class::Accessor);

use overload '""' => \&string;

our %numeric = (
    DEBUG3   => -2,
    DEBUG2   => -1,
    DEBUG    => 0,
    INFO     => 1,
    NOTICE   => 2,
    WARNING  => 3,
    ERROR    => 4,
    CRITICAL => 5,
);

our $start_time = time();

my $json = JSON::PP->new->allow_blessed->convert_blessed->canonical;
my $test_levels_config;

__PACKAGE__->mk_ro_accessors(qw(tag args timestamp trace));


sub new {
    my ( $proto, $attrs ) = @_;
    # tag required, args optional, other built

    confess "Attribute \(tag\) is required"
      if !exists $attrs->{tag};

    confess "Argument must be a HASHREF: args"
      if exists $attrs->{args}
      && ref $attrs->{args} ne 'HASH';

    my $time = time() - $start_time;
    $time =~ s/,/\./;
    $attrs->{timestamp} = $time;
    $attrs->{trace} = _build_trace();

    # lazy attributes
    $attrs->{_module} = delete $attrs->{module} if exists $attrs->{module};
    $attrs->{_level} = delete $attrs->{level} if exists $attrs->{level};
    $attrs->{_testcase} = delete $attrs->{testcase} if exists $attrs->{testcase};

    my $class = ref $proto || $proto;
    return Class::Accessor::new( $class, $attrs );
}

sub module {
    my $self = shift;

    # Lazy default value
    if ( !exists $self->{_module} ) {
        $self->{_module} = $self->_build_module();
    }

    return $self->{_module}
}

sub level {
    my $self = shift;

    # Lazy default value
    if ( !exists $self->{_level} ) {
        $self->{_level} = $self->_build_level();
    }

    return $self->{_level}
}

sub testcase {
    my $self = shift;

    # Lazy default value
    if ( !exists $self->{_testcase} ) {
        $self->{_testcase} = $self->_build_testcase();
    }

    return $self->{_testcase}
}

sub _build_trace {
    my @trace;

    my $i = 0;

    #        0          1      2            3         4           5          6            7       8         9         10
    # $package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash
    while ( my @line = caller( $i++ ) ) {
        next unless index( $line[3], 'Zonemaster::Engine' ) == 0;
        push @trace, [ @line[ 0, 3 ] ];
    }

    return \@trace;
}

sub _build_module {
    my ( $self ) = @_;

    foreach my $e ( @{ $self->trace } ) {
        if (    $e->[1] eq 'Zonemaster::Engine::Util::info'
            and $e->[0] =~ /^Zonemaster::Engine::Test::(.*)$/ )
        {
            return uc $1;
        }
    }

    return 'SYSTEM';
}

sub _build_testcase {
    my ( $self ) = @_;

    foreach my $e ( @{ $self->trace } ) {
        if ( $e->[1] =~ /^Zonemaster::Engine::Test::([^:]+)::(\1[0-9]+)$/i )
        {
            return uc $2;
        }
    }

    return 'UNSPECIFIED';
}

sub _build_level {
    my ( $self ) = @_;
    my $string;

    if ( !defined $test_levels_config ) {
        $test_levels_config = Zonemaster::Engine::Profile->effective->get( q{test_levels} );
    }

    if ( exists $test_levels_config->{ $self->module }{ $self->tag } ) {
        $string = uc $test_levels_config->{ $self->module }{ $self->tag };
    }
    else {
        $string = 'DEBUG';
    }

    if ( defined $numeric{$string} ) {
        return $string;
    }
    else {
        die "Unknown level string: $string";
    }
}

sub _set_level {
    my ( $self, $level ) = @_;

    $self->{_level} = $level
}


sub numeric_level {
    my ( $self ) = @_;

    return $numeric{ $self->level };
}

sub levels {
    return %numeric;
}

sub string {
    my ( $self ) = @_;
    my $argstr = q{};
    ## no critic (TestingAndDebugging::ProhibitNoWarnings)
    no warnings 'uninitialized';

    if ( $self->args ) {
        my $p_args = $self->printable_args;
        $argstr = join( q{; },
            map { $_ . q{=} . ( ref( $p_args->{$_} ) ? $json->encode( $p_args->{$_} ) : $p_args->{$_} ) }
            sort keys %{$p_args} );
    }

    return sprintf( '%s%s:%s %s', $self->module, $self->testcase ? q{:} . $self->testcase : q{}, $self->tag, $argstr );
}

sub printable_args {
    my ( $self ) = @_;

    if ( $self->args ) {
        my %p_args;
        foreach my $key_arg ( keys %{ $self->args } ) {
            if ( not ref( $self->args->{$key_arg} ) ) {
                $p_args{$key_arg} = $self->args->{$key_arg};
            }
            elsif ( $key_arg eq q{asn} and ref( $self->args->{$key_arg} ) eq q{ARRAY} ) {
                $p_args{q{asn}} = join( q{,}, @{ $self->args->{$key_arg} } );
            }
            else {
                $p_args{$key_arg} = $self->args->{$key_arg};
            }
        }
        return \%p_args;
    }

    return;
} ## end sub printable_args

###
### Class method
###

sub start_time_now {
    $start_time = time();
    return;
}

sub reset_config {
    undef $test_levels_config;
    return;
}

1;

=head1 NAME

Zonemaster::Engine::Logger::Entry - module for single log entries

=head1 SYNOPSIS

    Zonemaster::Engine->logger->add( TAG => { some => 'arguments' });

There should never be a need to create a log entry object in isolation. They should always be associated with and created via a logger object.

=head1 CLASS METHODS

=over

=item new

Construct a new object.

=item levels

Returns a hash where the keys are log levels as strings and the corresponding values their numeric value.

=item start_time_now()

Set the logger's start time to the current time.

=item reset_config()

Clear the test level cached configuration.

=back

=head1 ATTRIBUTES

=over

=item module

An auto-generated identifier of the module that created the log entry. If it was generated from a module under Zonemaster::Engine::Test, it will be an
uppercased version of the part of the name after "Zonemaster::Engine::Test". For example, "Zonemaster::Engine::Test::Basic" gets the module identifier "BASIC". If the
entry was generated from anywhere else, it will get the module identifier "SYSTEM".

=item testcase

Get uppercased version of method name called in module.

=item tag

The tag that was set when the entry was created.

=item args

The argument hash reference that was provided when the entry was created.

=item timestamp

The time after the current program started running when this entry was created. This is a floating-point value with the precision provided by
L<Time::HiRes>.

=item trace

A partial stack trace for the call that created the entry. Used to create the module tag. Almost certainly not useful for anything else.

=item level

The log level associated to this log entry.

=back

=head1 METHODS

=over

=item string

Simple method to generate a string representation of the log entry. Overloaded to the stringification operator.

=item printable_args

Used to transform data from an internal/JSON representation to a "user friendly" representation one.

=item numeric_level

Returns the log level of the entry in numeric form.

=back

=cut
