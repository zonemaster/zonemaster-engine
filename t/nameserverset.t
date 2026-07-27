use v5.24.0;
use warnings;

use List::Util;

use Test::More;

use Zonemaster::Engine;
use Zonemaster::Engine::DNSName;
use Zonemaster::Engine::Nameserver;

BEGIN { use_ok 'Zonemaster::Engine::NameserverSet'; }

subtest 'creating empty set' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new();

    isa_ok( $set, 'Zonemaster::Engine::NameserverSet' );
    ok( $set->is_empty(), '$set->is_empty() is true' );
    is( scalar $set->items, 0, 'set is empty' );
};

subtest 'is_empty() method' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new();

    ok( $set->is_empty(), 'is_empty() is true on empty set' );

    $set->push( 'not.empty.anymore.test' );

    ok( ! $set->is_empty(), 'is_empty() is false if set is nonempty' );
};

subtest 'pushing nothing is a non-operation' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new();

    $set->push();
    ok( $set->is_empty(), 'set is still empty' );
};

subtest 'push() methods returns self' => sub {
    isa_ok(
        Zonemaster::Engine::NameserverSet->new()->push(),
        'Zonemaster::Engine::NameserverSet',
        'push() method returns the object'
    );
};

subtest 'pushing a DNS name onto an empty set' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new();
    ok( $set->is_empty(), 'set is still empty' );

    $set->push( Zonemaster::Engine::DNSName->new( 'one.test' ) );

    ok( ! $set->is_empty(), 'set is no longer empty' );
    is( scalar $set->items, 1, 'set contains one item' );
    is( 'one.test', ($set->items)[0] );
};

subtest 'pushing a nameserver onto an empty set' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new();

    $set->push(
        Zonemaster::Engine::Nameserver->new( {
            name => 'ns1.one.test',
            address => '2001:db8::'
        } )
    );

    is( scalar $set->items, 1, 'set contains one item' );
    is( 'ns1.one.test/2001:db8::', ($set->items)[0] );
};

subtest 'pushing a plain string onto an empty set' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new();

    $set->push('plain.string.test');
    is( scalar $set->items, 1, 'set contains one item' );
    is( 'plain.string.test', ($set->items)[0] );
    isa_ok( ($set->items)[0], 'Zonemaster::Engine::DNSName' );
};

subtest 'pushing an empty string is a non-operation' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new();

    is( scalar $set->push('')->items(), 0, 'set does not grow' );
};

subtest 'pushing undef is a non-operation' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new();

    is( scalar $set->push(undef)->items(), 0, 'set does not grow' );
};

subtest 'pushing two equivalent DNS names' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new();
    $set->push( Zonemaster::Engine::DNSName->new( 'one.test' ) );
    my $old_size = scalar $set->items;

    $set->push( Zonemaster::Engine::DNSName->new( 'ONE.TEST' ) );

    is( scalar $set->items, $old_size, 'set still contains one item' );
    is( 'one.test', ($set->items)[0] );
};

subtest 'pushing a mix of equivalent DNS names and strings' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new();

    $set->push(
        'HeLLo.TeST',
        Zonemaster::Engine::DNSName->new('HELLO.TEST'),
        Zonemaster::Engine::DNSName->new('HEllo.TEst'),
        'hello.test'
    );

    is( scalar $set->items, 1, 'set contains exactly one item' );
    is( 'hello.test', ($set->items)[0] );
};

subtest 'pushing two distinct DNS names' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new();
    $set->push( Zonemaster::Engine::DNSName->new( 'one.test' ) );

    my $old_size = scalar $set->items;
    $set->push( Zonemaster::Engine::DNSName->new( 'two.test' ) );
    is( scalar $set->items, $old_size + 1, 'set size grew by one' );

    my @set_items = $set->items;
    ok( grep { $_ eq 'one.test' } @set_items );
    ok( grep { $_ eq 'two.test' } @set_items );
};

