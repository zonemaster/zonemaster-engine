#!perl
use 5.14.2;
use warnings;
use Test::More;

use Test::Fatal;
use Zonemaster::Engine;
use Zonemaster::Engine::Util;
use Zonemaster::LDNS;

my $datafile = 't/nameserver-axfr.data';
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

# This should be a successful AXFR
my $ns = Zonemaster::Engine::Nameserver->new( { name => 'kennedy.faerywicca.se', address => '46.21.106.227' } );
my $counter = 0;
is(
    exception {
        $ns->axfr( 'cyberpomo.com', sub { $counter += 1; return 1; } );
    },
    undef,
    'No exception'
);
ok( ( $counter > 10 ), 'At least ten records seen' );

# This should be a refused AXFR
$counter = 0;
my $ns2 = Zonemaster::Engine::Nameserver->new( { name => 'ns.nic.se', address => '91.226.36.45' } );
like(
    exception {
        $ns2->axfr( 'iis.se', sub { $counter += 1; return 1; } );
    },
    qr/REFUSED/,
    'AXFR was refused'
);
is( $counter, 0, 'No records seen' );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}
done_testing;
