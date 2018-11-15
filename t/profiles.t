#!perl -T
use 5.006;
use strict;
use warnings FATAL   => 'all';
use Test::More tests => 25;

use JSON;
use Readonly;
use Test::Differences;
use Test::Exception;

use_ok 'Zonemaster::Engine::Profile';

# JSON representation of an example profile with all properties set
Readonly my $EXAMPLE_PROFILE_1 => q(
{
  "resolver": {
    "defaults": {
      "usevc": 1,
      "dnssec": 0,
      "recurse": 1,
      "igntc": 0,
      "retry": 123,
      "retrans": 456
    },
    "source": "192.0.2.53"
  },
  "net": {
    "ipv4": 1,
    "ipv6": 0
  },
  "no_network": 1,
  "asnroots": [
    "example.com"
  ],
  "logfilter": {
    "Zone": {
      "TAG": [
        {
          "when": {
            "bananas": 0
          },
          "set": "WARNING"
        }
      ]
    }
  },
  "test_levels": {
    "Zone": {
      "TAG": "INFO"
    }
  },
  "test_cases": [
    "Zone01"
  ]
}
);

# JSON representation of an example profile with all properties set to values
# that are different than those in $EXAMPLE_PROFILE_1
Readonly my $EXAMPLE_PROFILE_2 => q(
{
  "resolver": {
    "defaults": {
      "usevc": 0,
      "dnssec": 1,
      "recurse": 0,
      "igntc": 1,
      "retry": 5678,
      "retrans": 1234
    },
    "source": "198.51.100.53"
  },
  "net": {
    "ipv4": 0,
    "ipv6": 1
  },
  "no_network": 0,
  "asnroots": [
    "asn1.example.com", "asn2.example.com"
  ],
  "logfilter": {
    "Nameserver": {
      "OTHER_TAG": [
        {
          "when": {
            "apples": 1
          },
          "set": "INFO"
        }
      ]
    }
  },
  "test_levels": {
    "Nameserver": {
      "OTHER_TAG": "ERROR"
    }
  },
  "test_cases": [
    "Zone02"
  ]
}
);

subtest 'new() returns a new profile every time' => sub {
    my $profile1 = Zonemaster::Engine::Profile->new;

    my $profile2 = Zonemaster::Engine::Profile->new;
    $profile1->set( 'net.ipv4', 1 );

    is $profile2->get( 'net.ipv4' ), undef, 'net.ipv4 is unaffected by update to another instance';
};

subtest 'new() returns a profile with all properties unset' => sub {
    my $profile = Zonemaster::Engine::Profile->new;

    is $profile->get( 'resolver.defaults.usevc' ),   undef, 'resolver.defaults.usevc is unset';
    is $profile->get( 'resolver.defaults.retrans' ), undef, 'resolver.defaults.retrans is unset';
    is $profile->get( 'resolver.defaults.dnssec' ),  undef, 'resolver.defaults.dnssec is unset';
    is $profile->get( 'resolver.defaults.recurse' ), undef, 'resolver.defaults.recurse is unset';
    is $profile->get( 'resolver.defaults.retry' ),   undef, 'resolver.defaults.retry is unset';
    is $profile->get( 'resolver.defaults.igntc' ),   undef, 'resolver.defaults.igntc is unset';
    is $profile->get( 'resolver.source' ),           undef, 'resolver.source is unset';
    is $profile->get( 'net.ipv4' ),                  undef, 'net.ipv4 is unset';
    is $profile->get( 'net.ipv6' ),                  undef, 'net.ipv6 is unset';
    is $profile->get( 'no_network' ),                undef, 'no_network is unset';
    is $profile->get( 'asnroots' ),                  undef, 'asnroots is unset';
    is $profile->get( 'logfilter' ),                 undef, 'logfilter is unset';
    is $profile->get( 'test_levels' ),               undef, 'test_levels is unset';
    is $profile->get( 'test_cases' ),                undef, 'test_cases is unset';
};

subtest 'default() returns a new profile every time' => sub {
    my $profile1 = Zonemaster::Engine::Profile->default;

    my $profile2 = Zonemaster::Engine::Profile->default;
    $profile1->set( 'net.ipv4', 1 );

    is $profile2->get( 'net.ipv4' ), undef, 'net.ipv4 is unaffected by update to another instance';
};

