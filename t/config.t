use Test::More;

BEGIN { use_ok( 'Zonemaster::Engine::Config' ) }
use Zonemaster::Engine::Util;

my $ref = Zonemaster::Engine::Config->get;

isa_ok( $ref, 'HASH' );
is( $ref->{resolver}{defaults}{retry},              2, 'retry exists and has expected value' );
is( Zonemaster::Engine->config->resolver_defaults->{retry}, 2, 'access other way works too' );

isa_ok( Zonemaster::Engine::Config->policy, 'HASH', 'policy got loaded and' );
is( Zonemaster::Engine::Config->policy->{'EXAMPLE'}{'EXAMPLE_TAG'}, 'DEBUG', 'found policy for example tag' );
Zonemaster::Engine::Config->load_module_policy( "DNSSEC" );
is( Zonemaster::Engine::Config->policy->{DNSSEC}{ALGORITHM_OK}, 'INFO', 'Found policy loaded from module' );

Zonemaster::Engine::Config->load_config_file( 't/config.json' );
is( Zonemaster::Engine->config->resolver_defaults->{retry}, 4711, 'loading config works' );

Zonemaster::Engine::Config->load_policy_file( 't/policy.json' );
is( Zonemaster::Engine::Config->policy->{'EXAMPLE'}{'EXAMPLE_TAG'}, 'WARNING', 'loading policy works' );

my $conf = Zonemaster::Engine::Config->new;
isa_ok($conf, 'Zonemaster::Engine::Config');
isa_ok($conf->testcases, 'HASH');
ok($conf->testcases->{basic03}, 'Data for basic03 in place');
ok($conf->should_run(basic03), 'basic03 should run');

is($conf->testcases->{basic02}, undef, 'Data for basic02 does not exist');
ok($conf->should_run(basic02), 'basic02 should run');

ok(defined($conf->testcases->{placeholder}), 'Data for placeholder in place');
ok(!$conf->should_run('placeholder'), 'placeholder should not run');

ok(!defined(Zonemaster::Engine->config->resolver_source), 'No source set.');
Zonemaster::Engine->config->resolver_source('192.0.2.2');
is(Zonemaster::Engine->config->resolver_source, '192.0.2.2', 'Source correctly set.');

done_testing;
