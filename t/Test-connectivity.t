use Test::More;
use File::Slurp;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Connectivity} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $checking_module = q{Connectivity};

my $datafile = q{t/Test-connectivity.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

my ($json, $profile_test);
foreach my $testcase ( qw{connectivity01 connectivity02 connectivity03 connectivity04} ) {
    $json          = read_file( 't/profiles/Test-'.$testcase.'-only.json' );
    $profile_test  = Zonemaster::Engine::Profile->from_json( $json );
    Zonemaster::Engine::Profile->effective->merge( $profile_test );
    my @testcases;
    foreach my $result ( Zonemaster::Engine->test_module( q{connectivity}, q{afnic.fr} ) ) {
        foreach my $trace (@{$result->trace}) {
            push @testcases, grep /Zonemaster::Engine::Test::Connectivity::connectivity/, @$trace;
        }
    }
    @testcases = uniq sort @testcases;
    is( scalar( @testcases ), 1, 'only one test-case ('.$testcase.')' );
    is( $testcases[0], 'Zonemaster::Engine::Test::Connectivity::'.$testcase, 'expected test-case ('.$testcases[0].')' );
}

$json         = read_file( 't/profiles/Test-connectivity-all.json' );
$profile_test = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

my @res;
my %res;
my %should_emit;

my $metadata = Zonemaster::Engine::Test::Connectivity->metadata();
my $test_levels = Zonemaster::Engine::Profile->effective->{profile}->{test_levels}->{CONNECTIVITY};

sub zone_gives {
    my ( $test, $zone, $gives_ref ) = @_;

    Zonemaster::Engine->logger->clear_history();
    my @res = grep { $_->tag !~ /^TEST_CASE_(END|START)$/ } Zonemaster::Engine->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( ( grep { $_->tag eq $gives } @res ), $zone->name->string . " gives $gives" );
    }
    return scalar( @res );
}

sub zone_gives_not {
    my ( $test, $zone, $gives_ref ) = @_;

    Zonemaster::Engine->logger->clear_history();
    my @res = grep { $_->tag !~ /^TEST_CASE_(END|START)$/ } Zonemaster::Engine->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( !( grep { $_->tag eq $gives } @res ), $zone->name->string . " does not give $gives" );
    }
    return scalar( @res );
}

sub check_output_connectivity_testcase {
    my ( $testcase, $res, $should_emit ) = @_;

    return if ( $testcase !~ q/connectivity0[1-4]/ );

    for my $key ( @{ $metadata->{$testcase} } ) {
        next if ( $test_levels->{$key} =~ q/DEBUG/ );
        if ( $should_emit->{$key} ) {
            ok( $res->{$key}, "Should emit $key" );
        } else {
            ok( !$res->{$key}, "Should NOT emit $key" );
        }
    }
}

sub check_output_connectivity_all {
    my ( $res, $should_emit ) = @_;

    check_output_connectivity_testcase( 'connectivity01', $res, $should_emit );
    check_output_connectivity_testcase( 'connectivity02', $res, $should_emit );
    check_output_connectivity_testcase( 'connectivity03', $res, $should_emit );
    check_output_connectivity_testcase( 'connectivity04', $res, $should_emit );
}

subtest 'All good' => sub {
    %res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{connectivity}, q{afnic.fr} );
    ok( !$res{MODULE_ERROR}, q{Test module completes normally} );
    %should_emit = (
        IPV4_DIFFERENT_ASN => 1,
        IPV6_DIFFERENT_ASN => 1,
        CN04_IPV4_DIFFERENT_PREFIX => 1,
        CN04_IPV6_DIFFERENT_PREFIX => 1
    );
    check_output_connectivity_all( \%res, \%should_emit );
};

my $zone;

################
# Connectivity03
################
$zone = Zonemaster::Engine->zone( '001.tf' );
zone_gives('connectivity03', $zone, [qw{IPV4_ONE_ASN IPV6_ONE_ASN}] );
zone_gives_not( 'connectivity03', $zone, [qw{EMPTY_ASN_SET ERROR_ASN_DATABASE IPV4_DIFFERENT_ASN IPV4_SAME_ASN IPV6_DIFFERENT_ASN IPV6_SAME_ASN}] );