subtest 'default() returns a profile with all properties set' => sub {
    my $profile = Zonemaster::Engine::Profile->default;

    ok defined( $profile->get( 'resolver.defaults.usevc' ) ),   'resolver.defaults.usevc is set';
    ok defined( $profile->get( 'resolver.defaults.dnssec' ) ),  'resolver.defaults.dnssec is set';
    ok defined( $profile->get( 'resolver.defaults.recurse' ) ), 'resolver.defaults.recurse is set';
    ok defined( $profile->get( 'resolver.defaults.igntc' ) ),   'resolver.defaults.igntc is set';
    ok defined( $profile->get( 'net.ipv4' ) ),                  'net.ipv4 is set';
    ok defined( $profile->get( 'net.ipv6' ) ),                  'net.ipv6 is set';
    ok defined( $profile->get( 'no_network' ) ),                'no_network is set';
    ok defined( $profile->get( 'resolver.defaults.retry' ) ),   'resolver.defaults.retry is set';
    ok defined( $profile->get( 'resolver.defaults.retrans' ) ), 'resolver.defaults.retrans is set';
    ok defined( $profile->get( 'resolver.source' ) ),           'resolver.source is set';
    ok defined( $profile->get( 'asnroots' ) ),                  'asnroots is set';
    ok defined( $profile->get( 'logfilter' ) ),                 'logfilter is set';
    ok defined( $profile->get( 'test_levels' ) ),               'test_levels is set';
    ok defined( $profile->get( 'test_cases' ) ),                'test_cases is set';
};

subtest 'from_json() returns a new profile every time' => sub {
    my $profile1 = Zonemaster::Engine::Profile->from_json( "{}" );

    my $profile2 = Zonemaster::Engine::Profile->from_json( "{}" );
    $profile1->set( 'net.ipv4', 1 );

    is $profile2->get( 'net.ipv4' ), undef, 'net.ipv4 is unaffected by update to another instance';
};

subtest 'from_json("{}") returns a profile with all properties unset' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json( "{}" );

    is $profile->get( 'resolver.defaults.usevc' ),   undef, 'resolver.defaults.usevc is unset';
    is $profile->get( 'resolver.defaults.dnssec' ),  undef, 'resolver.defaults.dnssec is unset';
    is $profile->get( 'resolver.defaults.recurse' ), undef, 'resolver.defaults.recurse is unset';
    is $profile->get( 'resolver.defaults.igntc' ),   undef, 'resolver.defaults.igntc is unset';
    is $profile->get( 'net.ipv4' ),                  undef, 'net.ipv4 is unset';
    is $profile->get( 'net.ipv6' ),                  undef, 'net.ipv6 is unset';
    is $profile->get( 'no_network' ),                undef, 'no_network is unset';
    is $profile->get( 'resolver.defaults.retry' ),   undef, 'resolver.defaults.retry is unset';
    is $profile->get( 'resolver.defaults.retrans' ), undef, 'resolver.defaults.retrans is unset';
    is $profile->get( 'resolver.source' ),           undef, 'resolver.source is unset';
    is $profile->get( 'asnroots' ),                  undef, 'asnroots is unset';
    is $profile->get( 'logfilter' ),                 undef, 'logfilter is unset';
    is $profile->get( 'test_levels' ),               undef, 'test_levels is unset';
    is $profile->get( 'test_cases' ),                undef, 'test_cases is unset';
};

