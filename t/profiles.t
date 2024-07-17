use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Log::Any::Test;    # Must come before use Log::Any

use JSON::PP;
use Readonly;
use Test::Differences;
use Test::Exception;
use Log::Any qw( $log );

use Zonemaster::Engine::Profile;

# YAML representation of an example profile with all properties set
Readonly my $EXAMPLE_PROFILE_1_YAML => q(
---
resolver:
  defaults:
    fallback: true
    igntc: false
    recurse: true
    retrans: 234
    retry: 123
    usevc: true
  source4: 192.0.2.53
  source6: 2001:db8::42
net:
  ipv4: true
  ipv6: false
no_network: true
cache:
  redis:
    server: 127.0.0.1:6379
    expire: 3600
asn_db:
  style: cymru
  sources:
    cymru:
      - asn1.example.com
      - asn2.example.com
logfilter:
  Zone:
    TAG:
      - set: WARNING
        when:
          bananas: 0
test_levels:
  Zone:
    TAG: INFO
test_cases:
  - Zone01
);

# JSON representation of an example profile with all properties set
Readonly my $EXAMPLE_PROFILE_1 => q(
{
  "resolver": {
    "defaults": {
      "usevc": true,
      "recurse": true,
      "igntc": false,
      "fallback": true,
      "retry": 123,
      "retrans": 234
    },
    "source4": "192.0.2.53",
    "source6": "2001:db8::42"
  },
  "net": {
    "ipv4": true,
    "ipv6": false
  },
  "no_network": true,
  "cache": {
    "redis": {
      "server": "127.0.0.1:6379",
      "expire": 3600
    }
  },
  "asn_db" : {
      "style" : "cymru",
      "sources" : {
          "cymru" : [ "asn1.example.com", "asn2.example.com" ]
      }
  },
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
# that are different from those in $EXAMPLE_PROFILE_1
Readonly my $EXAMPLE_PROFILE_2 => q(
{
  "resolver": {
    "defaults": {
      "usevc": false,
      "recurse": false,
      "igntc": true,
      "fallback": false,
      "retry": 99,
      "retrans": 88
    },
    "source4": "198.51.100.53",
    "source6": "2001:db8::cafe"
  },
  "net": {
    "ipv4": false,
    "ipv6": true
  },
  "no_network": false,
  "cache": {
    "redis": {
      "server": "127.0.0.2:6379",
      "expire": 7200
    }
  },
  "asn_db" : {
      "style" : "ripe",
      "sources" : {
          "ripe" : [ "asn3.example.com", "asn4.example.com" ]
      }
  },
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

Readonly my $EXAMPLE_PROFILE_3 => qq(
  {
    "resolver": {
      "source4": "",
      "source6": ""
    }
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

    for my $property ( Zonemaster::Engine::Profile->all_properties ) {
        is $profile->get( $property ), undef, "$property is unset";
    }
};

subtest 'default() returns a new profile every time' => sub {
    my $profile1 = Zonemaster::Engine::Profile->default;
    $profile1->set( 'net.ipv4', 1 );

    my $profile2 = Zonemaster::Engine::Profile->default;
    $profile2->set( 'net.ipv4', 0 );

    is $profile1->get( 'net.ipv4' ), 1, 'net.ipv4 is unaffected by update to another instance';
};

subtest 'default() returns a profile with all properties set' => sub {
    my $profile = Zonemaster::Engine::Profile->default;

    for my $property ( Zonemaster::Engine::Profile->all_properties ) {
        ok defined( $profile->get( $property ) ), "$property is set";
    }
};

subtest 'from_json() returns a new profile every time' => sub {
    my $profile1 = Zonemaster::Engine::Profile->from_json( "{}" );

    my $profile2 = Zonemaster::Engine::Profile->from_json( "{}" );
    $profile1->set( 'net.ipv4', 1 );

    is $profile2->get( 'net.ipv4' ), undef, 'net.ipv4 is unaffected by update to another instance';
};

subtest 'from_json("{}") returns a profile with all properties unset' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json( "{}" );

    for my $property ( Zonemaster::Engine::Profile->all_properties ) {
        is $profile->get( $property ), undef, "$property is unset";
    }
};

subtest 'from_json() parses values from a string' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );

    is $profile->get( 'resolver.defaults.usevc' ),    1,            'resolver.defaults.usevc was parsed from JSON';
    is $profile->get( 'resolver.defaults.recurse' ),  1,            'resolver.defaults.recurse was parsed from JSON';
    is $profile->get( 'resolver.defaults.igntc' ),    0,            'resolver.defaults.igntc was parsed from JSON';
    is $profile->get( 'resolver.defaults.fallback' ), 1,            'resolver.defaults.fallback was parsed from JSON';
    is $profile->get( 'net.ipv4' ),                   1,            'net.ipv4 was parsed from JSON';
    is $profile->get( 'net.ipv6' ),                   0,            'net.ipv6 was parsed from JSON';
    is $profile->get( 'no_network' ),                 1,            'no_network was parsed from JSON';
    is $profile->get( 'resolver.defaults.retry' ),    123,          'resolver.defaults.retry was parsed from JSON';
    is $profile->get( 'resolver.defaults.retrans' ),  234,          'resolver.defaults.retrans was parsed from JSON';
    is $profile->get( 'resolver.source4' ),           '192.0.2.53', 'resolver.source4 was parsed from JSON';
    is $profile->get( 'resolver.source6' ),           '2001:db8::42', 'resolver.source6 was parsed from JSON';
    eq_or_diff $profile->get( 'asn_db.style' ),       'cymru',      'asn_db.style was parsed from JSON';
    eq_or_diff $profile->get( 'asn_db.sources' ),     { cymru => ["asn1.example.com", "asn2.example.com"] }, 'asn_db.sources was parsed from JSON';
    eq_or_diff $profile->get( 'logfilter' ), { Zone => { TAG => [ { when => { bananas => 0 }, set => 'WARNING' } ] } },
      'logfilter was parsed from JSON';
    eq_or_diff $profile->get( 'test_levels' ), { Zone => { TAG => 'INFO' } }, 'test_levels was parsed from JSON';
    eq_or_diff $profile->get( 'test_cases' ), ['Zone01'], 'test_cases was parsed from JSON';
    eq_or_diff $profile->get( 'cache' ), { redis => { server => '127.0.0.1:6379', expire => 3600 } }, 'cache was parsed from JSON';
};

subtest 'from_json() parses sentinel values from a string' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_3 );

    is $profile->get( 'resolver.source4' ), '', 'resolver.source4 was parsed from JSON';
    is $profile->get( 'resolver.source6' ), '', 'resolver.source6 was parsed from JSON';
};

