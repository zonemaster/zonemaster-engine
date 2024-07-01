use v5.16.0;
use warnings;

use Test::More;
use Test::Differences;

BEGIN { 
    use_ok( 'Zonemaster::Engine::Validation' ), qw( validate_ipv4 validate_ipv6 )
}

subtest 'validate_ipv4()' => sub {
    my @ipv4_addresses = ( '127.0.0.1', '1.1.1.1' );
    subtest 'Valid IPv4 addresses' => sub {
        foreach my $ip ( @ipv4_addresses ) {
            my $ip_is_valid = validate_ipv4( $ip );
            eq_or_diff $ip_is_valid, 1, "$ip is a valid IPv4 address";
        }
    };

    my @inv_ipv4_addresses = ( 'fe80::127:0:0:1', 'abcd', '@bcd3', 'a.b.c.d', '', undef );
    subtest 'Invalid IPv4 addresses' => sub {
        foreach my $ip ( @inv_ipv4_addresses ) {
            my $ip_is_valid = validate_ipv4( $ip );
            $ip = 'undef' unless defined($ip);
            eq_or_diff $ip_is_valid, 0, "$ip is an invalid IPv4 address";
        }
    };
};

subtest 'validate_ipv6()' => sub {
    my @ipv6_addresses = ( 'fe80::127:0:0:1', '::1:1:1:1' );
    subtest 'Valid IPv6 addresses' => sub {
        foreach my $ip ( @ipv6_addresses ) {
            my $ip_is_valid = validate_ipv6( $ip );
            eq_or_diff $ip_is_valid, 1, "$ip is a valid IPv6 address";
        }
    };

    my @inv_ipv6_addresses = ( '127.0.0.1', 'wxyz', 'wxyz!', '::w:x:y:z', '', undef );
    subtest 'Invalid IPv6 addresses' => sub {
        foreach my $ip ( @inv_ipv6_addresses ) {
            my $ip_is_valid = validate_ipv6( $ip );
            $ip = 'undef' unless defined($ip);
            eq_or_diff $ip_is_valid, 0, "$ip is an invalid IPv6 address";
        }
    };
};

done_testing;