subtest 'from_json() parses values from a string' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );

    is $profile->get( 'resolver.defaults.usevc' ),   1,            'resolver.defaults.usevc was parsed from JSON';
    is $profile->get( 'resolver.defaults.dnssec' ),  0,            'resolver.defaults.dnssec was parsed from JSON';
    is $profile->get( 'resolver.defaults.recurse' ), 1,            'resolver.defaults.recurse was parsed from JSON';
    is $profile->get( 'resolver.defaults.igntc' ),   0,            'resolver.defaults.igntc was parsed from JSON';
    is $profile->get( 'net.ipv4' ),                  1,            'net.ipv4 was parsed from JSON';
    is $profile->get( 'net.ipv6' ),                  0,            'net.ipv6 was parsed from JSON';
    is $profile->get( 'no_network' ),                1,            'no_network was parsed from JSON';
    is $profile->get( 'resolver.defaults.retry' ),   123,          'resolver.defaults.retry was parsed from JSON';
    is $profile->get( 'resolver.defaults.retrans' ), 456,          'resolver.defaults.retrans was parsed from JSON';
    is $profile->get( 'resolver.source' ),           '192.0.2.53', 'resolver.source was parsed from JSON';
    is $profile->get( 'asnroots' ), ['example.com'], 'asnroots was parsed from JSON';
    is $profile->get( 'logfilter' ), { Zone => { TAG => [ { when => { bananas => 0 }, set => 'WARNING' } ] } },
      'logfilter was parsed from JSON';
    is $profile->get( 'test_levels' ), { Zone => { TAG => 'INFO' } }, 'test_levels was parsed from JSON';
    is $profile->get( 'test_cases' ), ['Zone01'], 'test_cases was parsed from JSON';
};

subtest 'from_json() dies on illegal paths' => sub {
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"foobar":1}' ) } 'foobar';
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"net":1}' ) } 'net';
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"net":{"foobar":1}}' ) } 'net.foobar';
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":1}' ) } 'resolver';
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":1}}' ) } 'resolver.defaults';
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"foobar":1}}}' ) }
    'resolver.defaults.foobar';
};

subtest 'from_json() dies on illegal values' => sub {
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver.defaults.usevc":"false"}' ); }
    "checks type of resolver.defaults.usevc";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver.defaults.dnssec":"false"}' ); }
    "checks type of resolver.defaults.dnssec";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver.defaults.recurse":"false"}' ); }
    "checks type of resolver.defaults.recurse";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver.defaults.igntc":"false"}' ); }
    "checks type of resolver.defaults.igntc";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"net.ipv4":"false"}' ); } "checks type of net.ipv4";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"net.ipv6":"false"}' ); } "checks type of net.ipv6";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"no_network":"false"}' ); } "checks type of no_network";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver.defaults.retry":0}' ); }
    "checks lower bound of resolver.defaults.retry";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver.defaults.retry":256}' ); }
    "checks upper bound of resolver.defaults.retry";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver.defaults.retry":1.5}' ); }
    "checks type of resolver.defaults.retry";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver.defaults.retrans":0}' ); }
    "checks lower bound of resolver.defaults.retrans";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver.defaults.retrans":256}' ); }
    "checks upper bound of resolver.defaults.retrans";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver.defaults.retrans":1.5}' ); }
    "checks type of resolver.defaults.retrans";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver.source":"example.com"}' ); }
    "checks type of resolver.source";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"asnroots":["noreply@example.com"]}' ); }
    "checks type of asnroots";
    dies_ok { Zonemaster::Engine::Profile->from_json( 'logfilter',   '{"logfilter":[]}' ); } "checks type of logfilter";
    dies_ok { Zonemaster::Engine::Profile->from_json( 'test_levels', '{"test_levels":[]}' ); }
    "checks type of test_levels";
    dies_ok { Zonemaster::Engine::Profile->from_json( 'test_cases', '{"test_cases":{}}' ); }
    "checks type of test_cases";
};

subtest 'get() returns 1 for true' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json(
        '{
            "resolver": {
                "defaults": {
                    "usevc": true,
                    "dnssec": true,
                    "recurse": true,
                    "igntc": true
                }
            },
            "net": {
                "ipv4": true,
                "ipv6": true
            },
            "no_network": true
        }'
    );

    is $profile->get( 'resolver.defaults.usevc' ),   1, "returns 1 for true resolver.defaults.usevc";
    is $profile->get( 'resolver.defaults.dnssec' ),  1, "returns 1 for true resolver.defaults.dnssec";
    is $profile->get( 'resolver.defaults.recurse' ), 1, "returns 1 for true resolver.defaults.recurse";
    is $profile->get( 'resolver.defaults.igntc' ),   1, "returns 1 for true resolver.defaults.igntc";
    is $profile->get( 'net.ipv4' ),                  1, "returns 1 for true net.ipv4";
    is $profile->get( 'net.ipv6' ),                  1, "returns 1 for true net.ipv6";
    is $profile->get( 'no_network' ),                1, "returns 1 for true no_network";
};

