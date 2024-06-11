package Zonemaster::Engine::Test::Zone;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare( "v1.0.14" );

use Zonemaster::Engine;

use Carp;
use List::MoreUtils qw[uniq none];
use List::Util qw[max];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;
use JSON::PP;
use Mail::SPF::v1::Record;
use Try::Tiny;

use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Constants qw[:soa :ip];
use Zonemaster::Engine::Recursor;
use Zonemaster::Engine::Nameserver;
use Zonemaster::Engine::Test::Address;
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Util;

=head1 NAME

Zonemaster::Engine::Test::Zone - Module implementing tests focused on the DNS zone content, such as SOA and MX records

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Zone->all( $zone );

=head1 METHODS

=over

=item all()

    my @logentry_array = all( $zone );

Runs the default set of tests for that module, i.e. between L<eight and ten tests|/TESTS> depending on the tested zone.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    push @results, $class->zone01( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone01} );
    push @results, $class->zone02( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone02} );
    push @results, $class->zone03( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone03} );
    push @results, $class->zone04( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone04} );
    push @results, $class->zone05( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone05} );
    push @results, $class->zone06( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone06} );
    push @results, $class->zone07( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone07} );
    push @results, $class->zone08( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone08} );

    if ( none { $_->tag eq q{NO_RESPONSE_MX_QUERY} } @results ) {
        push @results, $class->zone09( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone09} );
    }

    if ( none { $_->tag eq q{NO_RESPONSE_SOA_QUERY} } @results ) {
        push @results, $class->zone10( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone10} );
        push @results, $class->zone11( $zone ) if Zonemaster::Engine::Util::should_run_test( q{zone11} );
    }

    return @results;
} ## end sub all

=over

=item metadata()

    my $hash_ref = metadata();

Returns a reference to a hash, the keys of which are the names of all Test Cases in the module, and the corresponding values are references to
an array containing all the message tags that the Test Case can use in L<log entries|Zonemaster::Engine::Logger::Entry>.

=back

=cut