subtest 'from_json() dies on illegal paths' => sub {
    throws_ok { Zonemaster::Engine::Profile->from_json( '{"foobar":1}' ) }                               qr/^.*Unknown property .*/, 'foobar';
    throws_ok { Zonemaster::Engine::Profile->from_json( '{"net":1}' ) }                                  qr/^.*Unknown property .*/, 'net';
    throws_ok { Zonemaster::Engine::Profile->from_json( '{"net":{"foobar":1}}' ) }                       qr/^.*Unknown property .*/, 'net.foobar';
    throws_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":1}' ) }                             qr/^.*Unknown property .*/, 'resolver';
    throws_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":1}}' ) }                qr/^.*Unknown property .*/, 'resolver.defaults';
    throws_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"foobar":1}}}' ) }     qr/^.*Unknown property .*/, 'resolver.defaults.foobar';
    throws_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"dnssec":1}}}' ); }    qr/^.*Unknown property .*/, 'resolver.defaults.dnssec';
    throws_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"edns_size":1}}}' ); } qr/^.*Unknown property .*/, 'resolver.defaults.edns_size';
};

subtest 'from_json() dies on illegal values' => sub {
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"usevc":0}}}' ); }     "checks type of resolver.defaults.usevc";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"recurse":0}}}' ); }   "checks type of resolver.defaults.recurse";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"igntc":1}}}' ); }     "checks type of resolver.defaults.igntc";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"fallback":0}}}' ); }  "checks type of resolver.defaults.fallback";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"net":{"ipv4":1}}' ); }                        "checks type of net.ipv4";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"net":{"ipv6":0}}' ); }                        "checks type of net.ipv6";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"no_network":1}' ); }                          "checks type of no_network";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"retry":0}}}' ); }     "checks lower bound of resolver.defaults.retry";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"retry":256}}}' ); }   "checks upper bound of resolver.defaults.retry";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"retry":1.5}}}' ); }   "checks type of resolver.defaults.retry";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"retrans":0}}}' ); }   "checks lower bound of resolver.defaults.retrans";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"retrans":256}}}' ); } "checks upper bound of resolver.defaults.retrans";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"defaults":{"retrans":1.5}}}' ); } "checks type of resolver.defaults.retrans";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"asn_db":{"style":["noreply@example"]}' ); }   "checks type of asndb.style";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"asn_db":{"sources":["noreply@example"]}' ); } "checks type of asndb.sources";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"logfilter":[]}' ); }                          "checks type of logfilter";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"test_levels":[]}' ); }                        "checks type of test_levels";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"test_cases":{}}' ); }                         "checks type of test_cases";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"cache":[]}' ); }                              "checks type of cache";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"source4":"example.com"}}' ); }    "checks type of resolver.source4";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"source4":"2001:db8::42"}}' ); }   "checks type of resolver.source4 (only IPv4)";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"source6":"example.com"}}' ); }    "checks type of resolver.source6";
    dies_ok { Zonemaster::Engine::Profile->from_json( '{"resolver":{"source6":"192.0.2.53"}}' ); }     "checks type of resolver.source6 (only IPv6)";
};