subtest 'get() returns 0 for false' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json(
        '{
            "resolver": {
                "defaults": {
                    "usevc": false,
                    "dnssec": false,
                    "recurse": false,
                    "igntc": false
                }
            },
            "net": {
                "ipv4": false,
                "ipv6": false
            },
            "no_network": false
        }'
    );

    is $profile->get( 'resolver.defaults.usevc' ),   0, "returns 0 for false resolver.defaults.usevc";
    is $profile->get( 'resolver.defaults.dnssec' ),  0, "returns 0 for false resolver.defaults.dnssec";
    is $profile->get( 'resolver.defaults.recurse' ), 0, "returns 0 for false resolver.defaults.recurse";
    is $profile->get( 'resolver.defaults.igntc' ),   0, "returns 0 for false resolver.defaults.igntc";
    is $profile->get( 'net.ipv4' ),                  0, "returns 0 for false net.ipv4";
    is $profile->get( 'net.ipv6' ),                  0, "returns 0 for false net.ipv6";
    is $profile->get( 'no_network' ),                0, "returns 0 for false no_network";
};

subtest 'get() returns deep copies of properties with complex types' => sub {
    my $profile = Zonemaster::Engine::Profile->new;
    $profile->set( 'asnroots', ['asn1.example.com'] );
    $profile->set( 'logfilter',   {} );
    $profile->set( 'test_levels', {} );
    $profile->set( 'test_cases', [] );

    push @{ $profile->get( 'asnroots' ) },   'asn2.example.com';
    push @{ $profile->get( 'test_cases' ) }, 'Zone01';
    $profile->get( 'logfilter' )->{Zone} = {};
    $profile->get( 'test_levels' )->{Zone}{TAG} = 'INFO';

    eq_or_diff $profile->get( 'asnroots' ), ['asn1.example.com'], 'get(asnroots) returns a deep copy';
    eq_or_diff $profile->get( 'logfilter' ),   {}, 'get(logfilter) returns a deep copy';
    eq_or_diff $profile->get( 'test_levels' ), {}, 'get(test_levels) returns a deep copy';
    eq_or_diff $profile->get( 'test_cases' ), [], 'get(test_cases) returns a deep copy';
};

subtest 'get() dies if the given property name is invalid' => sub {
    my $profile = Zonemaster::Engine::Profile->new;
    $profile->set( 'asnroots', [ 'asn1.example.com', 'asn2.example.com' ] );
    $profile->set( 'logfilter', { Zone => {} } );
    $profile->set( 'test_levels', { Zone => { TAG => 'INFO' } } );
    $profile->set( 'test_cases', ['Zone01'] );

    dies_ok { $profile->get( 'net' ) } 'net';
    dies_ok { $profile->get( 'net.foobar' ) } 'net.foobar';
    dies_ok { $profile->get( 'resolver.defaults' ) } 'resolver.defaults';
    dies_ok { $profile->get( 'resolver' ) } 'resolver';
    dies_ok { $profile->get( 'asnroots.1' ) } 'asnroots.1';
    dies_ok { $profile->get( 'logfilter.Zone' ) } 'logfilter.Zone';
    dies_ok { $profile->get( 'test_levels.Zone' ) } 'test_levels.Zone';
    dies_ok { $profile->get( 'test_cases.Zone01' ) } 'test_cases.Zone01';
};

