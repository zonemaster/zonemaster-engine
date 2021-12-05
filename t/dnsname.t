use Test::More;

BEGIN { use_ok( 'Zonemaster::Engine::DNSName' ); }
use Zonemaster::Engine;

is_deeply( Zonemaster::Engine::DNSName->new( { labels => [qw(www iis se)] } )->labels, [ 'www', 'iis', 'se' ] );

my $name = Zonemaster::Engine::DNSName->new( 'www.iis.se' );
is_deeply( $name->labels, [ 'www', 'iis', 'se' ] );

my $root = Zonemaster::Engine::DNSName->new( '' );
is_deeply( $root->labels, [] );
is_deeply( Zonemaster::Engine::DNSName->new( '.' )->labels, [] );

is( $name->string, 'www.iis.se',  'Default, no final dot' );
is( $name->fqdn,   'www.iis.se.', 'With final dot' );
ok( 'www.iis.se' eq $name,  'Equal without dot' );
ok( 'www.iis.se.' eq $name, 'Equal with dot' );

is( $root->fqdn, '.', 'Root fqdn OK.' );
ok( '.' eq $root, 'Root equal with dot' );
ok( $root eq '.', 'Root equal with dot, other way around' );

is( Zonemaster::Engine::DNSName->new({ labels => [qw(www nic se)] }), 'www.nic.se' );
is_deeply( Zonemaster::Engine::DNSName->new( 'www.nic.se.' )->labels, [qw(www nic se)] );

is( $name->next_higher,              'iis.se' );
is( $name->next_higher->next_higher, 'se' );
is( $root->next_higher,              undef );

my $lower = Zonemaster::Engine::DNSName->new( 'iis.se' );
my $upper = Zonemaster::Engine::DNSName->new( 'IIS.SE' );
ok( $lower eq $upper, 'Comparison is case-insensitive' );

my $one = Zonemaster::Engine::DNSName->new( 'foo.bar.baz.com' );
my $two = Zonemaster::Engine::DNSName->new( 'fee.bar.baz.com' );
is( $one->common( $two ), 3, 'common label counting works' );

my $ex = Zonemaster::Engine::DNSName->new( 'example.org' );
my $pr = $ex->prepend( 'xx-example' );
is( $pr, 'xx-example.example.org', "Prepend works: $pr" );
is( $ex, 'example.org',            "Prepend does not change original: $ex" );
$pr = $root->prepend( 'xx-example' );
is( $pr, 'xx-example', "Prepend to root works: $pr" );

is( $name, Zonemaster::Engine::DNSName->new( $name ), 'Roundtrip creation works' );

my $zone  = Zonemaster::Engine->zone( 'nic.se' );
my $zname = Zonemaster::Engine::DNSName->new( $zone );
isa_ok( $zname, 'Zonemaster::Engine::DNSName' );
is( $zname, 'nic.se' );

done_testing;