subtest 'from_yaml() equals from_json() for a similar profile' => sub {
    my $profile_json = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );
    my $profile_yaml = Zonemaster::Engine::Profile->from_yaml( $EXAMPLE_PROFILE_1_YAML );
    is_deeply( $profile_yaml, $profile_json, 'same JSON and YAML profile' );
};

subtest 'get() returns 1 for true' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json(
        '{
            "resolver": {
                "defaults": {
                    "usevc": true,
                    "recurse": true,
                    "igntc": true,
                    "fallback": true
                }
            },
            "net": {
                "ipv4": true,
                "ipv6": true
            },
            "no_network": true
        }'
    );

    is $profile->get( 'resolver.defaults.usevc' ),    1, "returns 1 for true resolver.defaults.usevc";
    is $profile->get( 'resolver.defaults.recurse' ),  1, "returns 1 for true resolver.defaults.recurse";
    is $profile->get( 'resolver.defaults.igntc' ),    1, "returns 1 for true resolver.defaults.igntc";
    is $profile->get( 'resolver.defaults.fallback' ), 1, "returns 1 for true resolver.defaults.fallback";
    is $profile->get( 'net.ipv4' ),                   1, "returns 1 for true net.ipv4";
    is $profile->get( 'net.ipv6' ),                   1, "returns 1 for true net.ipv6";
    is $profile->get( 'no_network' ),                 1, "returns 1 for true no_network";
};

subtest 'get() returns 0 for false' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json(
        '{
            "resolver": {
                "defaults": {
                    "usevc": false,
                    "recurse": false,
                    "igntc": false,
                    "fallback": false
                }
            },
            "net": {
                "ipv4": false,
                "ipv6": false
            },
            "no_network": false
        }'
    );

    is $profile->get( 'resolver.defaults.usevc' ),    0, "returns 0 for false resolver.defaults.usevc";
    is $profile->get( 'resolver.defaults.recurse' ),  0, "returns 0 for false resolver.defaults.recurse";
    is $profile->get( 'resolver.defaults.igntc' ),    0, "returns 0 for false resolver.defaults.igntc";
    is $profile->get( 'resolver.defaults.fallback' ), 0, "returns 0 for false resolver.defaults.fallback";
    is $profile->get( 'net.ipv4' ),                   0, "returns 0 for false net.ipv4";
    is $profile->get( 'net.ipv6' ),                   0, "returns 0 for false net.ipv6";
    is $profile->get( 'no_network' ),                 0, "returns 0 for false no_network";
};

subtest 'get() returns deep copies of properties with complex types' => sub {
    my $profile = Zonemaster::Engine::Profile->new;
    $profile->set( 'asn_db.sources', {} );
    $profile->set( 'logfilter',   {} );
    $profile->set( 'test_levels', {} );
    $profile->set( 'test_cases', [] );
    $profile->set( 'cache',   {} );

    $profile->get( 'asn_db.sources' )->{cymru} = ['asn1.example.com', 'asn2.example.com'];
    push @{ $profile->get( 'test_cases' ) }, 'Zone01';
    $profile->get( 'logfilter' )->{Zone} = {};
    $profile->get( 'test_levels' )->{Zone}{TAG} = 'INFO';
    $profile->get( 'cache' )->{redis}{server} = '127.0.0.1:6379';

    eq_or_diff $profile->get( 'asn_db.sources' ), {}, 'get(asn_db.sources) returns a deep copy';
    eq_or_diff $profile->get( 'logfilter' ),   {}, 'get(logfilter) returns a deep copy';
    eq_or_diff $profile->get( 'test_levels' ), {}, 'get(test_levels) returns a deep copy';
    eq_or_diff $profile->get( 'test_cases' ), [], 'get(test_cases) returns a deep copy';
    eq_or_diff $profile->get( 'cache' ),   {}, 'get(cache) returns a deep copy';
};

subtest 'get() dies if the given property name is invalid' => sub {
    my $profile = Zonemaster::Engine::Profile->new;
    $profile->set( 'asn_db.style', 'cymru' );
    $profile->set( 'asn_db.sources', { cymru => ['asn1.example.com', 'asn2.example.com'] } );
    $profile->set( 'logfilter', { Zone => {} } );
    $profile->set( 'test_levels', { Zone => { TAG => 'INFO' } } );
    $profile->set( 'test_cases', ['Zone01'] );
    $profile->set( 'cache', { redis => { server => '127.0.0.1:6379' } } );

    throws_ok { $profile->get( 'net' ) }               qr/^.*Unknown property .*/, 'net';
    throws_ok { $profile->get( 'net.foobar' ) }        qr/^.*Unknown property .*/, 'net.foobar';
    throws_ok { $profile->get( 'resolver.defaults' ) } qr/^.*Unknown property .*/, 'resolver.defaults';
    throws_ok { $profile->get( 'resolver' ) }          qr/^.*Unknown property .*/, 'resolver';
    throws_ok { $profile->get( 'asn_db.fake' ) }       qr/^.*Unknown property .*/, 'asn_db.fake';
    throws_ok { $profile->get( 'logfilter.Zone' ) }    qr/^.*Unknown property .*/, 'logfilter.Zone';
    throws_ok { $profile->get( 'test_levels.Zone' ) }  qr/^.*Unknown property .*/, 'test_levels.Zone';
    throws_ok { $profile->get( 'test_cases.Zone01' ) } qr/^.*Unknown property .*/, 'test_cases.Zone01';
    throws_ok { $profile->get( 'cache.redis' ) }       qr/^.*Unknown property .*/, 'cache.redis';
    throws_ok { $profile->get( 'resolver.defaults.dnssec' ) }    qr/^.*Unknown property .*/, 'resolver.defaults.dnssec';
    throws_ok { $profile->get( 'resolver.defaults.edns_size' ) } qr/^.*Unknown property .*/, 'resolver.defaults.edns_size';
};