subtest 'set() inserts values for unset properties' => sub {
    my $profile = Zonemaster::Engine::Profile->new;

    $profile->set( 'resolver.defaults.usevc',   1 );
    $profile->set( 'resolver.defaults.dnssec',  0 );
    $profile->set( 'resolver.defaults.recurse', 1 );
    $profile->set( 'resolver.defaults.igntc',   0 );
    $profile->set( 'net.ipv4',                  1 );
    $profile->set( 'net.ipv6',                  0 );
    $profile->set( 'no_network',                1 );
    $profile->set( 'resolver.defaults.retry',   123 );
    $profile->set( 'resolver.defaults.retrans', 456 );
    $profile->set( 'resolver.source',           '192.0.2.53' );
    $profile->set( 'asnroots', ['example.com'] );
    $profile->set( 'logfilter', { Zone => { TAG => [ { when => { bananas => 0 }, set => 'WARNING' } ] } } );
    $profile->set( 'test_levels', { Zone => { TAG => 'INFO' } } );
    $profile->set( 'test_cases', ['Zone01'] );

    is $profile->get( 'resolver.defaults.usevc' ),   1,   'resolver.defaults.usevc can be given a value when unset';
    is $profile->get( 'resolver.defaults.dnssec' ),  0,   'resolver.defaults.dnssec can be given a value when unset';
    is $profile->get( 'resolver.defaults.recurse' ), 1,   'resolver.defaults.recurse can be given a value when unset';
    is $profile->get( 'resolver.defaults.igntc' ),   0,   'resolver.defaults.igntc can be given a value when unset';
    is $profile->get( 'net.ipv4' ),                  1,   'net.ipv4 can be given a value when unset';
    is $profile->get( 'net.ipv6' ),                  0,   'net.ipv6 can be given a value when unset';
    is $profile->get( 'no_network' ),                1,   'no_network can be given a value when unset';
    is $profile->get( 'resolver.defaults.retry' ),   123, 'resolver.defaults.retry can be given a value when unset';
    is $profile->get( 'resolver.defaults.retrans' ), 456, 'resolver.defaults.retrans can be given a value when unset';
    is $profile->get( 'resolver.source' ), '192.0.2.53', 'resolver.source can be given a value when unset';
    eq_or_diff $profile->get( 'asnroots' ), ['example.com'], 'anroots can be given a value when unset';
    eq_or_diff $profile->get( 'logfilter' ), { Zone => { TAG => [ { when => { bananas => 0 }, set => 'WARNING' } ] } },
      'logfilter can be given a value when unset';
    eq_or_diff $profile->get( 'test_levels' ), { Zone => { TAG => 'INFO' } },
      'test_levels can be given a value when unset';
    eq_or_diff $profile->get( 'test_cases' ), ['Zone01'], 'test_cases can be given a value when unset';
};

subtest 'set() updates values for set properties' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );

    $profile->set( 'resolver.defaults.usevc',   0 );
    $profile->set( 'resolver.defaults.dnssec',  1 );
    $profile->set( 'resolver.defaults.recurse', 0 );
    $profile->set( 'resolver.defaults.igntc',   1 );
    $profile->set( 'net.ipv4',                  0 );
    $profile->set( 'net.ipv6',                  1 );
    $profile->set( 'no_network',                0 );
    $profile->set( 'resolver.defaults.retry',   5678 );
    $profile->set( 'resolver.defaults.retrans', 1234 );
    $profile->set( 'resolver.source',           '198.51.100.53' );
    $profile->set( 'asnroots', [ 'asn1.example.com', 'asn2.example.com' ] );
    $profile->set( 'logfilter', { Nameserver => { OTHER_TAG => [ { when => { apples => 1 }, set => 'INFO' } ] } } );
    $profile->set( 'test_levels', { Nameserver => { OTHER_TAG => 'ERROR' } } );
    $profile->set( 'test_cases', ['Zone02'] );

    is $profile->get( 'resolver.defaults.usevc' ),   0,               'resolver.defaults.usevc was updated';
    is $profile->get( 'resolver.defaults.dnssec' ),  1,               'resolver.defaults.dnssec was updated';
    is $profile->get( 'resolver.defaults.recurse' ), 0,               'resolver.defaults.recurse was updated';
    is $profile->get( 'resolver.defaults.igntc' ),   1,               'resolver.defaults.igntc was updated';
    is $profile->get( 'net.ipv4' ),                  0,               'net.ipv4 was updated';
    is $profile->get( 'net.ipv6' ),                  1,               'net.ipv6 was updated';
    is $profile->get( 'no_network' ),                0,               'no_network was updated';
    is $profile->get( 'resolver.defaults.retry' ),   5678,            'resolver.defaults.retry was updated';
    is $profile->get( 'resolver.defaults.retrans' ), 1234,            'resolver.defaults.retrans was updated';
    is $profile->get( 'resolver.source' ),           '198.51.100.53', 'resolver.source was updated';
    eq_or_diff $profile->get( 'asnroots' ), [ 'asn1.example.com', 'asn2.example.com' ], 'asnroots was updated';
    eq_or_diff $profile->get( 'logfilter' ),
      { Nameserver => { OTHER_TAG => [ { when => { apples => 1 }, set => 'INFO' } ] } }, 'logfilter was updated';
    eq_or_diff $profile->get( 'test_levels' ), { Zone => { TAG => 'INFO' } }, 'test_levels was updated';
    eq_or_diff $profile->get( 'test_cases' ), ['Zone02'], 'test_cases was updated';
};