subtest 'new() can also create non-empty sets from a list' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new(
        map { Zonemaster::Engine::DNSName->new( $_ ) }
        qw( one.test two.test three.test )
    );
    is( scalar $set->items, 3, 'set contains three items' );
};

subtest 'pushing two names and a nameserver' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new( 'one.test' ),
        Zonemaster::Engine::DNSName->new( 'two.test' )
    );
    my $old_size = scalar $set->items;

    $set->push( Zonemaster::Engine::Nameserver->new({
        name => 'three.test',
        address => '2001:db8::3:1'
    } ) );

    is( scalar $set->items, $old_size + 1, 'set grows by one' );
};

subtest 'set only holds unique nameservers' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new( 'one.test' ),
        Zonemaster::Engine::DNSName->new( 'two.test' ),
        Zonemaster::Engine::Nameserver->new( {
            name => 'three.test',
            address => '2001:db8::3:1'
        } )
    );
    my $old_size = scalar $set->items;

    $set->push( Zonemaster::Engine::Nameserver->new({
        name => 'THREE.TEST.',
        address => '2001:db8::3:1'
    } ) );

    is( scalar $set->items, $old_size, 'set does not grow' );
};

subtest 'overwriting a DNS name with a name server' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new( 'one.test' ),
        Zonemaster::Engine::DNSName->new( 'two.test' ),
        Zonemaster::Engine::Nameserver->new( {
            name => 'three.test',
            address => '2001:db8::3:1'
        } )
    );
    my $old_size = scalar $set->items;

    ok( grep( { $_ eq 'one.test' } $set->items ), 'one.test is in the set' );

    $set->push( Zonemaster::Engine::Nameserver->new({
        name => 'OnE.TeSt',
        address => '2001:db8::1:1'
    } ) );

    my @set_items = $set->items;
    is( scalar @set_items, $old_size, 'set size did not grow' );
    ok( !grep( { $_ eq 'one.test' } @set_items ), 'one.test is no longer in the set' );
    ok( grep( { $_ eq 'one.test/2001:db8::1:1' } @set_items ), 'the new name server is in the set' );
};

subtest 'pushing a DNS name when a name server already exists' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new( 'one.test' ),
        Zonemaster::Engine::DNSName->new( 'two.test' ),
        Zonemaster::Engine::Nameserver->new( {
            name => 'three.test',
            address => '2001:db8::3:1'
        } )
    );
    my $old_size = scalar $set->items;

    $set->push(
        Zonemaster::Engine::DNSName->new( 'THREE.TEST' ),
        'THREE.TEST'
    );

    my @set_items = $set->items;
    is( scalar $set->items, $old_size, 'set size did not grow' );
    ok( ! grep( { lc $_ eq 'three.test' } @set_items ), 'the name is not in the set' )
        or diag join(", ", @set_items);
    ok( grep( { $_ eq 'three.test/2001:db8::3:1' } @set_items ), 'the nameserver is still there' )
        or diag join(", ", @set_items);
};

subtest 'adding a name server with same name but different IP' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::Nameserver->new( {
            name => 'one.test',
            address => '2001:db8::1:1'
        } ),
        Zonemaster::Engine::DNSName->new( 'two.test' ),
        Zonemaster::Engine::Nameserver->new( {
            name => 'three.test',
            address => '2001:db8::3:1'
        } )
    );
    my $old_size = scalar $set->items;

    $set->push( Zonemaster::Engine::Nameserver->new({
        name => 'one.test',
        address => '2001:db8::2:1'
    } ) );

    my @set_items = $set->items;
    is( scalar @set_items, $old_size + 1, 'set size increased by one' );
    ok( grep( { $_ eq 'one.test/2001:db8::1:1' } @set_items ), 'the old name server still is in the set' );
    ok( grep( { $_ eq 'one.test/2001:db8::2:1' } @set_items ), 'the new name server is in the set' );
};

