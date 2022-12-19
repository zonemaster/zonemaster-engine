package Zonemaster::Engine::Test;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare( "v1.1.12" );

use Moose;

use Readonly;
use Module::Find;
use Net::IP::XS;
use List::MoreUtils;
use Clone;

use Zonemaster::LDNS;
use Zonemaster::Engine;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Util;
use Zonemaster::Engine::Test::Basic;

use IO::Socket::INET6;    # Lazy-loads, so make sure it's here for the version logging

use File::ShareDir qw[dist_file];
use File::Slurp qw[read_file];
use Scalar::Util qw[blessed];
use POSIX qw[strftime];

my @all_test_modules;

BEGIN {
    @all_test_modules = split /\n/, read_file( dist_file( 'Zonemaster-Engine', 'modules.txt' ) );

    for my $name ( @all_test_modules ) {
        require sprintf q{Zonemaster/Engine/Test/%s.pm}, $name;
        "Zonemaster::Engine::Test::$name"->import();
    }
}

sub _log_versions {
    info( GLOBAL_VERSION => { version => Zonemaster::Engine->VERSION } );

    info( DEPENDENCY_VERSION => { name => 'Zonemaster::LDNS',      version => $Zonemaster::LDNS::VERSION } );
    info( DEPENDENCY_VERSION => { name => 'IO::Socket::INET6',     version => $IO::Socket::INET6::VERSION } );
    info( DEPENDENCY_VERSION => { name => 'Moose',                 version => $Moose::VERSION } );
    info( DEPENDENCY_VERSION => { name => 'Module::Find',          version => $Module::Find::VERSION } );
    info( DEPENDENCY_VERSION => { name => 'File::ShareDir',        version => $File::ShareDir::VERSION } );
    info( DEPENDENCY_VERSION => { name => 'File::Slurp',           version => $File::Slurp::VERSION } );
    info( DEPENDENCY_VERSION => { name => 'Net::IP::XS',           version => $Net::IP::XS::VERSION } );
    info( DEPENDENCY_VERSION => { name => 'List::MoreUtils',       version => $List::MoreUtils::VERSION } );
    info( DEPENDENCY_VERSION => { name => 'Clone',                 version => $Clone::VERSION } );
    info( DEPENDENCY_VERSION => { name => 'Readonly',              version => $Readonly::VERSION } );

    return;
} ## end sub _log_versions

sub modules {
    return @all_test_modules;
}

sub run_all_for {
    my ( $class, $zone ) = @_;
    my @results;

    Zonemaster::Engine->start_time_now();
    push @results, info( START_TIME => { time_t => time(), string => strftime( "%F %T %z", ( localtime() ) ) } );
    push @results, info( TEST_TARGET => { zone => $zone->name->string, module => 'all' } );

    info(
        MODULE_VERSION => {
            module  => 'Zonemaster::Engine::Test::Basic',
            version => Zonemaster::Engine::Test::Basic->version
        }
    );
    _log_versions();

    if ( not( Zonemaster::Engine::Profile->effective->get( q{net.ipv4} ) or Zonemaster::Engine::Profile->effective->get( q{net.ipv6} ) ) ) {
        return info( NO_NETWORK => {} );
    }

    push @results, Zonemaster::Engine::Test::Basic->all( $zone );
    info( MODULE_END => { module => 'Zonemaster::Engine::Test::Basic' } );

    if ( Zonemaster::Engine::Test::Basic->can_continue( @results ) and Zonemaster::Engine->can_continue() ) {
        foreach my $mod ( __PACKAGE__->modules ) {

            my $module = "Zonemaster::Engine::Test::$mod";
            info( MODULE_VERSION => { module => $module, version => $module->version } );
            my @res = eval { $module->all( $zone ) };
            if ( $@ ) {
                my $err = $@;
                if ( blessed $err and $err->isa( 'Zonemaster::Engine::Exception' ) ) {
                    die $err;    # Utility exception, pass it on
                }
                else {
                    push @res, info( MODULE_ERROR => { module => $module, msg => "$err" } );
                }
            }
            info( MODULE_END => { module => $module } );

            push @results, @res;
        } ## end foreach my $mod ( __PACKAGE__...)
    } ## end if ( Zonemaster::Engine::Test::Basic...)
    else {
        push @results, info( CANNOT_CONTINUE => { domain => $zone->name->string } );
    }

    return @results;
} ## end sub run_all_for

sub run_module {
    my ( $class, $requested, $zone ) = @_;
    my @res;
    my ( $module ) = grep { lc( $requested ) eq lc( $_ ) } $class->modules;
    $module = 'Basic' if ( not $module and lc( $requested ) eq 'basic' );

    Zonemaster::Engine->start_time_now();
    push @res, info( START_TIME => { time_t => time(), string => strftime( "%F %T %z", ( localtime() ) ) } );
    push @res, info( TEST_TARGET => { zone => $zone->name->string, module => $requested } );
    _log_versions();
    if ( not( Zonemaster::Engine::Profile->effective->get( q{net.ipv4} ) or Zonemaster::Engine::Profile->effective->get( q{net.ipv6} ) ) ) {
        return info( NO_NETWORK => {} );
    }

    if ( Zonemaster::Engine->can_continue() ) {
        if ( $module ) {
            my $m = "Zonemaster::Engine::Test::$module";
            info( MODULE_VERSION => { module => $m, version => $m->version } );
            push @res, eval { $m->all( $zone ) };
            if ( $@ ) {
                my $err = $@;
                if ( blessed $err and $err->isa( 'Zonemaster::Engine::Exception' ) ) {
                    die $err;    # Utility exception, pass it on
                }
                else {
                    push @res, info( MODULE_ERROR => { module => $module, msg => "$err" } );
                }
            }
            info( MODULE_END => { module => $module } );
            return @res;
        }
        else {
            info( UNKNOWN_MODULE => { module => $requested, testcase => 'all', module_list => join( ':', sort $class->modules ) } );
        }
    }
    else {
        info( CANNOT_CONTINUE => { domain => $zone->name->string } );
    }

    return;
} ## end sub run_module

