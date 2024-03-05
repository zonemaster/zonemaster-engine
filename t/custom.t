use Cwd qw(abs_path);
use List::Util qw(any);
use File::Spec;
use File::Basename qw(dirname);
use Test::More;
use strict;
use warnings;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
}

my $module  = 'My::Module';

my $modfile = abs_path( File::Spec->catfile(
    dirname( __FILE__ ),
    'custom.module'
) );

require_ok $modfile;

$module->import();

Zonemaster::Engine::Test->install_custom_test_module( $module );

ok any { $_ eq $module } Zonemaster::Engine::Test->modules();

my @results = Zonemaster::Engine->test_module( $module, q{example.com} );

ok scalar @results > 0;

ok scalar ( grep { 'THIS_IS_A_TEST' eq $_->tag } @results ) > 0;

done_testing;
