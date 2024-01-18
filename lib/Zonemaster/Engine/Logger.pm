package Zonemaster::Engine::Logger;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare("v1.0.8");

use Class::Accessor "antlers";

use Carp qw( confess );
use Data::Dumper;
use JSON::PP;
use List::MoreUtils qw[none any];
use Scalar::Util qw[blessed];
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Logger::Entry;

our $TEST_CASE_NAME = 'Unspecified';
our $MODULE_NAME = 'System';

has 'entries' => (
    is  => 'ro',
    isa => 'ArrayRef[Zonemaster::Engine::Logger::Entry]',
);
has 'callback' => (
    is  => 'rw',
    isa => 'CodeRef',
);

my $logfilter;

sub new {
    my $proto = shift;
    confess "must be called without arguments"
      if scalar( @_ ) != 0;

    my $class = ref $proto || $proto;
    return Class::Accessor::new( $class, { entries => [] } );
}

sub add {
    my ( $self, $tag, $argref, $module, $testcase ) = @_;

    $module //= $MODULE_NAME;
    $testcase //= $TEST_CASE_NAME;

    my $new =
      Zonemaster::Engine::Logger::Entry->new( { tag => uc( $tag ), args => $argref, testcase => $testcase, module => $module } );
    $self->_check_filter( $new );
    push @{ $self->entries }, $new;

    if ( $self->callback and ref( $self->callback ) eq 'CODE' ) {
        eval { $self->callback->( $new ) };
        if ( $@ ) {
            my $err = $@;
            if ( blessed( $err ) and $err->isa( "Zonemaster::Engine::Exception" ) ) {
                die $err;
            }
            else {
                $self->callback( undef );
                $self->add( LOGGER_CALLBACK_ERROR => { exception => $err } );
            }
        }
    }

    return $new;
} ## end sub add

sub _check_filter {
    my ( $self, $entry ) = @_;

    if ( ! defined $logfilter ) {
        $logfilter = Zonemaster::Engine::Profile->effective->get(q{logfilter});
    }

    if ( $logfilter ) {
        if ( $logfilter->{ uc $entry->module } ) {
            my $match = 0;
            foreach my $rule ( @{$logfilter->{ uc $entry->module }{ $entry->tag }} ) {
                foreach my $key ( keys %{ $rule->{when} } ) {
                    my $cond = $rule->{when}{$key};
                    if ( ref( $cond ) and ref( $cond ) eq 'ARRAY' ) {
                        if ( any { $_ eq $entry->args->{$key} } @$cond ) {
                            $match = 1;
                        } else {
                            $match = 0;
                            last;
                        }
                    }
                    else {
                        if ( $cond eq $entry->args->{$key} ) {
                            $match = 1;
                        } else {
                            $match = 0;
                            last;
                        }
                    }
                }
                if ( $match ) {
                    $entry->_set_level( $rule->{set} );
                    last;
                }
            }
        }
    }
    return;
} ## end sub _check_filter

sub start_time_now {
    Zonemaster::Engine::Logger::Entry->start_time_now();
    return;
}

sub reset_config {
    $logfilter = undef;
    Zonemaster::Engine::Logger::Entry->reset_config();
    return;
}

sub clear_history {
    my ( $self ) = @_;

    my $r = $self->entries;
    splice @$r, 0, scalar( @$r );

    return;
}

# get the max level from a log, return as a string
sub get_max_level {
    my ( $self ) = @_;

    my %levels = reverse Zonemaster::Engine::Logger::Entry->levels();
    my $level  = 0;

    foreach ( @{ $self->entries } ) {
        $level = $_->numeric_level if $_->numeric_level > $level;
    }

    return $levels{$level};
}

sub json {
    my ( $self, $min_level ) = @_;
    my $json    = JSON::PP->new->allow_blessed->convert_blessed->canonical;
    my %numeric = Zonemaster::Engine::Logger::Entry->levels();

    my @msg = @{ $self->entries };

    if ( $min_level and defined $numeric{ uc( $min_level ) } ) {
        @msg = grep { $_->numeric_level >= $numeric{ uc( $min_level ) } } @msg;
    }

    my @out;
    foreach my $m ( @msg ) {
        my %r;
        $r{timestamp} = $m->timestamp;
        $r{module}    = $m->module;
        $r{testcase}  = $m->testcase;
        $r{tag}       = $m->tag;
        $r{level}     = $m->level;
        $r{args}      = $m->args if $m->args;

        push @out, \%r;
    }

    return $json->encode( \@out );
} ## end sub json

1;

=head1 NAME

Zonemaster::Engine::Logger - class that holds L<Zonemaster::Engine::Logger::Entry> objects.

=head1 SYNOPSIS

    my $logger = Zonemaster::Engine::Logger->new;
    $logger->add( TAG => {some => 'arguments'});

=head1 CONSTRUCTORS

=over

=item new

Construct a new object.

    my $logger = Zonemaster::Engine::Logger->new;

=back

=head1 ATTRIBUTES

=over

=item entries

A reference to an array holding L<Zonemaster::Engine::Logger::Entry> objects.

=item callback($coderef)

If this attribute is set, the given code reference will be called every time a
log entry is added. The referenced code will be called with the newly created
entry as its single argument. The return value of the called code is ignored.

If the called code throws an exception, and the exception is not an object of
class L<Zonemaster::Engine::Exception> (or a subclass of it), the exception will be
logged as a system message at default level C<CRITICAL> and the callback
attribute will be cleared.

If an exception that is of (sub)class L<Zonemaster::Engine::Exception> is called, the
exception will simply be rethrown until it reaches the code that started the
test run that logged the message.

=back

=head1 METHODS

=over

=item add($tag, $argref, $module, $testcase)

Adds an entry with the given tag and arguments to the logger object.

C<$module> is optional and will default to
C<$Zonemaster::Engine::Logger::MODULE_NAME> if not set.

C<$testcase> is optional and will default to
C<$Zonemaster::Engine::Logger::TEST_CASE_NAME> if not set.

The variables C<$Zonemaster::Engine::Logger::MODULE_NAME> and
C<$Zonemaster::Engine::Logger::TEST_CASE_NAME> can be dynamically set to
change the default module ("System") or test case name ("Unspecified").

=item json([$level])

Returns a JSON-formatted string with all the stored log entries. If an argument
is given and is a known severity level, only messages with at least that level
will be included.

=item get_max_level

Returns the maximum log level from the entire log as the level string.

=back

=head1 CLASS METHODS

=over

=item start_time_now()

Set the logger's start time to the current time.

=item clear_history()

Remove all known log entries.

=item reset_config()

Clear the test level cached configuration.

=back

=head1 SUBROUTINES

=over

=item _check_filter($entry)

Apply the C<logfilter> defined rules to the entry. See
L<Zonemaster::Engine::Profile/"logfilter">.

=back

=cut
