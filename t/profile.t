use Test::More;

BEGIN { use_ok( 'Zonemaster::Engine::Profile' ) }
use Zonemaster::Engine::Util;

my $ref = Zonemaster::Engine::Profile->get;

isa_ok( $ref, 'HASH' );
is( $ref->{resolver}{defaults}{retry},              2, 'retry exists and has expected value' );
is( Zonemaster::Engine->profile->resolver_defaults->{retry}, 2, 'access other way works too' );

isa_ok( Zonemaster::Engine::Profile->test_levels, 'HASH', 'policy got loaded and' );
is( Zonemaster::Engine::Profile->test_levels->{'EXAMPLE'}{'EXAMPLE_TAG'}, 'DEBUG', 'found policy for example tag' );
Zonemaster::Engine::Profile->load_module_policy( "DNSSEC" );
is( Zonemaster::Engine::Profile->test_levels->{DNSSEC}{ALGORITHM_OK}, 'INFO', 'Found policy loaded from module' );

Zonemaster::Engine::Profile->load( 't/profile.json' );
is( Zonemaster::Engine->profile->resolver_defaults->{retry}, 4711, 'loading profile works' );

Zonemaster::Engine::Profile->load( 't/profile_policy.json' );
is( Zonemaster::Engine::Profile->test_levels->{'EXAMPLE'}{'EXAMPLE_TAG'}, 'WARNING', 'loading policy works' );

my $conf = Zonemaster::Engine::Profile->new;
isa_ok($conf, 'Zonemaster::Engine::Profile');
isa_ok($conf->testcases, 'HASH');
ok($conf->testcases->{basic03}, 'Data for basic03 in place');
ok($conf->should_run(basic03), 'basic03 should run');

is($conf->testcases->{basic02}, undef, 'Data for basic02 does not exist');
ok($conf->should_run(basic02), 'basic02 should run');

ok(defined($conf->testcases->{placeholder}), 'Data for placeholder in place');
ok(!$conf->should_run('placeholder'), 'placeholder should not run');

ok(!defined(Zonemaster::Engine->profile->resolver_source), 'No source set.');
Zonemaster::Engine->profile->resolver_source('192.0.2.2');
is(Zonemaster::Engine->profile->resolver_source, '192.0.2.2', 'Source correctly set.');

done_testing;
