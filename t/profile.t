use Test::More;

BEGIN { use_ok( 'Zonemaster::Engine::Profile' ) }
use Zonemaster::Engine::Util;

my $ref = Zonemaster::Engine::Profile->effective;

isa_ok( $ref, 'HASH' );
is( $ref->{resolver}{defaults}{retry},              2, 'retry exists and has expected value' );
is( Zonemaster::Engine->profile->resolver_defaults->{retry}, 2, 'access other way works too' );

isa_ok( Zonemaster::Engine::Profile->test_levels, 'HASH', 'policy got loaded and' );
is( Zonemaster::Engine::Profile->test_levels->{'EXAMPLE'}{'EXAMPLE_TAG'}, 'DEBUG', 'found policy for example tag' );
Zonemaster::Engine::Profile->load_module_policy( "DNSSEC" );
is( Zonemaster::Engine::Profile->test_levels->{DNSSEC}{ALGORITHM_OK}, 'INFO', 'Found policy loaded from module' );

Zonemaster::Engine::Profile->load( q{t/profile.json} );
is( Zonemaster::Engine->profile->resolver_defaults->{retry}, 4711, 'loading profile works' );

Zonemaster::Engine::Profile->load( q{t/profile_policy.json} );
is( Zonemaster::Engine::Profile->test_levels->{'EXAMPLE'}{'EXAMPLE_TAG'}, 'WARNING', 'loading policy works' );

my $conf = Zonemaster::Engine::Profile->new;
isa_ok($conf, 'Zonemaster::Engine::Profile');
isa_ok($conf->get( q{test_cases} ), 'HASH');
ok($conf->get( q{test_cases} )->{basic03}, 'Data for basic03 in place');
ok(Zonemaster::Engine::Util::should_run_test(q{basic03}), 'basic03 should run');

is($conf->get( q{test_cases} )->{basic02}, undef, 'Data for basic02 does not exist');
ok(Zonemaster::Engine::Util::should_run_test(q{basic02}), 'basic02 should run');

ok(defined($conf->get( q{test_cases} )->{placeholder}), 'Data for placeholder in place');
ok(!Zonemaster::Engine::Util::should_run_test(q{placeholder}), 'placeholder should not run');

ok(!defined(Zonemaster::Engine->profile->get( q{resolver.source} )), 'No source set.');
Zonemaster::Engine->profile->set( q{resolver.source}, q{192.0.2.2} );
is(Zonemaster::Engine->profile->get( q{resolver.source} ), '192.0.2.2', 'Source correctly set.');

done_testing;