subtest 'set() inserts values for unset properties' => sub {
    my $profile = Zonemaster::Engine::Profile->new;

    $profile->set( 'resolver.defaults.usevc',    1 );
    $profile->set( 'resolver.defaults.recurse',  1 );
    $profile->set( 'resolver.defaults.igntc',    0 );
    $profile->set( 'resolver.defaults.fallback', 1 );
    $profile->set( 'net.ipv4',                   0 );
    $profile->set( 'net.ipv6',                   1 );
    $profile->set( 'no_network',                 0 );
    $profile->set( 'resolver.defaults.retry',    123 );
    $profile->set( 'resolver.defaults.retrans',  234 );
    $profile->set( 'resolver.source4',           '192.0.2.53' );
    $profile->set( 'resolver.source6',           '2001:db8::42' );
    $profile->set( 'asn_db.style', 'cymru' );
    $profile->set( 'asn_db.sources', { cymru => ['asn1.example.com', 'asn2.example.com'] } );
    $profile->set( 'logfilter', { Zone => { TAG => [ { when => { bananas => 0 }, set => 'WARNING' } ] } } );
    $profile->set( 'test_levels', { Zone => { TAG => 'INFO' } } );
    $profile->set( 'test_cases', ['Zone01'] );
    $profile->set( 'cache', { redis => { server => '127.0.0.1:6379', expire => 3600 } } );

    is $profile->get( 'resolver.defaults.usevc' ),    1,   'resolver.defaults.usevc can be given a value when unset';
    is $profile->get( 'resolver.defaults.recurse' ),  1,   'resolver.defaults.recurse can be given a value when unset';
    is $profile->get( 'resolver.defaults.igntc' ),    0,   'resolver.defaults.igntc can be given a value when unset';
    is $profile->get( 'resolver.defaults.fallback' ), 1,   'resolver.defaults.fallback can be given a value when unset';
    is $profile->get( 'net.ipv4' ),                   0,   'net.ipv4 can be given a value when unset';
    is $profile->get( 'net.ipv6' ),                   1,   'net.ipv6 can be given a value when unset';
    is $profile->get( 'no_network' ),                 0,   'no_network can be given a value when unset';
    is $profile->get( 'resolver.defaults.retry' ),    123, 'resolver.defaults.retry can be given a value when unset';
    is $profile->get( 'resolver.defaults.retrans' ),  234, 'resolver.defaults.retrans can be given a value when unset';
    is $profile->get( 'resolver.source4' ),           '192.0.2.53', 'resolver.source4 can be given a value when unset';
    is $profile->get( 'resolver.source6' ),           '2001:db8::42', 'resolver.source6 can be given a value when unset';
    eq_or_diff $profile->get( 'asn_db.style' ),       'cymru', 'asn_db.style can be given a value when unset';
    eq_or_diff $profile->get( 'asn_db.sources' ),     { cymru => ['asn1.example.com', 'asn2.example.com'] }, 'asn_db.sources can be given a value when unset';
    eq_or_diff $profile->get( 'logfilter' ), { Zone => { TAG => [ { when => { bananas => 0 }, set => 'WARNING' } ] } },
      'logfilter can be given a value when unset';
    eq_or_diff $profile->get( 'test_levels' ), { Zone => { TAG => 'INFO' } },
      'test_levels can be given a value when unset';
    eq_or_diff $profile->get( 'test_cases' ), ['Zone01'], 'test_cases can be given a value when unset';
    eq_or_diff $profile->get( 'cache' ), { redis => { server => '127.0.0.1:6379', expire => 3600 } },
      'cache can be given a value when unset';
};