subtest 'set() dies on attempts to unset properties' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );

    dies_ok { $profile->set( 'resolver.defaults.usevc',   undef ); } 'dies on attempt to unset resolver.defaults.usevc';
    dies_ok { $profile->set( 'resolver.defaults.dnssec',  undef ); } 'dies on attempt to unset resolver.defaults.dnssec';
    dies_ok { $profile->set( 'resolver.defaults.recurse', undef ); } 'dies on attempt to unset resolver.defaults.recurse';
    dies_ok { $profile->set( 'resolver.defaults.igntc',   undef ); } 'dies on attempt to unset resolver.defaults.igntc';
    dies_ok { $profile->set( 'net.ipv4',                  undef ); } 'dies on attempt to unset net.ipv4';
    dies_ok { $profile->set( 'net.ipv6',                  undef ); } 'dies on attempt to unset net.ipv6';
    dies_ok { $profile->set( 'no_network',                undef ); } 'dies on attempt to unset no_network';
    dies_ok { $profile->set( 'resolver.defaults.retry',   undef ); } 'dies on attempt to unset resolver.defaults.retry';
    dies_ok { $profile->set( 'resolver.defaults.retrans', undef ); } 'dies on attempt to unset resolver.defaults.retans';
    dies_ok { $profile->set( 'resolver.source',           undef ); } 'dies on attempt to unset resolver.source';
    dies_ok { $profile->set( 'asnroots',                  undef ); } 'dies on attempt to unset asnroots';
    dies_ok { $profile->set( 'logfilter',                 undef ); } 'dies on attempt to unset logfilter';
    dies_ok { $profile->set( 'test_levels',               undef ); } 'dies on attempt to unset test_levels';
    dies_ok { $profile->set( 'test_cases',                undef ); } 'dies on attempt to unset test_cases';
};

subtest 'set() dies if the given property name is invalid' => sub {
    my $profile = Zonemaster::Engine::Profile->new;
    $profile->set( 'asnroots', [ 'asn1.example.com', 'asn2.example.com' ] );
    $profile->set( 'logfilter',   { Zone => {} } );
    $profile->set( 'test_levels', { Zone => {} } );
    $profile->set( 'test_cases', ['Zone01'] );

    dies_ok { $profile->set( 'net',               1 ) } 'dies on attempt to set a value for net';
    dies_ok { $profile->set( 'net.foobar',        1 ) } 'dies on attempt to set a value for net.foobar';
    dies_ok { $profile->set( 'resolver.defaults', 1 ) } 'dies on attempt to set a value for resolver.defaults';
    dies_ok { $profile->set( 'resolver',          1 ) } 'dies on attempt to set a value for resolver';
    dies_ok { $profile->set( 'asnroots.1',        1 ) } 'dies on attempt to set a value for asnroots.1';
    dies_ok { $profile->set( 'logfilter.Zone',    1 ) } 'dies on attempt to set a value for logfilter.Zone';
    dies_ok { $profile->set( 'test_levels.Zone',  1 ) } 'dies on attempt to set a value for test_levels.Zone';
    dies_ok { $profile->set( 'test_cases.Zone01', 1 ) } 'dies on attempt to set a value for test_cases.Zone01';
};

