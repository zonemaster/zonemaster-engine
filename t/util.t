use Test::More;
use Test::Differences;
use Test::Exception;

BEGIN { use_ok( 'Zonemaster::Engine::Util' ) }

isa_ok( ns( 'name', '::1' ), 'Zonemaster::Engine::Nameserver' );
isa_ok( info( 'TAG', {} ), 'Zonemaster::Engine::Logger::Entry' );
isa_ok( name( "foo.bar.com" ), 'Zonemaster::Engine::DNSName' );

my $dref = pod_extract_for( 'DNSSEC' );
isa_ok( $dref, 'HASH' );
ok( scalar( keys %$dref ) > 3, 'At least four keys' );
like( $dref->{dnssec01}, qr/Verifies that all DS records have digest types registered with IANA/, 'Expected content.' );

subtest 'parse_hints()' => sub {
    my @cases = (
        {
            name => 'Cropped IANA hints',
            hints => <<EOF,
;       This file holds the information on root name servers needed to
; -------- 8< --------
.                        3600000      NS    A.ROOT-SERVERS.NET.
A.ROOT-SERVERS.NET.      3600000      A     198.41.0.4
A.ROOT-SERVERS.NET.      3600000      AAAA  2001:503:ba3e::2:30
;
; FORMERLY NS1.ISI.EDU
;
.                        3600000      NS    B.ROOT-SERVERS.NET.
B.ROOT-SERVERS.NET.      3600000      A     199.9.14.201
B.ROOT-SERVERS.NET.      3600000      AAAA  2001:500:200::b
; -------- 8< --------
; End of file
EOF
            expected => {
                'A.ROOT-SERVERS.NET' => [ '198.41.0.4',   '2001:503:ba3e:0:0:0:2:30' ],
                'B.ROOT-SERVERS.NET' => [ '199.9.14.201', '2001:500:200:0:0:0:0:b' ],
            },
        },
        {
            name => 'Syntax error',
            hints => '(>_<)',
            error => qr/Unable to parse root hints/,
        },
    );

    for my $case ( @cases ) {
        if ( exists $case->{expected} ) {
            my $actual = Zonemaster::Engine::Util::parse_hints( $case->{hints} );
            eq_or_diff $actual, $case->{expected}, $case->{name};
        }
        else {
            throws_ok {
                Zonemaster::Engine::Util::parse_hints( $case->{hints} )
            } $case->{error}, $case->{name};
        }
    }
};

done_testing;
