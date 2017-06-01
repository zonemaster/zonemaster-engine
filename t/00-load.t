use 5.014002;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Zonemaster::Engine' ) || print "Bail out!\n";
}

diag( "Testing Zonemaster Engine $Zonemaster::Engine::VERSION, Perl $], $^X" );

done_testing;