subtest 'set() dies on illegal value' => sub {
    my $profile = Zonemaster::Engine::Profile->new;

    dies_ok { $profile->set( 'resolver.defaults.usevc',   'false' ); } 'checks type of resolver.defaults.usevc';
    dies_ok { $profile->set( 'resolver.defaults.dnssec',  'false' ); } 'checks type of resolver.defaults.dnssec';
    dies_ok { $profile->set( 'resolver.defaults.recurse', 'false' ); } 'checks type of resolver.defaults.recurse';
    dies_ok { $profile->set( 'resolver.defaults.igntc',   'false' ); } 'checks type of resolver.defaults.igntc';
    dies_ok { $profile->set( 'net.ipv4',                  'false' ); } 'checks type of net.ipv4';
    dies_ok { $profile->set( 'net.ipv6',                  'false' ); } 'checks type of net.ipv6';
    dies_ok { $profile->set( 'no_network',                'false' ); } 'checks type of no_network';
    dies_ok { $profile->set( 'resolver.defaults.retry',   0 ); } 'checks lower bound of resolver.defaults.retry';
    dies_ok { $profile->set( 'resolver.defaults.retry',   256 ); } 'checks upper bound of resolver.defaults.retry';
    dies_ok { $profile->set( 'resolver.defaults.retry',   1.5 ); } 'checks type of resolver.defaults.retry';
    dies_ok { $profile->set( 'resolver.defaults.retrans', 0 ); } 'checks lower bound of resolver.defaults.retrans';
    dies_ok { $profile->set( 'resolver.defaults.retrans', 256 ); } 'checks upper bound of resolver.defaults.retrans';
    dies_ok { $profile->set( 'resolver.defaults.retrans', 1.5 ); } 'checks type of resolver.defaults.retrans';
    dies_ok { $profile->set( 'resolver.source', ['192.0.2.53'] ); } 'checks type of resolver.defaults.usevc';
    dies_ok { $profile->set( 'asnroots',        ['noreply@example.com'] ); } 'checks type of resolver.defaults.usevc';
    dies_ok { $profile->set( 'logfilter',       [] ); } 'checks type of resolver.defaults.usevc';
    dies_ok { $profile->set( 'test_levels',     [] ); } 'checks type of resolver.defaults.usevc';
    dies_ok { $profile->set( 'test_cases', {} ); } 'checks type of resolver.defaults.usevc';
};

subtest 'merge() with a profile with all properties unset' => sub {
    my $profile1 = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );
    my $profile2 = Zonemaster::Engine::Profile->new;

    $profile1->merge( $profile2 );

    is $profile1->get( 'resolver.defaults.usevc' ),   1,            'keeps value of resolver.defaults.usevc';
    is $profile1->get( 'resolver.defaults.dnssec' ),  0,            'keeps value of resolver.defaults.dnssec';
    is $profile1->get( 'resolver.defaults.recurse' ), 1,            'keeps value of resolver.defaults.recurse';
    is $profile1->get( 'resolver.defaults.igntc' ),   0,            'keeps value of resolver.defaults.igntc';
    is $profile1->get( 'net.ipv4' ),                  1,            'keeps value of net.ipv4';
    is $profile1->get( 'net.ipv6' ),                  0,            'keeps value of net.ipv6';
    is $profile1->get( 'no_network' ),                1,            'keeps value of no_network';
    is $profile1->get( 'resolver.defaults.retry' ),   123,          'keeps value of resolver.defaults.retry';
    is $profile1->get( 'resolver.defaults.retrans' ), 456,          'keeps value of resolver.defaults.retrans';
    is $profile1->get( 'resolver.source' ),           '192.0.2.53', 'keeps value of resolver.source';
    eq_or_diff $profile1->get( 'asnroots' ), ['example.com'], 'keeps value of asnroots';
    eq_or_diff $profile1->get( 'logfilter' ), { Zone => { TAG => [ { when => { bananas => 0 }, set => 'WARNING' } ] } },
      'keeps value of logfilter';
    eq_or_diff $profile1->get( 'test_levels' ), { Zone01 => { TAG => 'INFO' } }, 'test_levels';
    eq_or_diff $profile1->get( 'test_cases' ), ['Zone01'], 'keeps value of test_cases';
};