$zone = Zonemaster::Engine->zone( 'zut-root.rd.nic.fr' );
zone_gives('connectivity03', $zone, [qw{IPV4_ONE_ASN}] );
zone_gives_not( 'connectivity03', $zone, [qw{EMPTY_ASN_SET ERROR_ASN_DATABASE IPV4_DIFFERENT_ASN IPV4_SAME_ASN IPV6_DIFFERENT_ASN IPV6_ONE_ASN IPV6_SAME_ASN}] );

################
# Connectivity04
################
$zone = Zonemaster::Engine->zone( '001.tf' );
zone_gives('connectivity04', $zone, [qw{CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX CN04_IPV6_SAME_PREFIX}] );
zone_gives_not( 'connectivity04', $zone, [qw{CN04_IPV4_SAME_PREFIX CN04_EMPTY_PREFIX_SET CN04_ERROR_PREFIX_DATABASE}] );

$zone = Zonemaster::Engine->zone( 'zut-root.rd.nic.fr' );
zone_gives('connectivity04', $zone, [qw{CN04_IPV4_SAME_PREFIX}] );
zone_gives_not( 'connectivity04', $zone, [qw{CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX CN04_IPV6_SAME_PREFIX CN04_EMPTY_PREFIX_SET CN04_ERROR_PREFIX_DATABASE}] );

################
subtest 'No IPv6 (profile with IPv4 only)' => sub {
    Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 1 );
    Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );

    %res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{connectivity}, q{afnic.fr} );

    subtest 'UDP' => sub {
        %should_emit = (
            CN01_IPV6_DISABLED => 1
        );
        check_output_connectivity_testcase( 'connectivity01', \%res, \%should_emit );
    };

    subtest 'TCP (no messages)' => sub {
        %should_emit = ();
        check_output_connectivity_testcase( 'connectivity02', \%res, \%should_emit );
    };

    Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 1 );
};

subtest 'No IPv4 (profile with IPv6 only)' => sub {
    Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
    Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 1 );

    %res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{connectivity}, q{afnic.fr} );

    subtest 'UDP' => sub {
        %should_emit = (
            CN01_IPV4_DISABLED => 1
        );
        check_output_connectivity_testcase( 'connectivity01', \%res, \%should_emit );
    };

    subtest 'TCP (no messages)' => sub {
        %should_emit = ();
        check_output_connectivity_testcase( 'connectivity02', \%res, \%should_emit );
    };

    Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 1 );
};

subtest 'No network' => sub {
    Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
    Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );

    %res = map{ $_->tag => 1 } Zonemaster::Engine->test_module( q{connectivity}, q{afnic.fr} );
    ok( $res{NO_NETWORK}, 'IPv6 and IPv4 disabled' );

    Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 1 );
    Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 1 );
};

TODO: {
    local $TODO = "Need to find/create zones with that error";

    # connectivity03
    ok( $tag{EMPTY_ASN_SET}, q{EMPTY_ASN_SET} );
    ok( $tag{ERROR_ASN_DATABASE}, q{ERROR_ASN_DATABASE} );
    ok( $tag{IPV4_DIFFERENT_ASN}, q{IPV4_DIFFERENT_ASN} );
    ok( $tag{IPV4_SAME_ASN}, q{IPV4_SAME_ASN} );
    ok( $tag{IPV6_DIFFERENT_ASN}, q{IPV6_DIFFERENT_ASN} );
    ok( $tag{IPV6_SAME_ASN}, q{IPV6_SAME_ASN} );

    # connectivity04
    ok( $tag{CN04_EMPTY_PREFIX_SET}, q{CN04_EMPTY_PREFIX_SET} );
    ok( $tag{CN04_ERROR_PREFIX_DATABASE}, q{CN04_ERROR_PREFIX_DATABASE} );
}

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
