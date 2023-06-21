use Test::More;
use Test::Fatal;
use File::Slurp;

use Zonemaster::Engine::Logger::Entry;
use POSIX qw[setlocale :locale_h];

BEGIN { use_ok( 'Zonemaster::Engine::Translator' ) }

my ($json, $profile_tmp);
$json        = read_file( 't/profiles/Test-all.json' );
$profile_tmp = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_tmp );
$json        = read_file( 't/profiles/Test-all-levels.json' );
$profile_tmp = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_tmp );

my $trans = new_ok( 'Zonemaster::Engine::Translator' => [ { locale => 'C' } ] );
ok( exists $trans->data->{BASIC}{B01_PARENT_FOUND},       'expected key from file exists' );
ok( exists $trans->data->{DNSSEC}{ALGORITHM_OK}, 'expected key from module exists' );

my $entry = Zonemaster::Engine::Logger::Entry->new(
    {
        module => 'BASIC',
        tag    => 'B01_PARENT_FOUND',
        args   => { domain => 'nothing.nowhere', ns_ip_list => 'ns1.nothing.nowhere/1.1.1.1' }
    }
);

like(
    $trans->to_string( $entry ),
    qr'   \d+.\d\d INFO      The parent zone is "nothing.nowhere" as returned from name servers "ns1.nothing.nowhere/1.1.1.1".',
    'string to_stringd as expected'
);

my $untranslated = Zonemaster::Engine::Logger::Entry->new(
    {
        module => 'SYSTEM',
        tag    => 'START_TIME',
        args   => { some => 'data' }
    }
);

ok( $trans->translate_tag( $untranslated ), 'Untranslated tag gets output' );

my %methods = Zonemaster::Engine->all_methods();

foreach my $module ( keys %methods ) {
    foreach my $testmethod ( @{ $methods{$module } } ) {
        ok( $trans->_translate_tag( uc( $module ), uc( $testmethod ), {}), 'Test method '. uc( $testmethod ) . ' has message tag with description');
    }
}

done_testing;