subtest 'set() updates values for set properties' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );

    $profile->set( 'resolver.defaults.usevc',    0 );
    $profile->set( 'resolver.defaults.recurse',  0 );
    $profile->set( 'resolver.defaults.igntc',    1 );
    $profile->set( 'resolver.defaults.fallback', 0 );
    $profile->set( 'net.ipv4',                   0 );
    $profile->set( 'net.ipv6',                   1 );
    $profile->set( 'no_network',                 0 );
    $profile->set( 'resolver.defaults.retry',    99 );
    $profile->set( 'resolver.defaults.retrans',  88 );
    $profile->set( 'resolver.source4',           '198.51.100.53' );
    $profile->set( 'resolver.source6',            '2001:db8::cafe' );
    $profile->set( 'asn_db.style', 'ripe' );
    $profile->set( 'asn_db.sources', { ripe => ['asn3.example.com', 'asn4.example.com'] } );
    $profile->set( 'logfilter', { Nameserver => { OTHER_TAG => [ { when => { apples => 1 }, set => 'INFO' } ] } } );
    $profile->set( 'test_levels', { Nameserver => { OTHER_TAG => 'ERROR' } } );
    $profile->set( 'test_cases', ['Zone02'] );
    $profile->set( 'cache', { redis => { server => '127.0.0.2:6379', expire => 7200 } } );

    is $profile->get( 'resolver.defaults.usevc' ),   0,               'resolver.defaults.usevc was updated';
    is $profile->get( 'resolver.defaults.recurse' ), 0,               'resolver.defaults.recurse was updated';
    is $profile->get( 'resolver.defaults.igntc' ),   1,               'resolver.defaults.igntc was updated';
    is $profile->get( 'net.ipv4' ),                  0,               'net.ipv4 was updated';
    is $profile->get( 'net.ipv6' ),                  1,               'net.ipv6 was updated';
    is $profile->get( 'no_network' ),                0,               'no_network was updated';
    is $profile->get( 'resolver.defaults.retry' ),   99,              'resolver.defaults.retry was updated';
    is $profile->get( 'resolver.defaults.retrans' ), 88,              'resolver.defaults.retrans was updated';
    is $profile->get( 'resolver.source4' ),          '198.51.100.53', 'resolver.source4 was updated';
    is $profile->get( 'resolver.source6' ),          '2001:db8::cafe', 'resolver.source6 was updated';
    eq_or_diff $profile->get( 'asn_db.style' ),      'ripe', 'asn_db.style was updated';
    eq_or_diff $profile->get( 'asn_db.sources' ),    { ripe => ['asn3.example.com', 'asn4.example.com'] }, 'asn_db.sources was updated';
    eq_or_diff $profile->get( 'logfilter' ),
      { Nameserver => { OTHER_TAG => [ { when => { apples => 1 }, set => 'INFO' } ] } }, 'logfilter was updated';
    eq_or_diff $profile->get( 'test_levels' ), { Nameserver => { OTHER_TAG => 'ERROR' } }, 'test_levels was updated';
    eq_or_diff $profile->get( 'test_cases' ), ['Zone02'], 'test_cases was updated';
    eq_or_diff $profile->get( 'cache' ), { redis => { server => '127.0.0.2:6379', expire => 7200 } },
    'cache was updated';
};

subtest 'set() dies on attempts to unset properties' => sub {
    my $profile = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );

    for my $property ( Zonemaster::Engine::Profile->all_properties ) {
        throws_ok { $profile->set( $property, undef ); } qr/^.* can not be undef/, "dies on attempt to unset $property";
    }
};

subtest 'set() dies if the given property name is invalid' => sub {
    my $profile = Zonemaster::Engine::Profile->new;
    $profile->set( 'asn_db.style', 'cymru' );
    $profile->set( 'asn_db.sources', { cymru => ['asn1.example.com', 'asn2.example.com'] } );
    $profile->set( 'logfilter',   { Zone => {} } );
    $profile->set( 'test_levels', { Zone => {} } );
    $profile->set( 'test_cases', ['Zone01'] );
    $profile->set( 'cache', { redis => { server => '127.0.0.1:6379' } } );

    throws_ok { $profile->set( 'net',               1 ) } qr/^.*Unknown property .*/, 'dies on attempt to set a value for net';
    throws_ok { $profile->set( 'net.foobar',        1 ) } qr/^.*Unknown property .*/, 'dies on attempt to set a value for net.foobar';
    throws_ok { $profile->set( 'resolver.defaults', 1 ) } qr/^.*Unknown property .*/, 'dies on attempt to set a value for resolver.defaults';
    throws_ok { $profile->set( 'resolver',          1 ) } qr/^.*Unknown property .*/, 'dies on attempt to set a value for resolver';
    throws_ok { $profile->set( 'asn_db.fake',       1 ) } qr/^.*Unknown property .*/, 'dies on attempt to set a value for asn_db.fake';
    throws_ok { $profile->set( 'logfilter.Zone',    1 ) } qr/^.*Unknown property .*/, 'dies on attempt to set a value for logfilter.Zone';
    throws_ok { $profile->set( 'test_levels.Zone',  1 ) } qr/^.*Unknown property .*/, 'dies on attempt to set a value for test_levels.Zone';
    throws_ok { $profile->set( 'test_cases.Zone01', 1 ) } qr/^.*Unknown property .*/, 'dies on attempt to set a value for test_cases.Zone01';
    throws_ok { $profile->set( 'cache.redis',       1 ) } qr/^.*Unknown property .*/, 'dies on attempt to set a value for cache.redis';
    throws_ok { $profile->set( 'resolver.defaults.dnssec', 1 ) }    qr/^.*Unknown property .*/, 'dies on attempt to set a value for resolver.defaults.dnssec';
    throws_ok { $profile->set( 'resolver.defaults.edns_size', 1 ) } qr/^.*Unknown property .*/, 'dies on attempt to set a value for resolver.defaults.edns_size';
};