subtest 'sorted_items() method' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new('b.test'),
        Zonemaster::Engine::Nameserver->new({
            name => 'a.test',
            address => '::1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'a.test',
            address => '127.0.0.1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '2001:db8:bc::'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '2001:db8:bbbb::1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '203.0.113.234'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '192.0.2.2'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '192.0.2.101'
        }),
    );

    my @ordered_items = map { "$_" } $set->sorted_items();

    my @expected = qw(
                         a.test/127.0.0.1
                         a.test/::1
                         b.test
                         d.test/192.0.2.2
                         d.test/192.0.2.101
                         d.test/203.0.113.234
                         d.test/2001:db8:bc::
                         d.test/2001:db8:bbbb::1
                 );

    is_deeply( \@ordered_items, \@expected, 'ordering items works as it should' )
        or diag("Here’s how \$set->sorted_items() sorted the items:\n"
                . join "\n", map { " * $_" } @ordered_items );
};

subtest 'names() method' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new('B.TEST'),
        Zonemaster::Engine::Nameserver->new({
            name => 'a.test',
            address => '::1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'A.TEST',
            address => '127.0.0.1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '2001:db8:bc::'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'D.TEST',
            address => '2001:db8:bbbb::1'
        })
    );

    my @names = $set->names();

    is( scalar @names, 3, 'correct list size' );
    ok( grep({ $_ eq 'a.test' } @names), 'a.test is in the list' );
    ok( grep({ $_ eq 'b.test' } @names), 'b.test is in the list' );
    ok( grep({ $_ eq 'd.test' } @names), 'd.test is in the list' );
    ok( List::Util::all(sub { $_->isa('Zonemaster::Engine::DNSName') }, @names),
        'names() returns DNSName objects' );
};

subtest 'get() method' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new('B.TEST'),
        Zonemaster::Engine::Nameserver->new({
            name => 'a.test',
            address => '::1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'A.TEST',
            address => '127.0.0.1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '2001:db8:bc::'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'D.TEST',
            address => '2001:db8:bbbb::1'
        })
    );

    my @a = $set->get('A.TeSt');
    is( scalar @a, 2, 'get a.test gives correct number of items' );
    ok( grep({ $_ eq 'a.test/::1' } @a) );
    ok( grep({ $_ eq 'a.test/127.0.0.1' } @a) );

    my @b = $set->get('b.test');
    is( scalar @b, 1, 'get b.test gives correct amount of items' );
    ok( $b[0] eq 'b.test' );

    is( $set->get('b.test'), 'b.test' );

    is( scalar do { my @c = $set->get('c.test'); @c }, 0,
        'get c.test in list context return empty array');
    is( $set->get('c.test'), undef,
        'get c.test in scalar context returns undef');

    my @d = $set->get( Zonemaster::Engine::DNSName->new('d.test') );
    is( scalar @d, 2,
        'passing a DNSName to get() instead of a string also works');
};

subtest 'get_ips() method' => sub {
    my $set = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new('B.TEST'),
        Zonemaster::Engine::Nameserver->new({
            name => 'a.test',
            address => '::1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'A.TEST',
            address => '127.0.0.1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '2001:db8:bc::'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'D.TEST',
            address => '2001:db8:bbbb::1'
        })
    );

    my @a = $set->get_ips('A.TeSt');
    is( scalar @a, 2, 'get_ips a.test gives correct number of items' );
    ok( grep({ $_ eq 'a.test/::1' } @a) );
    ok( grep({ $_ eq 'a.test/127.0.0.1' } @a) );

    my @b = $set->get_ips('b.test');
    is( scalar @b, 0, 'get_ips b.test gives correct amount of items' );

    is( scalar do { my @c = $set->get_ips('c.test'); @c }, 0,
        'get_ips c.test in list context return empty array');
    is( $set->get_ips('c.test'), undef,
        'get_ips c.test in scalar context returns undef');

    my @d = $set->get_ips( Zonemaster::Engine::DNSName->new('d.test') );
    is( scalar @d, 2,
        'passing a DNSName to get_ips() instead of a string also works');
};