sub metadata {
    my ( $class ) = @_;

    return {
        zone01 => [
            qw(
              Z01_MNAME_HAS_LOCALHOST_ADDR
              Z01_MNAME_IS_DOT
              Z01_MNAME_IS_LOCALHOST
              Z01_MNAME_IS_MASTER
              Z01_MNAME_MISSING_SOA_RECORD
              Z01_MNAME_NO_RESPONSE
              Z01_MNAME_NOT_AUTHORITATIVE
              Z01_MNAME_NOT_IN_NS_LIST
              Z01_MNAME_NOT_MASTER
              Z01_MNAME_NOT_RESOLVE
              Z01_MNAME_UNEXPECTED_RCODE
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        zone02 => [
            qw(
              REFRESH_MINIMUM_VALUE_LOWER
              REFRESH_MINIMUM_VALUE_OK
              NO_RESPONSE_SOA_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        zone03 => [
            qw(
              REFRESH_LOWER_THAN_RETRY
              REFRESH_HIGHER_THAN_RETRY
              NO_RESPONSE_SOA_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        zone04 => [
            qw(
              RETRY_MINIMUM_VALUE_LOWER
              RETRY_MINIMUM_VALUE_OK
              NO_RESPONSE_SOA_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        zone05 => [
            qw(
              EXPIRE_MINIMUM_VALUE_LOWER
              EXPIRE_LOWER_THAN_REFRESH
              EXPIRE_MINIMUM_VALUE_OK
              NO_RESPONSE_SOA_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        zone06 => [
            qw(
              SOA_DEFAULT_TTL_MAXIMUM_VALUE_HIGHER
              SOA_DEFAULT_TTL_MAXIMUM_VALUE_LOWER
              SOA_DEFAULT_TTL_MAXIMUM_VALUE_OK
              NO_RESPONSE_SOA_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        zone07 => [
            qw(
              MNAME_IS_CNAME
              MNAME_IS_NOT_CNAME
              NO_RESPONSE_SOA_QUERY
              MNAME_HAS_NO_ADDRESS
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        zone08 => [
            qw(
              MX_RECORD_IS_CNAME
              MX_RECORD_IS_NOT_CNAME
              NO_RESPONSE_MX_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        zone09 => [
            qw(
              Z09_INCONSISTENT_MX
              Z09_INCONSISTENT_MX_DATA
              Z09_MISSING_MAIL_TARGET
              Z09_MX_DATA
              Z09_MX_FOUND
              Z09_NON_AUTH_MX_RESPONSE
              Z09_NO_MX_FOUND
              Z09_NO_RESPONSE_MX_QUERY
              Z09_NULL_MX_NON_ZERO_PREF
              Z09_NULL_MX_WITH_OTHER_MX
              Z09_ROOT_EMAIL_DOMAIN
              Z09_TLD_EMAIL_DOMAIN
              Z09_UNEXPECTED_RCODE_MX
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        zone10 => [
            qw(
              MULTIPLE_SOA
              NO_RESPONSE
              NO_SOA_IN_RESPONSE
              ONE_SOA
              WRONG_SOA
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        zone11 => [
            qw(
              Z11_INCONSISTENT_SPF_POLICIES
              Z11_DIFFERENT_SPF_POLICIES_FOUND
              Z11_NO_SPF_FOUND
              Z11_SPF1_MULTIPLE_RECORDS
              Z11_SPF1_SYNTAX_ERROR
              Z11_SPF1_SYNTAX_OK
              Z11_UNABLE_TO_CHECK_FOR_SPF
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    ZONE01 => sub {
        __x    # ZONE:ZONE01
          'Fully qualified master nameserver in SOA';
    },
    ZONE02 => sub {
        __x    # ZONE:ZONE02
          'SOA \'refresh\' minimum value';
    },
    ZONE03 => sub {
        __x    # ZONE:ZONE03
          'SOA \'retry\' lower than \'refresh\'';
    },
    ZONE04 => sub {
        __x    # ZONE:ZONE04
          'SOA \'retry\' at least 1 hour';
    },
    ZONE05 => sub {
        __x    # ZONE:ZONE05
          'SOA \'expire\' minimum value';
    },
    ZONE06 => sub {
        __x    # ZONE:ZONE06
          'SOA \'minimum\' maximum value';
    },
    ZONE07 => sub {
        __x    # ZONE:ZONE07
          'SOA master is not an alias';
    },
    ZONE08 => sub {
        __x    # ZONE:ZONE08
          'MX is not an alias';
    },
    ZONE09 => sub {
        __x    # ZONE:ZONE09
          'MX record present';
    },
    ZONE10 => sub {
        __x    # ZONE:ZONE10
          'No multiple SOA records';
    },
    ZONE11 => sub {
        __x    # ZONE:ZONE11
          'SPF policy validation', @_;
    },
    RETRY_MINIMUM_VALUE_LOWER => sub {
        __x    # ZONE:RETRY_MINIMUM_VALUE_LOWER
          'SOA \'retry\' value ({retry}) is less than the recommended one ({required_retry}).', @_;
    },
    RETRY_MINIMUM_VALUE_OK => sub {
        __x    # ZONE:RETRY_MINIMUM_VALUE_OK
          'SOA \'retry\' value ({retry}) is at least equal to the minimum recommended value ({required_retry}).', @_;
    },
    MNAME_IS_CNAME => sub {
        __x    # ZONE:MNAME_IS_CNAME
          'SOA \'mname\' value ({mname}) refers to a NS which is an alias (CNAME).', @_;
    },
    MNAME_IS_NOT_CNAME => sub {
        __x    # ZONE:MNAME_IS_NOT_CNAME
          'SOA \'mname\' value ({mname}) refers to a NS which is not an alias (CNAME).', @_;
    },
    REFRESH_MINIMUM_VALUE_LOWER => sub {
        __x    # ZONE:REFRESH_MINIMUM_VALUE_LOWER
          'SOA \'refresh\' value ({refresh}) is less than the recommended one ({required_refresh}).', @_;
    },
    REFRESH_MINIMUM_VALUE_OK => sub {
        __x    # ZONE:REFRESH_MINIMUM_VALUE_OK
          'SOA \'refresh\' value ({refresh}) is at least equal to the minimum recommended value ({required_refresh}).', @_;
    },
    EXPIRE_LOWER_THAN_REFRESH => sub {
        __x    # ZONE:EXPIRE_LOWER_THAN_REFRESH
          'SOA \'expire\' value ({expire}) is lower than the SOA \'refresh\' value ({refresh}).', @_;
    },
    SOA_DEFAULT_TTL_MAXIMUM_VALUE_HIGHER => sub {
        __x    # ZONE:SOA_DEFAULT_TTL_MAXIMUM_VALUE_HIGHER
          'SOA \'minimum\' value ({minimum}) is higher than the recommended one ({highest_minimum}).', @_;
    },
    SOA_DEFAULT_TTL_MAXIMUM_VALUE_LOWER => sub {
        __x    # ZONE:SOA_DEFAULT_TTL_MAXIMUM_VALUE_LOWER
          'SOA \'minimum\' value ({minimum}) is less than the recommended one ({lowest_minimum}).', @_;
    },
    SOA_DEFAULT_TTL_MAXIMUM_VALUE_OK => sub {
        __x    # ZONE:SOA_DEFAULT_TTL_MAXIMUM_VALUE_OK
          'SOA \'minimum\' value ({minimum}) is between the recommended ones ({lowest_minimum}/{highest_minimum}).', @_;
    },
    EXPIRE_MINIMUM_VALUE_LOWER => sub {
        __x    # ZONE:EXPIRE_MINIMUM_VALUE_LOWER
          'SOA \'expire\' value ({expire}) is less than the recommended one ({required_expire}).', @_;
    },
    REFRESH_LOWER_THAN_RETRY => sub {
        __x    # ZONE:REFRESH_LOWER_THAN_RETRY
          'SOA \'refresh\' value ({refresh}) is lower than the SOA \'retry\' value ({retry}).', @_;
    },
    REFRESH_HIGHER_THAN_RETRY => sub {
        __x    # ZONE:REFRESH_HIGHER_THAN_RETRY
          'SOA \'refresh\' value ({refresh}) is higher than the SOA \'retry\' value ({retry}).', @_;
    },
    MX_RECORD_IS_CNAME => sub {
        __x    # ZONE:MX_RECORD_IS_CNAME
          'MX record for the domain is pointing to a CNAME.', @_;
    },
    MX_RECORD_IS_NOT_CNAME => sub {
        __x    # ZONE:MX_RECORD_IS_NOT_CNAME
          'MX record for the domain is not pointing to a CNAME.', @_;
    },
    MULTIPLE_SOA => sub {
        __x    # ZONE:MULTIPLE_SOA
          'Nameserver {ns} responds with multiple ({count}) SOA records on SOA queries.', @_;
    },
    NO_RESPONSE => sub {
        __x    # ZONE:NO_RESPONSE
          'Nameserver {ns} did not respond.', @_;
    },
    NO_RESPONSE_SOA_QUERY => sub {
        __x    # ZONE:NO_RESPONSE_SOA_QUERY
          'No response from nameserver(s) on SOA queries.';
    },
    NO_RESPONSE_MX_QUERY => sub {
        __x    # ZONE:NO_RESPONSE_MX_QUERY
          'No response from nameserver(s) on MX queries.';
    },
    NO_SOA_IN_RESPONSE => sub {
        __x    # ZONE:NO_SOA_IN_RESPONSE
          'Response from nameserver {ns} on SOA queries does not contain SOA record.', @_;
    },
    MNAME_HAS_NO_ADDRESS => sub {
        __x    # ZONE:MNAME_HAS_NO_ADDRESS
          'No IP address found for SOA \'mname\' nameserver ({mname}).', @_;
    },
    ONE_SOA => sub {
        __x    # ZONE:ONE_SOA
          'A unique SOA record is returned by all nameservers of the zone.', @_;
    },
    EXPIRE_MINIMUM_VALUE_OK => sub {
        __x    # ZONE:EXPIRE_MINIMUM_VALUE_OK
          'SOA \'expire\' value ({expire}) is higher than the minimum recommended value ({required_expire}) '
          . 'and not lower than the \'refresh\' value ({refresh}).',
          @_;
    },
    IPV4_DISABLED => sub {
        __x    # ZONE:IPV4_DISABLED
          'IPv4 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IPV6_DISABLED => sub {
        __x    # ZONE:IPV6_DISABLED
          'IPv6 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    TEST_CASE_END => sub {
        __x    # ZONE:TEST_CASE_END
          'TEST_CASE_END {testcase}.', @_;
    },
    TEST_CASE_START => sub {
        __x    # ZONE:TEST_CASE_START
          'TEST_CASE_START {testcase}.', @_;
    },
    WRONG_SOA => sub {
        __x    # ZONE:WRONG_SOA
          'Nameserver {ns} responds with a wrong owner name ({owner} instead of {name}) on SOA queries.', @_;
    },
    Z01_MNAME_HAS_LOCALHOST_ADDR => sub {
        __x    # ZONE:Z01_MNAME_HAS_LOCALHOST_ADDR
          'SOA MNAME name server "{nsname}" resolves to a localhost IP address ({ns_ip}).', @_;
    },
    Z01_MNAME_IS_DOT => sub {
        __x    # ZONE:Z01_MNAME_IS_DOT
          'SOA MNAME is specified as "." which usually means "no server". Fetched from name servers "{ns_ip_list}".', @_;
    },
    Z01_MNAME_IS_LOCALHOST => sub {
        __x    # ZONE:Z01_MNAME_IS_LOCALHOST
          'SOA MNAME name server is "localhost", which is invalid. Fetched from name servers "{ns_ip_list}".', @_;
    },
    Z01_MNAME_IS_MASTER => sub {
        __x    # ZONE:Z01_MNAME_IS_MASTER
          'SOA MNAME name server(s) "{ns_list}" appears to be master.', @_;
    },
    Z01_MNAME_MISSING_SOA_RECORD => sub {
        __x    # ZONE:Z01_MNAME_MISSING_SOA_RECORD
          'SOA MNAME name server "{ns}" responds to an SOA query with no SOA records in the answer section.', @_;
    },
    Z01_MNAME_NO_RESPONSE => sub {
        __x    # ZONE:Z01_MNAME_NO_RESPONSE
          'SOA MNAME name server "{ns}" does not respond to an SOA query.', @_;
    },
    Z01_MNAME_NOT_AUTHORITATIVE => sub {
        __x    # ZONE:Z01_MNAME_NOT_AUTHORITATIVE
          'SOA MNAME name server "{ns}" is not authoritative for the zone.', @_;
    },
    Z01_MNAME_NOT_IN_NS_LIST => sub {
        __x    # ZONE:Z01_MNAME_NOT_IN_NS_LIST
          'SOA MNAME name server "{nsname}" is not listed as NS record for the zone.', @_;
    },
    Z01_MNAME_NOT_MASTER => sub {
        __x    # ZONE:Z01_MNAME_NOT_MASTER
          'SOA MNAME name server(s) "{ns_list}" do not have the highest SOA SERIAL (expected "{soaserial}" but got "{soaserial_list}")', @_;
    },
    Z01_MNAME_NOT_RESOLVE => sub {
        __x    # ZONE:Z01_MNAME_NOT_RESOLVE
          'SOA MNAME name server "{nsname}" cannot be resolved into an IP address.', @_;
    },
    Z01_MNAME_UNEXPECTED_RCODE => sub {
        __x    # ZONE:Z01_MNAME_UNEXPECTED_RCODE
          'SOA MNAME name server "{ns}" gives unexpected RCODE name ("{rcode}") in response to an SOA query.', @_;
    },
    Z09_INCONSISTENT_MX => sub {
        __x    # ZONE:Z09_INCONSISTENT_MX
          'Some name servers return an MX RRset while others return none.', @_;
    },
    Z09_INCONSISTENT_MX_DATA => sub {
        __x    # ZONE:Z09_INCONSISTENT_MX_DATA
          'The MX RRset data is inconsistent between the name servers.', @_;
    },
    Z09_MISSING_MAIL_TARGET => sub {
        __x    # ZONE:Z09_MISSING_MAIL_TARGET
          'The child zone has no mail target (no MX).', @_;
    },
    Z09_MX_DATA => sub {
        __x    # ZONE:Z09_MX_DATA
          'Mail targets in the MX RRset "{mailtarget_list}" returned from name servers "{ns_ip_list}".', @_;
    },
    Z09_MX_FOUND => sub {
        __x    # ZONE:Z09_MX_FOUND
          'MX RRset was returned by name servers "{ns_ip_list}".', @_;
    },
    Z09_NON_AUTH_MX_RESPONSE => sub {
        __x    # ZONE:Z09_NON_AUTH_MX_RESPONSE
          'Non-authoritative response on MX query from name servers "{ns_ip_list}".', @_;
    },
    Z09_NO_MX_FOUND => sub {
        __x    # ZONE:Z09_NO_MX_FOUND
          'No MX RRset was returned by name servers "{ns_ip_list}".', @_;
    },
    Z09_NO_RESPONSE_MX_QUERY => sub {
        __x    # ZONE:Z09_NO_RESPONSE_MX_QUERY
          'No response on MX query from name servers "{ns_ip_list}".', @_;
    },
    Z09_NULL_MX_NON_ZERO_PREF => sub {
        __x    # ZONE:Z09_NULL_MX_NON_ZERO_PREF
          'The zone has a Null MX with non-zero preference.', @_;
    },
    Z09_NULL_MX_WITH_OTHER_MX => sub {
        __x    # ZONE:Z09_NULL_MX_WITH_OTHER_MX
          'The zone has a Null MX mixed with other MX records.', @_;
    },
    Z09_ROOT_EMAIL_DOMAIN => sub {
        __x    # ZONE:Z09_ROOT_EMAIL_DOMAIN
          'Root zone with an unexpected MX RRset (non-Null MX).', @_;
    },
    Z09_TLD_EMAIL_DOMAIN => sub {
        __x    # ZONE:Z09_TLD_EMAIL_DOMAIN
          'The zone is a TLD and has an unexpected MX RRset (non-Null MX).', @_;
    },
    Z09_UNEXPECTED_RCODE_MX => sub {
        __x    # ZONE:Z09_UNEXPECTED_RCODE_MX
          'Unexpected RCODE value ({rcode}) on the MX query from name servers "{ns_ip_list}".', @_;
    },
    Z11_INCONSISTENT_SPF_POLICIES => sub {
        __x    # ZONE:Z11_INCONSISTENT_SPF_POLICIES
          'One or more name servers do not publish the same SPF policy as the others.';
    },
    Z11_DIFFERENT_SPF_POLICIES_FOUND => sub {
        __x    # ZONE:Z11_DIFFERENT_SPF_POLICIES_FOUND
          'The following name servers returned the same SPF version 1 policy, but other name servers returned a different policy. Name servers: {ns_ip_list}.', @_;
    },
    Z11_NO_SPF_FOUND => sub {
        __x    # ZONE:Z11_NO_SPF_FOUND
          'No SPF policy was found for {domain}.', @_;
    },
    Z11_SPF1_MULTIPLE_RECORDS => sub {
        __x    # ZONE:Z11_SPF1_MULTIPLE_RECORDS
          'The following name servers returned more than one SPF version 1 policy. Name servers: {ns_ip_list}.', @_;
    },
    Z11_SPF1_SYNTAX_ERROR => sub {
        __x    # ZONE:Z11_SPF1_SYNTAX_ERROR
          'The SPF policy of {domain} has a syntax error. Policy retrieved from the following nameservers: {ns_ip_list}.', @_;
    },
    Z11_SPF1_SYNTAX_OK => sub {
        __x    # ZONE:Z11_SPF1_SYNTAX_OK
          'The SPF policy of {domain} has correct syntax.', @_;
    },
    Z11_UNABLE_TO_CHECK_FOR_SPF => sub {
        __x    # ZONE:Z11_UNABLE_TO_CHECK_FOR_SPF
          'None of the zone’s name servers responded with an authoritative response to queries for SPF policies.';
    },
);

=over

=item tag_descriptions()

    my $hash_ref = tag_descriptions();

Used by the L<built-in translation system|Zonemaster::Engine::Translator>.

Returns a reference to a hash, the keys of which are the message tags and the corresponding values are strings (message IDs).

=back

=cut

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

=over

=item version()

    my $version_string = version();

Returns a string containing the version of the current module.

=back

=cut

sub version {
    return "$Zonemaster::Engine::Test::Zone::VERSION";
}

=head1 INTERNAL METHODS

=over

=item _emit_log()

    my $log_entry = _emit_log( $message_tag_string, $hash_ref );

Adds a message to the L<logger|Zonemaster::Engine::Logger> for this module.
See L<Zonemaster::Engine::Logger::Entry/add($tag, $argref, $module, $testcase)> for more details.

Takes a string (message tag) and a reference to a hash (arguments).

Returns a L<Zonemaster::Engine::Logger::Entry> object.

=back

=cut

sub _emit_log { my ( $tag, $argref ) = @_; return Zonemaster::Engine->logger->add( $tag, $argref, 'Zone' ); }

=over

=item _ip_disabled_message()

    my $bool = _ip_disabled_message( $logentry_array_ref, $ns, @query_type_string );

Checks if the IP version of a given name server is allowed to be queried. If not, it adds a logging message and returns true. Else, it returns false.

Takes a reference to an array of L<Zonemaster::Engine::Logger::Entry> objects, a L<Zonemaster::Engine::Nameserver> object and an array of strings (query type).

Returns a boolean.

=back

=cut

sub _ip_disabled_message {
    my ( $results_array, $ns, @rrtypes ) = @_;

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
        push @$results_array, map {
          _emit_log(
            IPV6_DISABLED => {
                ns     => $ns->string,
                rrtype => $_
            }
          )
        } @rrtypes;
        return 1;
    }

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
        push @$results_array, map {
          _emit_log(
            IPV4_DISABLED => {
                ns     => $ns->string,
                rrtype => $_,
            }
          )
        } @rrtypes;
        return 1;
    }
    return 0;
}

=over

=item _retrieve_record_from_zone()

    my $packet = _retrieve_record_from_zone( $logentry_array_ref, $zone, $name, $query_type_string );

Retrieves resource records of given type for the given name from the response of the first authoritative server of the given zone that has at least one.
Used as an helper function for Test Cases L<Zone02|/zone02()> to L<Zone07|/zone07()>.

Takes a reference to an array of L<Zonemaster::Engine::Logger::Entry> objects, a L<Zonemaster::Engine::Zone> object, a L<Zonemaster::Engine::DNSName> object and a string (query type).

Returns a L<Zonemaster::Engine::Packet> object, or C<undef>.

=back

=cut

sub _retrieve_record_from_zone {
    my ( $results_array, $zone, $name, $type ) = @_;

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method5( $zone ) } ) {

        if ( _ip_disabled_message( $results_array, $ns, $type ) ) {
            next;
        }

        my $p = $ns->query( $name, $type );

        if ( defined $p and scalar $p->get_records( $type, q{answer} ) > 0 ) {
            return $p if $p->aa;
        }
    }

    return;
}

=over

=item _spf_syntax_ok()

    _spf_syntax_ok( $spf_string );

Attempts to run L<Mail::SPF::v1::Record/new_from_string($text, %options)> on the provided string.

Takes a string (SPF text).

=back

=cut

sub _spf_syntax_ok {
    my $spf = shift;

    try {
        Mail::SPF::v1::Record->new_from_string($spf);
    }
}

=head1 TESTS

=over

=item zone01()

    my @logentry_array = zone01( $zone );

Runs the L<Zone01 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Zone-TP/zone01.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub zone01 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Zone01';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my %mname_ns;
    my @serial_ns;
    my %mname_not_master;
    my @mname_master;
    my @mname_localhost;
    my @mname_dot;

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) } ){
        if ( _ip_disabled_message( \@results, $ns, q{SOA} ) ){
            next;
        }

        my $p = $ns->query( $zone->name, q{SOA} );

        if ( not $p or $p->rcode ne q{NOERROR} or not $p->aa or not $p->get_records_for_name( q{SOA}, $zone->name ) ){
            next;
        }

        foreach my $soa_rr ( $p->get_records_for_name( q{SOA}, $zone->name ) ){
            my $soa_mname = lc($soa_rr->mname);
            $soa_mname =~ s/[.]\z//smx;

            if ( $soa_mname eq 'localhost' ){
                push @mname_localhost, $ns->address->short;
            }
            elsif ( not $soa_mname ){
                push @mname_dot, $ns->address->short;
            }
            else{
                $mname_ns{$soa_mname} = undef;
            }

            push @serial_ns, $soa_rr->serial;
        }
    }

    if ( scalar @mname_localhost ){
        push @results, _emit_log( Z01_MNAME_IS_LOCALHOST => { ns_ip_list => join( q{;}, @mname_localhost ) } );
    }

    if ( scalar @mname_dot ){
        push @results, _emit_log( Z01_MNAME_IS_DOT => { ns_ip_list => join( q{;}, @mname_dot ) } );
    }

    my $found_ip = 0;
    my $found_serial = 0;

    foreach my $mname ( keys %mname_ns ){
        if ( none { $_ eq $mname } @{ Zonemaster::Engine::TestMethods->method3( $zone ) } ){
            push @results, _emit_log( Z01_MNAME_NOT_IN_NS_LIST => { nsname => $mname } );
        }

        foreach my $ip ( Zonemaster::Engine::Recursor->get_addresses_for( $mname ) ){
            $found_ip++;
            $mname_ns{$mname}{$ip->short} = undef;
        }

        if ( $found_ip ){
            foreach my $ip ( keys %{ $mname_ns{$mname} } ){
                if ( $ip eq '127.0.0.1' or $ip eq '::1' ){
                    push @results, _emit_log( Z01_MNAME_HAS_LOCALHOST_ADDR => { nsname => $mname, ns_ip => $ip } );
                }
                else{
                    my $ns = Zonemaster::Engine::Nameserver->new( { name => $mname, address => $ip } );

                    if ( _ip_disabled_message( \@results, $ns, q{SOA} ) ){
                       next;
                    }

                    my $p = $ns->query( $zone->name, q{SOA} );

                    if ( $p ){
                        if ( $p->rcode eq q{NOERROR} and $p->get_records_for_name( q{SOA}, $zone->name, q{answer} ) ){
                            if ( not $p->aa ){
                                push @results, _emit_log( Z01_MNAME_NOT_AUTHORITATIVE => { ns => $ns->string } );
                            }
                            else {
                                $found_serial++;
                                my ( $rr ) = $p->get_records_for_name( q{SOA}, $zone->name, q{answer} );
                                $mname_ns{$mname}{$ip} = $rr->serial;
                            }
                        }
                        elsif ( $p->rcode ne q{NOERROR} ){
                            push @results, _emit_log( Z01_MNAME_UNEXPECTED_RCODE => { ns => $ns->string, rcode => $p->rcode } );
                        }
                        elsif ( not $p->get_records_for_name( q{SOA}, $zone->name, q{answer} ) ){
                            push @results, _emit_log( Z01_MNAME_MISSING_SOA_RECORD => { ns => $ns->string } );
                        }
                    }
                    else {
                        push @results, _emit_log( Z01_MNAME_NO_RESPONSE => { ns => $ns->string } );
                    }
                }
            }
        }
        else{
            push @results, _emit_log( Z01_MNAME_NOT_RESOLVE => { nsname => $mname } );
        }
    }

    if ( $found_serial ){
        foreach my $mname ( keys %mname_ns ){
            MNAME_IP: foreach my $mname_ip ( keys %{ $mname_ns{$mname} } ){
                my $mname_serial = $mname_ns{$mname}{$mname_ip};

                if ( not defined($mname_serial) ){
                    next;
                }

                foreach my $serial ( uniq @serial_ns ){
                    if ( Zonemaster::Engine::Util::serial_gt( $serial, $mname_serial ) ){
                        $mname_not_master{$mname}{$mname_ip} = $mname_serial;
                        next MNAME_IP;
                    }
                }

                push @mname_master, $mname . '/' . $mname_ip ;
            }
        }

        if ( %mname_not_master ){
            push @results,
                _emit_log(
                    Z01_MNAME_NOT_MASTER => {
                        ns_list => join( q{;}, sort map
                                        {
                                            my $mname = $_;
                                            map { "$mname/$_" } keys %{ $mname_not_master{$_} }
                                        }
                                        keys %mname_not_master
                                   ),
                        soaserial => max( uniq map { values %{ $mname_not_master{$_} } } keys %mname_not_master ),
                        soaserial_list => join( q{;}, uniq @serial_ns )
                    }
                );
        }

        if ( @mname_master ){
            push @results,
                _emit_log(
                    Z01_MNAME_IS_MASTER => {
                        ns_list  => join( q{;}, sort @mname_master )
                    }
                );
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) )
} ## end sub zone01

=over

=item zone02()

    my @logentry_array = zone02( $zone );

Runs the L<Zone02 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Zone-TP/zone02.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub zone02 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Zone02';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $p = _retrieve_record_from_zone( \@results, $zone, $zone->name, q{SOA} );

    my $soa_refresh_minimum_value = Zonemaster::Engine::Profile->effective->get( q{test_cases_vars.zone02.SOA_REFRESH_MINIMUM_VALUE} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_refresh = $soa->refresh;
        if ( $soa_refresh < $soa_refresh_minimum_value ) {
            push @results,
              _emit_log(
                REFRESH_MINIMUM_VALUE_LOWER => {
                    refresh          => $soa_refresh,
                    required_refresh => $soa_refresh_minimum_value,
                }
              );
        }
        else {
            push @results,
              _emit_log(
                REFRESH_MINIMUM_VALUE_OK => {
                    refresh          => $soa_refresh,
                    required_refresh => $soa_refresh_minimum_value,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, _emit_log( NO_RESPONSE_SOA_QUERY => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) )
} ## end sub zone02

=over

=item zone03()

    my @logentry_array = zone03( $zone );

Runs the L<Zone03 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Zone-TP/zone03.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub zone03 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Zone03';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $p = _retrieve_record_from_zone( \@results, $zone, $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_retry   = $soa->retry;
        my $soa_refresh = $soa->refresh;
        if ( $soa_retry >= $soa_refresh ) {
            push @results,
              _emit_log(
                REFRESH_LOWER_THAN_RETRY => {
                    retry   => $soa_retry,
                    refresh => $soa_refresh,
                }
              );
        }
        else {
            push @results,
              _emit_log(
                REFRESH_HIGHER_THAN_RETRY => {
                    retry   => $soa_retry,
                    refresh => $soa_refresh,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, _emit_log( NO_RESPONSE_SOA_QUERY => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) )
} ## end sub zone03

=over

=item zone04()

    my @logentry_array = zone04( $zone );

Runs the L<Zone04 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Zone-TP/zone04.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub zone04 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Zone04';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $p = _retrieve_record_from_zone( \@results, $zone, $zone->name, q{SOA} );

    my $soa_retry_minimum_value = Zonemaster::Engine::Profile->effective->get( q{test_cases_vars.zone04.SOA_RETRY_MINIMUM_VALUE} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_retry = $soa->retry;
        if ( $soa_retry < $soa_retry_minimum_value ) {
            push @results,
              _emit_log(
                RETRY_MINIMUM_VALUE_LOWER => {
                    retry          => $soa_retry,
                    required_retry => $soa_retry_minimum_value,
                }
              );
        }
        else {
            push @results,
              _emit_log(
                RETRY_MINIMUM_VALUE_OK => {
                    retry          => $soa_retry,
                    required_retry => $soa_retry_minimum_value,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, _emit_log( NO_RESPONSE_SOA_QUERY => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) )
} ## end sub zone04

=over

=item zone05()

    my @logentry_array = zone05( $zone );

Runs the L<Zone05 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Zone-TP/zone05.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub zone05 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Zone05';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $p = _retrieve_record_from_zone( \@results, $zone, $zone->name, q{SOA} );

    my $soa_expire_minimum_value = Zonemaster::Engine::Profile->effective->get( q{test_cases_vars.zone05.SOA_EXPIRE_MINIMUM_VALUE} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_expire  = $soa->expire;
        my $soa_refresh = $soa->refresh;
        if ( $soa_expire < $soa_expire_minimum_value ) {
            push @results,
              _emit_log(
                EXPIRE_MINIMUM_VALUE_LOWER => {
                    expire          => $soa_expire,
                    required_expire => $soa_expire_minimum_value,
                }
              );
        }
        if ( $soa_expire < $soa_refresh ) {
            push @results,
              _emit_log(
                EXPIRE_LOWER_THAN_REFRESH => {
                    expire  => $soa_expire,
                    refresh => $soa_refresh,
                }
              );
        }
        if ( not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
            push @results,
              _emit_log(
                EXPIRE_MINIMUM_VALUE_OK => {
                    expire          => $soa_expire,
                    refresh         => $soa_refresh,
                    required_expire => $soa_expire_minimum_value,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, _emit_log( NO_RESPONSE_SOA_QUERY => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) )
} ## end sub zone05

=over

=item zone06()

    my @logentry_array = zone06( $zone );

Runs the L<Zone06 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Zone-TP/zone06.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub zone06 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Zone06';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $p = _retrieve_record_from_zone( \@results, $zone, $zone->name, q{SOA} );

    my $soa_default_ttl_maximum_value = Zonemaster::Engine::Profile->effective->get( q{test_cases_vars.zone06.SOA_DEFAULT_TTL_MAXIMUM_VALUE} );
    my $soa_default_ttl_minimum_value = Zonemaster::Engine::Profile->effective->get( q{test_cases_vars.zone06.SOA_DEFAULT_TTL_MINIMUM_VALUE} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_minimum = $soa->minimum;
        if ( $soa_minimum > $soa_default_ttl_maximum_value ) {
            push @results,
              _emit_log(
                SOA_DEFAULT_TTL_MAXIMUM_VALUE_HIGHER => {
                    minimum         => $soa_minimum,
                    highest_minimum => $soa_default_ttl_maximum_value,
                }
              );
        }
        elsif ( $soa_minimum < $soa_default_ttl_minimum_value ) {
            push @results,
              _emit_log(
                SOA_DEFAULT_TTL_MAXIMUM_VALUE_LOWER => {
                    minimum        => $soa_minimum,
                    lowest_minimum => $soa_default_ttl_minimum_value,
                }
              );
        }
        else {
            push @results,
              _emit_log(
                SOA_DEFAULT_TTL_MAXIMUM_VALUE_OK => {
                    minimum         => $soa_minimum,
                    highest_minimum => $soa_default_ttl_maximum_value,
                    lowest_minimum  => $soa_default_ttl_minimum_value,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, _emit_log( NO_RESPONSE_SOA_QUERY => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) )
} ## end sub zone06

=over

=item zone07()

    my @logentry_array = zone07( $zone );

Runs the L<Zone07 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Zone-TP/zone07.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub zone07 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Zone07';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $p = _retrieve_record_from_zone( \@results, $zone, $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $soa_mname = $soa->mname;
        $soa_mname =~ s/[.]\z//smx;
        my $addresses_nb = 0;
        foreach my $address_type ( q{A}, q{AAAA} ) {
            my $p_mname = Zonemaster::Engine::Recursor->recurse( $soa_mname, $address_type );
            if ( $p_mname ) {
                if ( $p_mname->has_rrs_of_type_for_name( $address_type, $soa_mname ) ) {
                    $addresses_nb++;
                }
                if ( $p_mname->has_rrs_of_type_for_name( q{CNAME}, $soa_mname ) ) {
                    push @results,
                      _emit_log(
                        MNAME_IS_CNAME => {
                            mname => $soa_mname,
                        }
                      );
                }
                else {
                    push @results,
                      _emit_log(
                        MNAME_IS_NOT_CNAME => {
                            mname => $soa_mname,
                        }
                      );
                }
            } ## end if ( $p_mname )
        } ## end foreach my $address_type ( ...)
        if ( not $addresses_nb ) {
            push @results,
              _emit_log(
                MNAME_HAS_NO_ADDRESS => {
                    mname => $soa_mname,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, _emit_log( NO_RESPONSE_SOA_QUERY => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) )
} ## end sub zone07

=over

=item zone08()

    my @logentry_array = zone08( $zone );

Runs the L<Zone08 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Zone-TP/zone08.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub zone08 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Zone08';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $p = $zone->query_auth( $zone->name, q{MX} );
    if ( $p ) {
        my @mx = $p->get_records_for_name( q{MX}, $zone->name );
        for my $mx ( @mx ) {
            my $p2 = $zone->query_auth( $mx->exchange, q{CNAME} );
            if ( $p2 ) {
                if ( $p2->has_rrs_of_type_for_name( q{CNAME}, $mx->exchange ) ) {
                    push @results, _emit_log( MX_RECORD_IS_CNAME => {} );
                }
                else {
                    push @results, _emit_log( MX_RECORD_IS_NOT_CNAME => {} );
                }
            }
        }
    }
    else {
        push @results, _emit_log( NO_RESPONSE_MX_QUERY => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) )
} ## end sub zone08

=over

=item zone09()

    my @logentry_array = zone09( $zone );

Runs the L<Zone09 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Zone-TP/zone09.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub zone09 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Zone09';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my %ip_already_processed;

    my @no_response_mx;
    my %unexpected_rcode_mx;
    my @non_authoritative_mx;
    my @no_mx_set;
    my %mx_set;

    my %all_ns;

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) } ){
        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( _ip_disabled_message( \@results, $ns, qw{SOA MX} ) ) {
            next;
        }

        my $p1 = $ns->query( $zone->name, q{SOA} );

        if ( not $p1 or $p1->rcode ne q{NOERROR} or not $p1->aa or not $p1->has_rrs_of_type_for_name(q{SOA}, $zone->name) ){
            next;
        }

        my $p2 = $ns->query( $zone->name, q{MX}, { fallback => 0, usevc => 0 } );

        if ( $p2 and $p2->tc ){
            $p2 = $ns->query( $zone->name, q{MX}, { fallback => 0, usevc => 1 } );
        }

        if ( not $p2 ){
            push @no_response_mx, $ns->address->short;
        }
        elsif ( $p2->rcode ne q{NOERROR} ){
            push @{ $unexpected_rcode_mx{$p2->rcode} }, $ns->address->short;
        }
        elsif ( not $p2->aa ){
            push @non_authoritative_mx, $ns->address->short;
        }
        elsif ( not scalar grep { $_->owner eq $zone->name } $p2->get_records_for_name(q{MX}, $zone->name, q{answer}) ){
            push @no_mx_set, $ns->address->short;
        }
        else{
            push @{ $mx_set{$ns->address->short} }, $p2->get_records_for_name(q{MX}, $zone->name, q{answer});
        }

        push @{ $all_ns{$ns->name->string} }, $ns->address->short;
    }

    if ( scalar @no_response_mx ){
        push @results, _emit_log( Z09_NO_RESPONSE_MX_QUERY => { ns_ip_list => join( q{;}, sort @no_response_mx ) } );
    }

    if ( scalar %unexpected_rcode_mx ){
        foreach my $rcode ( keys %unexpected_rcode_mx ){
            push @results, _emit_log( Z09_UNEXPECTED_RCODE_MX => {
                rcode => $rcode,
                ns_ip_list => join( q{;}, sort @{ $unexpected_rcode_mx{$rcode} } )
                }
            );
        }
    }

    if ( scalar @non_authoritative_mx ){
        push @results, _emit_log( Z09_NON_AUTH_MX_RESPONSE => { ns_ip_list => join( q{;}, sort @no_response_mx ) } );
    }

    if ( scalar @no_mx_set and scalar %mx_set ){
        push @results, _emit_log( Z09_INCONSISTENT_MX => {} );
        push @results, _emit_log( Z09_NO_MX_FOUND => { ns_ip_list => join( q{;}, sort @no_mx_set ) } );
        push @results, _emit_log( Z09_MX_FOUND => { ns_ip_list => join( q{;}, sort keys %mx_set ) } );
    }

    if ( scalar %mx_set ){
        my $data_json;
        my $json = JSON::PP->new->canonical->pretty;
        my $first = 1;

        foreach my $ns ( keys %mx_set ){
            if ( $first ){
                my @data = map { lc $_->string } sort @{ $mx_set{$ns} };
                $data_json = $json->encode( \@data );
                $first = 0;
            }
            else{
                my @next_data = map { lc $_->string } sort @{ $mx_set{$ns} };
                if ( $json->encode( \@next_data ) ne $data_json ){
                    push @results, _emit_log( Z09_INCONSISTENT_MX_DATA => {} );

                    foreach my $ns_name ( keys %all_ns ){
                        push @results, _emit_log( Z09_MX_DATA => {
                            mailtarget_list  => join( q{;}, map { $_->exchange } @{ $mx_set{@{$all_ns{$ns_name}}[0]} } ),
                            ns_ip_list => join( q{;}, @{ $all_ns{$ns_name} } )
                            }
                        )
                    }

                    last;
                }
            }
        }

        unless ( grep{$_->tag eq 'Z09_INCONSISTENT_MX_DATA'} @results ){
            my $has_null_mx = 0;
            my ( $ns ) = keys %mx_set;

            foreach my $rr ( @{$mx_set{$ns}} ){
                if ( $rr->exchange eq '.' ){
                    if ( scalar @{$mx_set{$ns}} > 1 ){
                        push @results, _emit_log( Z09_NULL_MX_WITH_OTHER_MX => {} ) unless grep{$_->tag eq 'Z09_NULL_MX_WITH_OTHER_MX'} @results;
                    }

                    if ( $rr->preference > 0 ){
                        push @results, _emit_log( Z09_NULL_MX_NON_ZERO_PREF => {} ) unless grep{$_->tag eq 'Z09_NULL_MX_NON_ZERO_PREF'} @results;
                    }

                    $has_null_mx = 1;
                }
            }

            if ( not $has_null_mx ){
                if ( $zone->name->string eq '.' ){
                    push @results, _emit_log( Z09_ROOT_EMAIL_DOMAIN => {} );
                }

                elsif ( $zone->name->next_higher eq '.' ){
                    push @results, _emit_log( Z09_TLD_EMAIL_DOMAIN => {} );
                }

                else {
                    push @results, _emit_log( Z09_MX_DATA => {
                        ns_ip_list => join( q{;}, keys %mx_set ),
                        mailtarget_list => join( q{;}, map { map { $_->exchange } @$_ } $mx_set{ (keys %mx_set)[0] } )
                        }
                    );
                }
            }
        }
    }

    elsif ( scalar @no_mx_set ){
        unless ( $zone->name eq '.' or $zone->name->next_higher eq '.' or $zone->name =~ /\.arpa$/ ){
            push @results, _emit_log( Z09_MISSING_MAIL_TARGET => {} );
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) )
} ## end sub zone09

=over

=item zone10()

    my @logentry_array = zone10( $zone );

Runs the L<Zone10 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Zone-TP/zone10.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub zone10 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Zone10';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my $name = name( $zone );

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) } ) {

        if ( _ip_disabled_message( \@results, $ns, q{SOA} ) ) {
            next;
        }

        my $p = $ns->query( $name, q{SOA} );

        if ( not $p ) {
            push @results, _emit_log( NO_RESPONSE => { ns => $ns->string } );
            next;
        }
        else {
            my @soa = $p->get_records( q{SOA}, q{answer} );
            if ( scalar @soa ) {
                if ( scalar @soa > 1 ) {
                    push @results,
                      _emit_log(
                        MULTIPLE_SOA => {
                            ns    => $ns->string,
                            count => scalar @soa,
                        }
                      );
                }
                elsif ( lc( $soa[0]->owner ) ne lc( $name->fqdn ) ) {
                    push @results,
                      _emit_log(
                        WRONG_SOA => {
                            ns    => $ns->string,
                            owner => lc( $soa[0]->owner ),
                            name  => lc( $name->fqdn ),
                        }
                      );
                }
            } ## end if ( scalar @soa )
            else {
                push @results, _emit_log( NO_SOA_IN_RESPONSE => { ns => $ns->string } );
            }
        } ## end else [ if ( not $p ) ]
    } ## end foreach my $ns ( @{ Zonemaster::Engine::TestMethods...})
    if ( not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results, _emit_log( ONE_SOA => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) )
} ## end sub zone10

=over

=item zone11()

    my @logentry_array = zone11( $zone );

Runs the L<Zone11 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Zone-TP/zone11.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub zone11 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Zone11';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    # This hash maps nameserver IP addresses to arrayrefs of TXT resource
    # record data matching the signature for SPF policies. These arrays
    # usually contain at most one string.
    my %ns_spf = ();

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) } ) {
        if ( _ip_disabled_message( \@results, $ns, q{TXT} ) ) {
            next;
        }

        my $p = $ns->query( $zone->name, q{TXT} );

        if ( $p and $p->rcode eq q{NOERROR} and $p->aa ) {
            my @txt_rrs = $p->get_records_for_name( q{TXT}, $zone->name );
            my @txt_rdata = map { lc $_->txtdata() } @txt_rrs;
            my @spf1_policies = grep /\Av=spf1(?:\Z|\s+)/, @txt_rdata;

            $ns_spf{$ns->address->short} = \@spf1_policies;
        }
    }

    # At this point, the values of %ns_spf contain *lists* of SPF policies.
    # There should be at most one item in each of those lists, but zones may
    # mistakenly publish more than one policy.
    #
    # We can’t use a list of strings directly as a hash key; we need flat
    # strings and a conversion method that can disambiguate between
    # [qw(a b c)] and [qw(ab c)]. The best method is to prefix each string in
    # the list with its length, then concatenate all of these strings
    # together. Hence, [qw(a b c)] becomes "<1>a<1>b<1>c" and [qw(ab c)]
    # becomes "<2>ab<1>c".
    my %spf_ns = ();
    for my $ns ( keys %ns_spf ) {
        my $mangled_spfs = join '', map { sprintf '<%d>%s', length $_, $_ } sort @{$ns_spf{$ns}};
        push @{$spf_ns{$mangled_spfs}}, $ns;
    }

    if ( not scalar %ns_spf ) {
        push @results, _emit_log( Z11_UNABLE_TO_CHECK_FOR_SPF => {} );
    }
    elsif ( List::MoreUtils::all { $_ eq '' } keys %spf_ns ) {
        push @results, _emit_log( Z11_NO_SPF_FOUND => { domain => $zone->name->string } );
    }
    elsif ( scalar keys %spf_ns > 1 ) {
        push @results, _emit_log( Z11_INCONSISTENT_SPF_POLICIES => {} );

        for my $ns ( values %spf_ns ) {
            push @results, _emit_log( Z11_DIFFERENT_SPF_POLICIES_FOUND => { ns_ip_list => join( q{;}, sort @$ns ) } );
        }
    }
    elsif ( my @bad_ns = grep { scalar @{$ns_spf{$_}} > 1 } keys %ns_spf ) {
        push @results, _emit_log( Z11_SPF1_MULTIPLE_RECORDS => { ns_ip_list => join( q{;}, sort @bad_ns ) } );
    }
    else {
        my $spf_text = (values %ns_spf)[0][0];

        if ( _spf_syntax_ok($spf_text) ) {
            push @results, _emit_log( Z11_SPF1_SYNTAX_OK => { domain => $zone->name->string } );
        }
        else {
            push @results, _emit_log( Z11_SPF1_SYNTAX_ERROR => {
                domain => $zone->name->string,
                ns_ip_list => join( q{;}, sort (keys %ns_spf) )
              }
            );
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) )
} ## end sub zone11

1;