subtest 'set() dies on illegal value' => sub {
    my $profile = Zonemaster::Engine::Profile->new;

    dies_ok { $profile->set( 'resolver.defaults.retry',   0 ); } 'checks lower bound of resolver.defaults.retry';
    dies_ok { $profile->set( 'resolver.defaults.retry',   256 ); } 'checks upper bound of resolver.defaults.retry';
    dies_ok { $profile->set( 'resolver.defaults.retry',   1.5 ); } 'checks type of resolver.defaults.retry';
    dies_ok { $profile->set( 'resolver.defaults.retrans', 0 ); } 'checks lower bound of resolver.defaults.retrans';
    dies_ok { $profile->set( 'resolver.defaults.retrans', 256 ); } 'checks upper bound of resolver.defaults.retrans';
    dies_ok { $profile->set( 'resolver.defaults.retrans', 1.5 ); } 'checks type of resolver.defaults.retrans';
    dies_ok { $profile->set( 'resolver.source4', 'example.com' ); } 'resolver.source4 rejects domain name string';
    dies_ok { $profile->set( 'resolver.source4', ['192.0.2.53'] ); } 'resolver.source4 rejects arrayref';
    dies_ok { $profile->set( 'resolver.source6', 'example.com' ); } 'resolver.source6 rejects domain name string';
    dies_ok { $profile->set( 'resolver.source6', ['2001:db8::42'] ); } 'resolver.source6 rejects arrayref';
    dies_ok { $profile->set( 'asn_db.style',     ['noreply@example.com'] ); } 'checks type of asn_db.style';
    dies_ok { $profile->set( 'asn_db.sources',   ['noreply@example.com'] ); } 'checks type of asn_db.sources';
    dies_ok { $profile->set( 'logfilter',        [] ); } 'checks type of logfilter';
    dies_ok { $profile->set( 'test_levels',      [] ); } 'checks type of test_levels';
    dies_ok { $profile->set( 'test_cases',       {} ); } 'checks type of test_cases';
    dies_ok { $profile->set( 'cache',            [] ); } 'checks type of cache';
};

subtest 'set() accepts sentinel values' => sub {
    my $profile = Zonemaster::Engine::Profile->new;

    $profile->set( 'resolver.source4', '' );
    is $profile->get( 'resolver.source4' ), '', 'resolver.source4 was updated';

    $profile->set( 'resolver.source6', '' );
    is $profile->get( 'resolver.source6' ), '', 'resolver.source6 was updated';
};

subtest 'set() uses standard truthiness rules for boolean properties' => sub {
    my $profile = Zonemaster::Engine::Profile->new;

    subtest 'values considered false' => sub {
        $profile->set( 'no_network', 0 );
        ok !$profile->get( 'no_network' ), 'the number 0';

        $profile->set( 'no_network', "" );
        ok !$profile->get( 'no_network' ), 'the empty string';

        $profile->set( 'no_network', "0" );
        ok !$profile->get( 'no_network' ), 'the string that contains a single 0 digit';
    };

    subtest 'values considered true' => sub {
        $profile->set( 'no_network', 1 );
        ok $profile->get( 'no_network' ), 'any non-0 number';

        $profile->set( 'no_network', " " );
        ok $profile->get( 'no_network' ), 'the string with a space in it';

        $profile->set( 'no_network', "00" );
        ok $profile->get( 'no_network' ), 'two or more 0 characters in a string';

        $profile->set( 'no_network', "0\n" );
        ok $profile->get( 'no_network' ), 'a 0 followed by a newline';

        $profile->set( 'no_network', "true" );
        ok $profile->get( 'no_network' ), 'the string "true"';

        $profile->set( 'no_network', "false" );
        ok $profile->get( 'no_network' ), 'yes, even the string "false"';
    };
};