subtest 'merge() with a profile with all properties set' => sub {
    my $profile1 = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );
    my $profile2 = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_2 );

    $profile1->merge( $profile2 );

    is $profile1->get( 'resolver.defaults.usevc' ),   0,               'updates resolver.defaults.usevc';
    is $profile1->get( 'resolver.defaults.dnssec' ),  1,               'updates resolver.defaults.dnssec';
    is $profile1->get( 'resolver.defaults.recurse' ), 0,               'updates resolver.defaults.recurse';
    is $profile1->get( 'resolver.defaults.igntc' ),   1,               'updates resolver.defaults.igntc';
    is $profile1->get( 'net.ipv4' ),                  0,               'updates net.ipv4';
    is $profile1->get( 'net.ipv6' ),                  1,               'updates net.ipv6';
    is $profile1->get( 'no_network' ),                0,               'updates no_network';
    is $profile1->get( 'resolver.defaults.retry' ),   5678,            'updates resolver.defaults.retry';
    is $profile1->get( 'resolver.defaults.retrans' ), 1234,            'updates resolver.defaults.retrans';
    is $profile1->get( 'resolver.source' ),           '198.51.100.53', 'updates resolver.source';
    is $profile1->get( 'asnroots' ), [ 'asn1.example.com', 'asn2.example.com' ], 'updates asnroots';
    is $profile1->get( 'logfilter' ),
      { Nameserver => { OTHER_TAG => [ { when => { apples => 1 }, set => 'INFO' } ] } }, 'updates logfilter';
    is $profile1->get( 'test_levels' ), { Nameserver => { OTHER_TAG => 'ERROR' } }, 'updates test_levels';
    is $profile1->get( 'test_cases' ), ['Zone02'], 'updates test_cases';
};

subtest 'merge() does not update the other profile' => sub {
    my $profile1 = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );
    my $profile2 = Zonemaster::Engine::Profile->new;

    $profile1->merge( $profile2 );

    is $profile2->get( 'resolver.defaults.usevc' ),   undef, 'resolver.defaults.usevc was untouched in other';
    is $profile2->get( 'resolver.defaults.retrans' ), undef, 'resolver.defaults.retrans was untouched in other';
    is $profile2->get( 'resolver.defaults.dnssec' ),  undef, 'resolver.defaults.dnssec was untouched in other';
    is $profile2->get( 'resolver.defaults.recurse' ), undef, 'resolver.defaults.recurse was untouched in other';
    is $profile2->get( 'resolver.defaults.retry' ),   undef, 'resolver.defaults.retry was untouched in other';
    is $profile2->get( 'resolver.defaults.igntc' ),   undef, 'resolver.defaults.igntc was untouched in other';
    is $profile2->get( 'resolver.source' ),           undef, 'resolver.source was untouched in other';
    is $profile2->get( 'net.ipv4' ),                  undef, 'net.ipv4 was untouched in other';
    is $profile2->get( 'net.ipv6' ),                  undef, 'net.ipv6 was untouched in other';
    is $profile2->get( 'no_network' ),                undef, 'no_network was untouched in other';
    is $profile2->get( 'asnroots' ),                  undef, 'asnroots was untouched in other';
    is $profile2->get( 'logfilter' ),                 undef, 'logfilter was untouched in other';
    is $profile2->get( 'test_levels' ),               undef, 'test_levels was untouched in other';
    is $profile2->get( 'test_cases' ),                undef, 'test_cases was untouched in other';
};

subtest 'to_json() returns a JSON representation of self' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );

    my $json = $profile->to_json;

    eq_or_diff decode_json( $json ), decode_json( $EXAMPLE_PROFILE_1 );
};

subtest 'to_json() omits unset properties' => sub {
    my $profile = Zonemaster::Engine::Profile->new;

    my $json = $profile->to_json;

    eq_or_diff decode_json( $json ), {};
};

subtest 'effective() is initially equivalent to default()' => sub {
    my $json0 = Zonemaster::Engine::Profile->default->to_json;

    my $json1 = Zonemaster::Engine::Profile->effective->to_json;

    eq_or_diff json_decode( $json1 ), json_decode( $json0 );
};

subtest 'effective() returns the same profile every time' => sub {
    my $profile1 = Zonemaster::Engine::Profile->effective;

    my $profile2 = Zonemaster::Engine::Profile->effective;
    $profile2->set( 'resolver.defaults.retry', 67890 );
    $profile1->set( 'resolver.defaults.retry', 12345 );

    is $profile1->get( 'resolver.defaults.retry' ), 67890;
};
