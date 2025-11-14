use strict;
use warnings;
use Test::More tests => 2;
use Test::NoWarnings;

use File::Slurp;
use POSIX qw[setlocale :locale_h];
use Test::Fatal;
use Zonemaster::Engine::Logger::Entry;
use Zonemaster::Engine::Translator;

my ($json, $profile_tmp);
$json        = read_file( 't/profiles/Test-all.json' );
$profile_tmp = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_tmp );
$json        = read_file( 't/profiles/Test-all-levels.json' );
$profile_tmp = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_tmp );

Zonemaster::Engine::Translator->initialize( locale => 'C' );

subtest 'Everything but Test::NoWarnings' => sub {
    my $trans = Zonemaster::Engine::Translator->instance();
    isa_ok $trans, 'Zonemaster::Engine::Translator',
        'Zonemaster::Engine::Translator->instance()';

    ok( exists $trans->data->{Basic}{B01_PARENT_FOUND}, 'expected key from file exists' );
    ok( exists $trans->data->{DNSSEC}{NOT_SIGNED},      'expected key from module exists' );

    my $entry = Zonemaster::Engine::Logger::Entry->new(
        {
            module   => 'Basic',
            testcase => 'Basic01',
            tag      => 'B01_PARENT_FOUND',
            args     => { domain => 'nothing.nowhere', ns_list => 'ns1.nothing.nowhere/1.1.1.1' },
        }
    );

    like(
        $trans->to_string( $entry ),
qr'   \d+.\d\d INFO      The parent zone is "nothing.nowhere" as returned from name servers "ns1.nothing.nowhere/1.1.1.1".',
        'string to_stringd as expected'
    );

    my $untranslated = Zonemaster::Engine::Logger::Entry->new(
        {
            module   => 'SYSTEM',
            testcase => 'Basic01',
            tag      => 'START_TIME',
            args     => { some => 'data' },
        }
    );

    ok( $trans->translate_tag( $untranslated ), 'Untranslated tag gets output' );

    my %methods = Zonemaster::Engine->all_methods();

    foreach my $module ( keys %methods ) {
        foreach my $testmethod ( @{ $methods{$module} } ) {
            ok( $trans->_translate_tag( $module, uc( $testmethod ), {} ),
                'Test method ' . uc( $testmethod ) . ' has message tag with description' );
        }
    }
};
