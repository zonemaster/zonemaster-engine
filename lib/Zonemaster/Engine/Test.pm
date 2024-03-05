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

=head1 NAME

Zonemaster::Engine::Test - Module implementing methods to find, load and execute all Test modules

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test->run_all_for($zone);
    my @results = Zonemaster::Engine::Test->run_module('DNSSEC', $zone);
    my @results = Zonemaster::Engine::Test->run_one('DNSSEC', 'dnssec01', $zone);

=head1 TEST MODULES

Test modules are defined as modules with names starting with C<Zonemaster::Engine::Test::>.
They are expected to provide at least the following class methods:

=over

=item all()

This will be given a L<Zonemaster::Engine::Zone> object as its only argument, and, after running the
Test Cases for that Test module, is expected to return a list of L<Zonemaster::Engine::Logger::Entry> objects.
This is the entry point used by the L</run_all_for()> and L</run_module()> methods of this class.

=back

=cut

=over

=item version()

This must return the version of the Test module.

=back

=cut

=over

=item metadata()

This must return a reference to a hash, the keys of which are the names of all Test Cases in
the module, and the corresponding values are references to an array containing all the message
tags that the Test Case can use in L<log entries|Zonemaster::Engine::Logger::Entry>.

=back

=cut

=over

=item tag_descriptions()

This must return a reference to a hash, the keys of which are the message tags and the corresponding values
are strings (message IDs) corresponding to user-friendly English translations of those message tags.
Keep in mind that the message ids will be used as keys to look up translations into other languages,
so think twice before editing them.

=back

=cut

my @all_test_modules;

BEGIN {
    @all_test_modules = split /\n/, read_file( dist_file( 'Zonemaster-Engine', 'modules.txt' ) );

    for my $name ( @all_test_modules ) {
        require sprintf q{Zonemaster/Engine/Test/%s.pm}, $name;
        "Zonemaster::Engine::Test::$name"->import();
    }
}

=head1 INTERNAL METHODS

=over

=item _log_versions()

    _log_versions();

Adds logging messages regarding the current version of some modules, specifically for L<Zonemaster::Engine> and other dependency modules (e.g. L<Zonemaster::LDNS>).

=back

=cut

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

=head1 METHODS

=over

=item install()

    Zonemaster::Engine::Test->install_custom_test_module('My::Module');

Installs a custom module outside of the C<Zonemaster::Engine::Test::> namespace.
This module must be a modules that implements the same interface as the modules
in that namespace (ie. C<version()> C<all()> etc).

The effective profile will be updated to include all test cases from the custom
module.

=back

=cut

sub install_custom_test_module {
    my ( $class, $module ) = @_;

    push @all_test_modules, $module;

    $module->import();

    my $profile = Zonemaster::Engine::Profile->effective;

    my @cases = keys(%{$module->metadata});

    push @{$profile->{profile}->{test_cases}}, @cases;

    return;
}

=pod

=over

=item modules()

    my @modules_array = modules();

Returns a list of strings containing the names of all available Test modules, with the
exception of L<Zonemaster::Engine::Test::Basic> (since that one is a bit special),
based on the content of the B<share/modules.txt> file.

=back

=cut

sub modules {
    return @all_test_modules;
}

=over

=item run_all_for()

    my @logentry_array = run_all_for( $zone );

Runs the L<default set of tests|/all()> of L<all Test modules found|/modules()> for the given zone.