sub run_one {
    my ( $class, $requested, $test, @arguments ) = @_;
    my @res;
    my ( $module ) = grep { lc( $requested ) eq lc( $_ ) } $class->modules;
    $module = 'Basic' if ( not $module and lc( $requested ) eq 'basic' );

    Zonemaster::Engine->start_time_now();
    push @res, info( START_TIME => { time_t => time(), string => strftime( "%F %T %z", ( localtime() ) ) } );
    push @res,
      info( TEST_ARGS => { module => $requested, testcase => $test, args => join( ';', map { "$_" } @arguments ) } );
    _log_versions();
    if ( not( Zonemaster::Engine::Profile->effective->get( q{net.ipv4} ) or Zonemaster::Engine::Profile->effective->get( q{net.ipv6} ) ) ) {
        return info( NO_NETWORK => {} );
    }

    if ( Zonemaster::Engine->can_continue() ) {
        if ( $module ) {
            my $m = "Zonemaster::Engine::Test::$module";
            if ( $m->metadata->{$test} ) {
                info( MODULE_VERSION => { module => $m, version => $m->version } );
                push @res, eval { $m->$test( @arguments ) };
                if ( $@ ) {
                    my $err = $@;
                    if ( blessed $err and $err->isa( 'Zonemaster::Engine::Exception' ) ) {
                        die $err;    # Utility exception, pass it on
                    }
                    else {
                        push @res, info( MODULE_ERROR => { module => $module, msg => "$err" } );
                    }
                }
                info( MODULE_END => { module => $module } );
                return @res;
            }
            else {
                info( UNKNOWN_METHOD => { module => $m, testcase => $test } );
            }
        } ## end if ( $module )
        else {
            info( UNKNOWN_MODULE => { module => $requested, testcase => $test, module_list => join( ':', sort $class->modules ) } );
        }
    }
    else {
        my $zname = q{};
        foreach my $arg ( @arguments ) {
            if ( ref($arg) eq q{Zonemaster::Engine::Zone} ) {
                $zname = $arg->name;
            }
        }
        info( CANNOT_CONTINUE => { domain => $zname } );
    }

    return;
} ## end sub run_one

1;

=head1 NAME

Zonemaster::Engine::Test - module to find, load and execute all test modules

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test->run_all_for($zone);
    my @results = Zonemaster::Engine::Test->run_module('DNSSEC', $zone);


=head1 TEST MODULES

Test modules are defined as modules with names starting with
"Zonemaster::Engine::Test::". They are expected to provide at least four
class methods, and optionally a fifth one.

=over

=item all($zone)

C<all> will be given a zone object as its only argument, and is
epected to return a list of L<Zonemaster::Engine::Logger::Entry> objects. This
is the entry point used by the C<run_all_for> and C<run_module>
methods.

=item version()

This must return the version of the test module.

=item metadata()

This must return a reference to a hash where the keys are the names of
callable methods implementing tests, and the values are references to
arrays with the tags of the messages the test methods can generate.

=item translation()

This must return a reference to a hash where the keys are all the
message tags the test module can produce, and the corresponing keys
are the english translations of those messages. The translation
strings will be used as keys to look up translations into other
languages, so think twice before editing them.

=item policy()

Optionally, a test module can implement this method, which if
implemented should return a reference to a hash where the keys are all
the message tags the module can produce and the correspondning values
are their recommended default log levels.

=back

=head1 CLASS METHODS

=over

=item modules()

Returns a list with the names of all available test modules except
L<Zonemaster::Engine::Test::Basic> (since that one is a bit special).

=item run_all_for($zone)

Runs all (default) tests in all test modules found, and returns a list
of the log entry objects they returned.

The order in which the test modules found will be executed is not
defined, except that L<Zonemaster::Engine::Test::Basic> is always executed
first. If the Basic tests fail to indicate a very basic level of
function (it must have a parent domain, and it must have at least one
functional nameserver) for the zone, no further tests will be
executed.

=item run_module($module, $zone)

Runs all default tests in the named module for the given zone.

=item run_one($module, $method, @arguments)

Run one particular test method in one particular module. The requested
module must be in the list of active loaded modules (that is, not a
module disabled by the current policy), and the method must be listed
in the metadata the module exports. If those requirements are
fulfilled, the method will be called with the provided arguments. No
attempt is made to check that the provided arguments make sense for
the particular method called. That is left entirely to the user.

=back

=cut