subtest 'merge() with a profile with all properties unset' => sub {
    my $profile1 = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );
    my $profile2 = Zonemaster::Engine::Profile->new;

    $profile1->merge( $profile2 );

    is $profile1->get( 'resolver.defaults.usevc' ),    1,            'keeps value of resolver.defaults.usevc';
    is $profile1->get( 'resolver.defaults.recurse' ),  1,            'keeps value of resolver.defaults.recurse';
    is $profile1->get( 'resolver.defaults.igntc' ),    0,            'keeps value of resolver.defaults.igntc';
    is $profile1->get( 'resolver.defaults.fallback' ), 1,            'keeps value of resolver.defaults.fallback';
    is $profile1->get( 'net.ipv4' ),                   1,            'keeps value of net.ipv4';
    is $profile1->get( 'net.ipv6' ),                   0,            'keeps value of net.ipv6';
    is $profile1->get( 'no_network' ),                 1,            'keeps value of no_network';
    is $profile1->get( 'resolver.defaults.retry' ),    123,          'keeps value of resolver.defaults.retry';
    is $profile1->get( 'resolver.defaults.retrans' ),  234,          'keeps value of resolver.defaults.retrans';
    is $profile1->get( 'resolver.source4' ),           '192.0.2.53', 'keeps value of resolver.source4';
    is $profile1->get( 'resolver.source6' ),           '2001:db8::42', 'keeps value of resolver.source6';
    eq_or_diff $profile1->get( 'asn_db.style' ), 'cymru', 'keeps value of asn_db.style';
    eq_or_diff $profile1->get( 'asn_db.sources' ), { cymru => ['asn1.example.com', 'asn2.example.com'] }, 'keeps value of asn_db.sources';
    eq_or_diff $profile1->get( 'logfilter' ), { Zone => { TAG => [ { when => { bananas => 0 }, set => 'WARNING' } ] } },
      'keeps value of logfilter';
    eq_or_diff $profile1->get( 'test_levels' ), { Zone => { TAG => 'INFO' } }, 'keeps value of test_levels';
    eq_or_diff $profile1->get( 'test_cases' ), ['Zone01'], 'keeps value of test_cases';
    eq_or_diff $profile1->get( 'cache' ), { redis => { server => '127.0.0.1:6379', expire => 3600 } }, 'keeps value of cache';
};

subtest 'merge() with a profile with all properties set' => sub {
    my $profile1 = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );
    my $profile2 = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_2 );

    $profile1->merge( $profile2 );

    is $profile1->get( 'resolver.defaults.usevc' ),    0,               'updates resolver.defaults.usevc';
    is $profile1->get( 'resolver.defaults.recurse' ),  0,               'updates resolver.defaults.recurse';
    is $profile1->get( 'resolver.defaults.igntc' ),    1,               'updates resolver.defaults.igntc';
    is $profile1->get( 'resolver.defaults.fallback' ), 0,               'updates resolver.defaults.fallback';
    is $profile1->get( 'net.ipv4' ),                   0,               'updates net.ipv4';
    is $profile1->get( 'net.ipv6' ),                   1,               'updates net.ipv6';
    is $profile1->get( 'no_network' ),                 0,               'updates no_network';
    is $profile1->get( 'resolver.defaults.retry' ),    99,              'updates resolver.defaults.retry';
    is $profile1->get( 'resolver.defaults.retrans' ),  88,              'updates resolver.defaults.retrans';
    is $profile1->get( 'resolver.source4' ),           '198.51.100.53', 'updates resolver.source4';
    is $profile1->get( 'resolver.source6' ),           '2001:db8::cafe', 'updates resolver.source6';
    eq_or_diff $profile1->get( 'asn_db.style' ),       'ripe', 'updates asn_db.style';
    eq_or_diff $profile1->get( 'asn_db.sources' ),     { ripe => ['asn3.example.com', 'asn4.example.com'] }, 'updates asn_db.sources';
    eq_or_diff $profile1->get( 'logfilter' ),
      { Nameserver => { OTHER_TAG => [ { when => { apples => 1 }, set => 'INFO' } ] } }, 'updates logfilter';
    eq_or_diff $profile1->get( 'test_levels' ), { Nameserver => { OTHER_TAG => 'ERROR' } }, 'updates test_levels';
    eq_or_diff $profile1->get( 'test_cases' ), ['Zone02'], 'updates test_cases';
    eq_or_diff $profile1->get( 'cache' ), { redis => { server => '127.0.0.2:6379', expire => 7200 } }, 'updates cache';
};