This method always starts with the execution of the L<Basic Test module|Zonemaster::Engine::Test::Basic>.
If the L<Basic tests|Zonemaster::Engine::Test::Basic/TESTS> fail to indicate an extremely minimal
level of function for the zone (e.g., it must have a parent domain, and it must have at least one
functional name server), the testing suite is aborted. See L<Zonemaster::Engine::Test::Basic/can_continue()>
for more details.
Otherwise, other Test modules are L<looked up and loaded|/modules()> from the B<share/modules.txt> file,
and executed in the order in which they appear in the file.
The default set of tests (Test Cases) is specified in the L</all()> method of each Test module. They
can be individually disabled by the L<profile|Zonemaster::Engine::Profile/test_cases>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub run_all_for {
    my ( $class, $zone ) = @_;
    my @results;

    Zonemaster::Engine->start_time_now();
    push @results, info( START_TIME => { time_t => time(), string => strftime( "%F %T %z", ( localtime() ) ) } );
    push @results, info( TEST_TARGET => { zone => $zone->name->string, module => 'all' } );
    _log_versions();

    if ( not( Zonemaster::Engine::Profile->effective->get( q{net.ipv4} ) or Zonemaster::Engine::Profile->effective->get( q{net.ipv6} ) ) ) {
        return info( NO_NETWORK => {} );
    }

    info( MODULE_VERSION => { module  => 'Zonemaster::Engine::Test::Basic', version => Zonemaster::Engine::Test::Basic->version } );
    push @results, Zonemaster::Engine::Test::Basic->all( $zone );
    info( MODULE_END => { module => 'Zonemaster::Engine::Test::Basic' } );

    if ( Zonemaster::Engine::Test::Basic->can_continue( $zone, @results ) and Zonemaster::Engine->can_continue() ) {
        foreach my $mod ( __PACKAGE__->modules ) {
            my $module = ( $mod =~ /::/ ? $mod : "Zonemaster::Engine::Test::$mod" );
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
        }
    }
    else {
        push @results, info( CANNOT_CONTINUE => { domain => $zone->name->string } );
    }

    return @results;
} ## end sub run_all_for

=over

=item run_module()

    my @logentry_array = run_module( $module, $zone );

Runs the L<default set of tests|/all()> of the given Test module for the given zone.

The Test module must be in the list of actively loaded modules (that is,
a module defined in the B<share/modules.txt> file).
The default set of tests (Test Cases) is specified in the L</all()> method of each Test module.
They can be individually disabled by the L<profile|Zonemaster::Engine::Profile/test_cases>.

Takes a string (module name) and a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

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
            my $m = ( $module =~ /::/ ? $module : "Zonemaster::Engine::Test::$module" );
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

=over

=item run_one()

    my @logentry_array = run_one( $module, $test_case, $zone );

Runs the given Test Case of the given Test module for the given zone.

The Test module must be in the list of actively loaded modules (that is,
a module defined in the B<share/modules.txt> file), and the Test Case
must be listed both in the L<metadata|/metadata()> of the Test module
exports and in the L<profile|Zonemaster::Engine::Profile/test_cases>.

Takes a string (module name), a string (test case name) and an array of L<Zonemaster::Engine::Zone> objects.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub run_one {
    my ( $class, $requested, $test, $zone ) = @_;
    my @res;
    my ( $module ) = grep { lc( $requested ) eq lc( $_ ) } $class->modules;
    $module = 'Basic' if ( not $module and lc( $requested ) eq 'basic' );

    Zonemaster::Engine->start_time_now();
    push @res, info( START_TIME => { time_t => time(), string => strftime( "%F %T %z", ( localtime() ) ) } );
    push @res, info( TEST_TARGET => { zone => $zone->name->string, module => $requested, testcase => $test } );
    _log_versions();
    
    if ( not( Zonemaster::Engine::Profile->effective->get( q{net.ipv4} ) or Zonemaster::Engine::Profile->effective->get( q{net.ipv6} ) ) ) {
        return info( NO_NETWORK => {} );
    }

    if ( Zonemaster::Engine->can_continue() ) {
        if ( $module ) {
            my $m = ( $module =~ /::/ ? $module : "Zonemaster::Engine::Test::$module" );
            if ( $m->metadata->{$test} and Zonemaster::Engine::Util::should_run_test( $test ) ) {
                info( MODULE_VERSION => { module => $m, version => $m->version } );
                push @res, eval { $m->$test( $zone ) };
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
        }
        else {
            info( UNKNOWN_MODULE => { module => $requested, testcase => $test, module_list => join( ':', sort $class->modules ) } );
        }
    }
    else {
        info( CANNOT_CONTINUE => { domain => $zone->name->string } );
    }

    return;
} ## end sub run_one

1;
