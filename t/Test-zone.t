use Test::More;
use File::Slurp;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Zone} );
}

my $datafile = q{t/Test-zone.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

my ($json, $profile_test);
$json         = read_file( 't/profiles/Test-zone-all.json' );
$profile_test = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

my %res;
my $zone;

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{Zone}, q{afnic.fr} );
ok( $res{MX_RECORD_EXISTS},            q{Target found to deliver e-mail for the domain name} );
ok( $res{RETRY_MINIMUM_VALUE_LOWER},   q{SOA 'Retry' vakue is too low} );
ok( $res{REFRESH_MINIMUM_VALUE_LOWER}, q{SOA 'Refresh' value is too low} );
ok( $res{MNAME_NO_RESPONSE},           q{SOA 'mname' nameserver does not respond} );
ok( $res{MNAME_IS_NOT_CNAME},          q{SOA 'mname' value refers to a NS which is not an alias} );
ok( $res{MNAME_NOT_IN_GLUE},           q{SOA 'mname' nameserver is not listed in "parent" NS records for tested zone} );
ok( $res{SOA_DEFAULT_TTL_MAXIMUM_VALUE_OK}, q{SOA 'minimum' value is between the recommended ones} );
ok( $res{REFRESH_HIGHER_THAN_RETRY},        q{SOA 'refresh' value is higher than the SOA 'retry' value} );
ok( $res{EXPIRE_MINIMUM_VALUE_OK},
    q{SOA 'expire' value is higher than the minimum recommended value and lower than 'refresh' value} );
ok( $res{MX_RECORD_IS_NOT_CNAME}, q{MX record for the domain is not pointing to a CNAME} );
ok( $res{ONE_SOA} , q{Unique SOA returned} );

$zone = Zonemaster::Engine->zone( q{zone01.zut-root.rd.nic.fr} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone01}, $zone );
ok( $res{MNAME_RECORD_DOES_NOT_EXIST}, q{SOA 'mname' field does not exist} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{Zone}, q{zone07.zut-root.rd.nic.fr} );
ok( $res{SOA_DEFAULT_TTL_MAXIMUM_VALUE_LOWER}, q{SOA 'minimum' value is too low} );

$zone = Zonemaster::Engine->zone( q{zone05.zut-root.rd.nic.fr} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone09}, $zone );
ok( $res{NO_MX_RECORD}, q{No MX records} );

#
# zone08
#
$zone = Zonemaster::Engine->zone( q{zone08-mx-are-cname.zut-root.rd.nic.fr} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone08}, $zone );
ok( $res{MX_RECORD_IS_CNAME}, q{MX records are CNAME} );
ok( !$res{MX_RECORD_IS_NOT_CNAME}, q{MX records are CNAME (only CNAME found)} );

$zone = Zonemaster::Engine->zone( q{zone08-mx-are-not-cname.zut-root.rd.nic.fr} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone08}, $zone );
ok( $res{MX_RECORD_IS_NOT_CNAME}, q{MX records are NOT_CNAME} );
ok( !$res{MX_RECORD_IS_CNAME}, q{MX records are NOT_CNAME (no CNAME found)} );

$zone = Zonemaster::Engine->zone( q{zone08-one-mx-is-cname.zut-root.rd.nic.fr} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone08}, $zone );
ok( $res{MX_RECORD_IS_CNAME}, q{mixed MX records are partially CNAME} );
ok( $res{MX_RECORD_IS_NOT_CNAME}, q{mixed MX records are partially NOT CNAME} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{Zone}, q{zone02.zut-root.rd.nic.fr} );
ok( $res{MNAME_NOT_AUTHORITATIVE},    q{SOA 'mname' nameserver is not authoritative for zone} );
ok( $res{RETRY_MINIMUM_VALUE_OK},     q{SOA 'retry' value is more than the minimum recommended value} );
ok( $res{REFRESH_MINIMUM_VALUE_OK},   q{SOA 'refresh' value is higher than the minimum recommended value} );
ok( $res{EXPIRE_LOWER_THAN_REFRESH},  q{SOA 'expire' value is lower than the SOA 'refresh' value} );
ok( $res{EXPIRE_MINIMUM_VALUE_LOWER}, q{SOA 'expire' value is less than the recommended one} );
ok( $res{SOA_DEFAULT_TTL_MAXIMUM_VALUE_OK}, q{SOA 'minimum' value is between the recommended ones} );

