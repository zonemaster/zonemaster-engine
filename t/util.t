use Test::More;
use Test::Differences;
use Test::Exception;

BEGIN { use_ok( 'Zonemaster::Engine::Util', qw( info name ns parse_hints pod_extract_for ) ) }

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
            name  => 'Syntax error',
            hints => '(>_<)',
            error => qr/Unable to parse root hints/,
        },
        {
            name  => 'Forbidden $TTL',
            hints => "\n\$TTL 3600",
            error => qr/Forbidden directive \$TTL/,
        },
        {
            name  => 'Forbidden $INCLUDE',
            hints => "\n\$INCLUDE /etc/motd",
            error => qr/Forbidden directive \$INCLUDE/,
        },
        {
            name  => 'Forbidden $ORIGIN',
            hints => "\n\$ORIGIN NET.",
            error => qr/Forbidden directive \$ORIGIN/,
        },
        {
            name  => 'Forbidden $GENERATE',
            hints => "\n\$GENERATE 65-126 $ CNAME \$.64/26",
            error => qr/Forbidden directive \$GENERATE/,
        },
        {
            name  => 'Forbidden CH class',
            hints => '.                        CH 3600000      NS    A.ROOT-SERVERS.NET.',
            error => qr/Forbidden RR class CH/,
        },
        {
            name  => 'Forbidden RR type SOA',
            hints => <<EOF,
.                        86400 SOA    a.root-servers.net. nstld.verisign-grs.com. (
                                      2022093000 ; serial
                                      1800       ; refresh (30 minutes)
                                      900        ; retry (15 minutes)
                                      604800     ; expire (1 week)
                                      86400      ; minimum (1 day)
                                      )
EOF
            error => qr/Forbidden RR type SOA/,
        },
        {
            name  => 'Forbidden RR type TXT',
            hints => '.                        3600000      TXT    "B.ROOT-SERVERS.NET"',
            error => qr/Forbidden RR type TXT/,
        },
        {
            name  => 'Wrong owner name',
            hints => 'NET.                     3600000      NS    A.ROOT-SERVERS.NET.',
            error => qr/Owner name for NS record must be "\."/,
        },
        {
            name  => 'Missing address record',
            hints => '.                        3600000      NS    A.ROOT-SERVERS.NET.',
            error => qr/No address record found for NS A\.ROOT-SERVERS\.NET/,
        },
        {
            name  => 'Orphan A record',
            hints => 'B.ROOT-SERVERS.NET.      3600000      A     199.9.14.201',
            error => qr/Ownername of A record does not match any NS RDATA/,
        },
        {
            name  => 'Orphan AAAA record',
            hints => 'B.ROOT-SERVERS.NET.      3600000      AAAA  2001:500:200::b',
            error => qr/Ownername of AAAA record does not match any NS RDATA/,
        },
        {
            name  => 'Missing NS',
            hints => '',
            error => qr/No NS record found/,
        },
    );

    for my $case ( @cases ) {
        if ( exists $case->{expected} ) {
            my $actual = parse_hints( $case->{hints} );
            eq_or_diff $actual, $case->{expected}, $case->{name};
        }
        else {
            throws_ok {
                parse_hints( $case->{hints} )
            } $case->{error}, $case->{name};
        }
    }
};

done_testing;
