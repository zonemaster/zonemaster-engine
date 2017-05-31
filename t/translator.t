use Test::More;
use Test::Fatal;

use Zonemaster::Engine::Logger::Entry;
use POSIX qw[setlocale :locale_h];

BEGIN { use_ok( 'Zonemaster::Engine::Translator' ) }

my $trans = new_ok( 'Zonemaster::Engine::Translator' => [ { locale => 'C' } ] );
ok( exists $trans->data->{BASIC}{HAS_PARENT},       'expected key from file exists' );
ok( exists $trans->data->{DNSSEC}{ALGORITHM_OK}, 'expected key from module exists' );

my $entry = Zonemaster::Engine::Logger::Entry->new(
    {
        module => 'BASIC',
        tag    => 'HAS_PARENT',
        args   => { pname => 'nothing.nowhere' }
    }
);

like(
    $trans->to_string( $entry ),
    qr'   0.\d\d INFO      Parent domain \'nothing.nowhere\' was found for the tested domain.',
    'string to_stringd as expected'
);

my $untranslated = Zonemaster::Engine::Logger::Entry->new(
    {
        module => 'SYSTEM',
        tag    => 'QUERY',
        args   => { some => 'data' }
    }
);

ok( $trans->translate_tag( $untranslated ), 'Untranslated tag gets output' );

done_testing;