subtest 'merge() does not update the other profile' => sub {
    my $profile1 = Zonemaster::Engine::Profile->from_json( $EXAMPLE_PROFILE_1 );
    my $profile2 = Zonemaster::Engine::Profile->new;

    $profile1->merge( $profile2 );

    is $profile2->get( 'resolver.defaults.usevc' ),    undef, 'resolver.defaults.usevc was untouched in other';
    is $profile2->get( 'resolver.defaults.retrans' ),  undef, 'resolver.defaults.retrans was untouched in other';
    is $profile2->get( 'resolver.defaults.recurse' ),  undef, 'resolver.defaults.recurse was untouched in other';
    is $profile2->get( 'resolver.defaults.retry' ),    undef, 'resolver.defaults.retry was untouched in other';
    is $profile2->get( 'resolver.defaults.igntc' ),    undef, 'resolver.defaults.igntc was untouched in other';
    is $profile2->get( 'resolver.defaults.fallback' ), undef, 'resolver.defaults.fallback was untouched in other';
    is $profile2->get( 'resolver.source4' ),           undef, 'resolver.source4 was untouched in other';
    is $profile2->get( 'resolver.source6' ),           undef, 'resolver.source6 was untouched in other';
    is $profile2->get( 'net.ipv4' ),                   undef, 'net.ipv4 was untouched in other';
    is $profile2->get( 'net.ipv6' ),                   undef, 'net.ipv6 was untouched in other';
    is $profile2->get( 'no_network' ),                 undef, 'no_network was untouched in other';
    is $profile2->get( 'asn_db.style' ),               undef, 'asn_db.style was untouched in other';
    is $profile2->get( 'asn_db.sources' ),             undef, 'asn_db.sources was untouched in other';
    is $profile2->get( 'logfilter' ),                  undef, 'logfilter was untouched in other';
    is $profile2->get( 'test_levels' ),                undef, 'test_levels was untouched in other';
    is $profile2->get( 'test_cases' ),                 undef, 'test_cases was untouched in other';
    is $profile2->get( 'cache' ),                      undef, 'cache was untouched in other';
};

subtest 'to_json() serializes each property' => sub {
    subtest 'resolver.defaults.usevc' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'resolver.defaults.usevc', 1 );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"resolver":{"defaults":{"usevc":true}}}' );
    };

    subtest 'resolver.defaults.recurse' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'resolver.defaults.recurse', 1 );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"resolver":{"defaults":{"recurse":true}}}' );
    };

    subtest 'resolver.defaults.igntc' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'resolver.defaults.igntc', 0 );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"resolver":{"defaults":{"igntc":false}}}' );
    };

    subtest 'resolver.defaults.fallback' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'resolver.defaults.fallback', 0 );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"resolver":{"defaults":{"fallback":false}}}' );
    };

    subtest 'net.ipv4' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'net.ipv4', 1 );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"net":{"ipv4":true}}' );
    };

    subtest 'net.ipv6' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'net.ipv6', 0 );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"net":{"ipv6":false}}' );
    };

    subtest 'no_network' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'no_network', 1 );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"no_network":true}' );
    };

    subtest 'resolver.defaults.retry' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'resolver.defaults.retry', 123 );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"resolver":{"defaults":{"retry":123}}}' );
    };

    subtest 'resolver.defaults.retrans' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'resolver.defaults.retrans', 234 );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"resolver":{"defaults":{"retrans":234}}}' );
    };

    subtest 'resolver.source4' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'resolver.source4', '192.0.2.53' );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"resolver":{"source4":"192.0.2.53"}}' );
    };

    subtest 'resolver.source6' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'resolver.source6', '2001:db8::42' );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"resolver":{"source6":"2001:db8::42"}}' );
    };

    subtest 'resolver.source6 sentinel value' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'resolver.source6', '' );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( qq({"resolver":{"source6":""}}) );
    };

    subtest 'asn_db.style' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'asn_db.style', 'cymru' );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"asn_db":{"style": "cymru"}}' );
    };

    subtest 'asn_db.sources' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'asn_db.sources', { cymru => ['asn1.example.com','asn2.example.com'] } );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"asn_db":{"sources": {"cymru": ["asn1.example.com","asn2.example.com"]}}} ' );
    };

    subtest 'test_cases' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'test_cases', ['Zone01'] );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"test_cases":["Zone01"]}' );
    };

    subtest 'test_levels' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'test_levels', { Zone => { TAG => 'INFO' } } );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ), decode_json( '{"test_levels":{"Zone":{"TAG":"INFO"}}}' );
    };

    subtest 'logfilter' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'logfilter', { Zone => { TAG => [ { when => { bananas => 0 }, set => 'WARNING' } ] } } );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ),
          decode_json( '{"logfilter":{"Zone":{"TAG":[{"when":{"bananas":0},"set":"WARNING"}]}}}' );
    };

    subtest 'cache' => sub {
        my $profile = Zonemaster::Engine::Profile->new;
        $profile->set( 'cache', { redis => { server => '127.0.0.1:6379', expire => 3600 } } );

        my $json = $profile->to_json;

        eq_or_diff decode_json( $json ),
          decode_json( '{"cache":{"redis":{"server":"127.0.0.1:6379","expire":3600}}}' );
    };
};

subtest 'effective() is initially equivalent to default()' => sub {
    my $json0 = Zonemaster::Engine::Profile->default->to_json;

    my $json1 = Zonemaster::Engine::Profile->effective->to_json;

    eq_or_diff decode_json( $json1 ), decode_json( $json0 );
};

subtest 'effective() returns the same profile every time' => sub {
    my $profile1 = Zonemaster::Engine::Profile->effective;
    $profile1->set( 'resolver.defaults.retry', 111 );

    my $profile2 = Zonemaster::Engine::Profile->effective;
    $profile2->set( 'resolver.defaults.retry', 222 );

    is $profile1->get( 'resolver.defaults.retry' ), 222;
};

done_testing;