subtest 'difference() method on two empty sets' => sub {
    my $set_a = Zonemaster::Engine::NameserverSet->new();
    my $set_b = Zonemaster::Engine::NameserverSet->new();

    my ( $lhs, $rhs ) = $set_a->difference( $set_b );
    is( scalar $lhs->items(), 0, 'set a minus set b is empty' );
    is( scalar $rhs->items(), 0, 'set b minus set a is empty' );
};

subtest 'difference() method on non-empty sets' => sub {
    my $set_a = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new('B.TEST'),
        Zonemaster::Engine::DNSName->new('e.TEST'),
        Zonemaster::Engine::Nameserver->new({
            name => 'a.test',
            address => '::1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'A.TEST',
            address => '127.0.0.1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '2001:db8:bc::'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'D.TEST',
            address => '2001:db8:bbbb::1'
        })
    );

    my $set_b = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new('b.test'),
        Zonemaster::Engine::DNSName->new('c.test'),
        Zonemaster::Engine::Nameserver->new({
            name => 'a.test',
            address => '127.0.0.1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '2001:db8:bc::'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '2001:db8:bbbb::1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '203.0.113.234'
        }),
    );

    my ( $only_in_a, $only_in_b ) = $set_a->difference( $set_b );

    isa_ok( $only_in_a, 'Zonemaster::Engine::NameserverSet' );
    isa_ok( $only_in_b, 'Zonemaster::Engine::NameserverSet' );

    is_deeply(
        [ map { "$_" } $only_in_a->sorted_items() ],
        [ qw( a.test/::1 e.TEST ) ]
    );
    is_deeply(
        [ map { "$_" } $only_in_b->sorted_items() ],
        [ qw( c.test d.test/203.0.113.234 ) ]
    );
};

subtest 'equals() on two empty sets' => sub {
    my $set_a = Zonemaster::Engine::NameserverSet->new();
    my $set_b = Zonemaster::Engine::NameserverSet->new();

    ok( $set_a->equals( $set_b ), 'two empty sets are equal to each other' );
};

subtest 'equals() on two nonempty sets' => sub {
    my $set_a = Zonemaster::Engine::NameserverSet->new();
    my $set_b = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new( 'hello.test' )
    );

    ok( ! $set_a->equals( $set_b ), 'both sets are not equal' );
};

subtest 'equals() on two different sets' => sub {
    my $set_a = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new( 'hello.test' )
    );

    my $set_b = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new( 'hello2.test' )
    );

    ok( ! $set_a->equals( $set_b ), 'equals() returns false on sets containing different items' );
};

subtest 'equals() on sub- and supersets' => sub {
    my $set_a = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new( 'hello.test' )
    );

    my $set_b = Zonemaster::Engine::NameserverSet->new(
        Zonemaster::Engine::DNSName->new( 'hello.test' ),
        Zonemaster::Engine::DNSName->new( 'hello2.test' )
    );

    ok( ! $set_a->equals( $set_b ),
        'one set is not equal to a strict superset of oneself' );
    ok( ! $set_b->equals( $set_a ),
        'one set is not equal to a strict subset of oneself' );
};

subtest 'equals() on equal sets' => sub {
    my @input = (
        Zonemaster::Engine::DNSName->new('b.test'),
        Zonemaster::Engine::DNSName->new('c.test'),
        Zonemaster::Engine::Nameserver->new({
            name => 'a.test',
            address => '127.0.0.1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '2001:db8:bc::'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '2001:db8:bbbb::1'
        }),
        Zonemaster::Engine::Nameserver->new({
            name => 'd.test',
            address => '203.0.113.234'
        }),
    );

    my $set_a = Zonemaster::Engine::NameserverSet->new( @input );
    my $set_b = Zonemaster::Engine::NameserverSet->new( @input );

    ok( $set_a->equals( $set_b ),
        'two non-empty sets with same items test equal');
};

done_testing;