subtest 'user defined SOA values' => sub {
    $zone = Zonemaster::Engine->zone( q{zone02.zut-root.rd.nic.fr} );

    subtest 'SOA retry, refresh, expire' => sub {
        my $new_refresh = 86400;
        my $new_retry   = 7200;
        my $new_expire  = 86400;

        Zonemaster::Engine::Profile->effective->set( q{test_cases_vars.zone02.SOA_REFRESH_MINIMUM_VALUE}, $new_refresh );
        Zonemaster::Engine::Profile->effective->set( q{test_cases_vars.zone04.SOA_RETRY_MINIMUM_VALUE}, $new_retry );
        Zonemaster::Engine::Profile->effective->set( q{test_cases_vars.zone05.SOA_EXPIRE_MINIMUM_VALUE}, $new_expire );

        %res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{Zone}, $zone );
        ok( $res{REFRESH_MINIMUM_VALUE_LOWER}, q{SOA 'refresh' value is lower than the minimum user defined value} );
        ok( $res{RETRY_MINIMUM_VALUE_LOWER}, q{SOA 'retry' value is lower than the minimum user defined value} );
        ok( $res{EXPIRE_MINIMUM_VALUE_LOWER}, q{SOA 'expire' value is lower than the minimum user defined value} );
    };

    subtest 'SOA minimum TTL' => sub {
        my $new_ttl_min = 7200;
        my $new_ttl_max = 3600;

        Zonemaster::Engine::Profile->effective->set( q{test_cases_vars.zone06.SOA_DEFAULT_TTL_MINIMUM_VALUE}, $new_ttl_min );
        %res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone06}, $zone );
        ok( $res{SOA_DEFAULT_TTL_MAXIMUM_VALUE_LOWER}, q{SOA 'minimum' value is too low} );

        Zonemaster::Engine::Profile->effective->set( q{test_cases_vars.zone06.SOA_DEFAULT_TTL_MAXIMUM_VALUE}, $new_ttl_max );
        %res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone06}, $zone );
        ok( $res{SOA_DEFAULT_TTL_MAXIMUM_VALUE_HIGHER}, q{SOA 'minimum' value is too high} );
    };

    # reset the profile
    Zonemaster::Engine::Profile->effective->merge( Zonemaster::Engine::Profile->default );
};


%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{Zone}, q{zone03.zut-root.rd.nic.fr} );
ok( $res{MNAME_IS_CNAME},           q{SOA 'mname' value refers to a NS which is an alias (CNAME)} );
ok( $res{REFRESH_LOWER_THAN_RETRY}, q{SOA 'refresh' value is lower than the SOA 'retry' value} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{Zone}, q{google.tf} );
ok( $res{SOA_DEFAULT_TTL_MAXIMUM_VALUE_HIGHER}, q{SOA 'minimum' value is too high} );
ok( $res{MNAME_IS_AUTHORITATIVE},               q{SOA 'mname' nameserver is authoritative zone} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{Zone}, q{zone04.zut-root.rd.nic.fr} );
ok( $res{MNAME_HAS_NO_ADDRESS}, q{No IP address found for SOA 'mname' nameserver} );

# $zone = Zonemaster::Engine->zone( 'alcatel.se' );
# %res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone07}, $zone );
# ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );

# $zone = Zonemaster::Engine->zone( 'stromstadsoptiska.se' );
# %res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone08}, $zone );
# ok( $res{NO_RESPONSE_MX_QUERY}, q{No response from nameserver(s) on MX queries} );

$zone = Zonemaster::Engine->zone( 'name.doesnotexist' );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone01}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone02}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone03}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone04}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone05}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone06}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone07}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );

Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 1 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );

$zone = Zonemaster::Engine->zone( q{trasigdnssec.se} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Zone}, q{zone01}, $zone );
ok( !$res{MNAME_NO_RESPONSE}, q{SOA 'mname' found with IPv4 only} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
