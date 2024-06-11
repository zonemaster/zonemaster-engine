use v5.16.0;
use warnings;

use Test::More;
use Test::Differences;

BEGIN { 
    use_ok( 'Zonemaster::Engine::Validation' ), qw( validate_ip_for_version )
}

subtest 'validate_ip_for_version()' => sub {
    my @ipv4_addresses = ( '127.0.0.1', '1.1.1.1' );
    subtest 'Valid IPv4 addresses' => sub {
        foreach my $ip ( @ipv4_addresses ) {
            my $ip_is_valid = validate_ip_for_version( $ip, 4 );
            eq_or_diff $ip_is_valid, 1, "$ip is a valid IPv4 address";
        }
    };

    my @ipv6_addresses = ( 'fe80::127:0:0:1', '::1:1:1:1' );
    subtest 'Valid IPv6 addresses' => sub {
        foreach my $ip ( @ipv6_addresses ) {
            my $ip_is_valid = validate_ip_for_version( $ip, 6 );
            eq_or_diff $ip_is_valid, 1, "$ip is a valid IPv6 address";
        }
    };

    my @inv_ipv4_addresses = ( 'abcd', '@bcd3', 'a.b.c.d', '', undef );
    subtest 'Invalid IPv4 addresses' => sub {
        foreach my $ip ( @inv_ipv4_addresses ) {
            my $ip_is_valid = validate_ip_for_version( $ip, 4 );
            $ip = 'undef' unless defined($ip);
            eq_or_diff $ip_is_valid, 0, "$ip is an invalid IPv4 address";
        }
    };

    my @inv_ipv6_addresses = ( 'wxyz', 'wxyz!', '::w:x:y:z', '', undef );
    subtest 'Invalid IPv6 addresses' => sub {
        foreach my $ip ( @inv_ipv6_addresses ) {
            my $ip_is_valid = validate_ip_for_version( $ip, 6 );
            $ip = 'undef' unless defined($ip);
            eq_or_diff $ip_is_valid, 0, "$ip is an invalid IPv6 address";
        }
    };

    my @ip_versions = ( 4, 6, '4', '6', 04, '06' );
    subtest 'Valid IP versions' => sub {
        foreach my $ipv ( @ip_versions ) {
            my $ip_is_valid;
            $ip_is_valid = validate_ip_for_version( '127.0.0.1', $ipv ) if $ipv == 4;
            $ip_is_valid = validate_ip_for_version( 'fe80::', $ipv ) if $ipv == 6;
            eq_or_diff $ip_is_valid, 1, "$ipv is a valid IP version";
        }
    };

    my @inv_ip_versions = ( 1, -10, '100', 'a', '', undef );
    subtest 'Invalid IP versions' => sub {
        foreach my $ipv ( @inv_ip_versions ) {
            my $ip_is_valid = validate_ip_for_version( '127.0.0.1', $ipv );
            $ipv = 'undef' unless defined($ipv);
            eq_or_diff $ip_is_valid, 0, "$ipv is an invalid IP version";
        }
    };
};

done_testing;
