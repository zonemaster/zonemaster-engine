package Zonemaster::Engine::Test::DNSSEC;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare( "v1.1.51" );

###
### This test module implements DNSSEC tests.
###

use Zonemaster::LDNS::RR;

use Zonemaster::Engine;

use Carp;
use List::MoreUtils qw[uniq none];
use List::Util qw[min];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Constants qw[:algo :soa :ip];
use Zonemaster::Engine::Util;
use Zonemaster::Engine::TestMethods;

### Table fetched from IANA on 2017-03-09
Readonly::Hash our %algo_properties => (
    0 => {
        status      => $ALGO_STATUS_NOT_ZONE_SIGN,
        description => q{Delete DS},
        mnemonic    => q{DELETE},
        sig         => 0,
    },
    1 => {
        status      => $ALGO_STATUS_DEPRECATED,
        description => q{RSA/MD5},
        mnemonic    => q{RSAMD5},
        sig         => 0,
    },
    2 => {
        status      => $ALGO_STATUS_NOT_ZONE_SIGN,
        description => q{Diffie-Hellman},
        mnemonic    => q{DH},
        sig         => 0,
    },
    3 => {
        status      => $ALGO_STATUS_DEPRECATED,
        description => q{DSA/SHA1},
        mnemonic    => q{DSA},
        sig         => 1,
    },
    4 => {
        status      => $ALGO_STATUS_RESERVED,
        description => q{Reserved},
    },
    5 => {
        status      => $ALGO_STATUS_NOT_RECOMMENDED,
        description => q{RSA/SHA1},
        mnemonic    => q{RSASHA1},
        sig         => 1,
    },
    6 => {
        status      => $ALGO_STATUS_DEPRECATED,
        description => q{DSA-NSEC3-SHA1},
        mnemonic    => q{DSA-NSEC3-SHA1},
        sig         => 1,
    },
    7 => {
        status      => $ALGO_STATUS_NOT_RECOMMENDED,
        description => q{RSASHA1-NSEC3-SHA1},
        mnemonic    => q{RSASHA1-NSEC3-SHA1},
        sig         => 1,
    },
    8 => {
        status      => $ALGO_STATUS_OTHER,
        description => q{RSA/SHA-256},
        mnemonic    => q{RSASHA256},
        sig         => 1,
    },
    9 => {
        status      => $ALGO_STATUS_RESERVED,
        description => q{Reserved},
    },
    10 => {
        status      => $ALGO_STATUS_NOT_RECOMMENDED,
        description => q{RSA/SHA-512},
        mnemonic    => q{RSASHA512},
        sig         => 1,
    },
    11 => {
        status      => $ALGO_STATUS_RESERVED,
        description => q{Reserved},
    },
    12 => {
        status      => $ALGO_STATUS_DEPRECATED,
        description => q{GOST R 34.10-2001},
        mnemonic    => q{ECC-GOST},
        sig         => 1,
    },
    13 => {
        status      => $ALGO_STATUS_OTHER,
        description => q{ECDSA Curve P-256 with SHA-256},
        mnemonic    => q{ECDSAP256SHA256},
        sig         => 1,
    },
    14 => {
        status      => $ALGO_STATUS_OTHER,
        description => q{ECDSA Curve P-384 with SHA-384},
        mnemonic    => q{ECDSAP384SHA384},
        sig         => 1,
    },
    15 => {
        status      => $ALGO_STATUS_OTHER,
        description => q{Ed25519},
        mnemonic    => q{ED25519},
        sig         => 1,
    },
    16 => {
        status      => $ALGO_STATUS_OTHER,
        description => q{Ed448},
        mnemonic    => q{ED448},
        sig         => 1,
    },
    (
        map { $_ => { status => $ALGO_STATUS_UNASSIGNED, description => q{Unassigned}, } } ( 17 .. 122 )
    ),
    (
        map { $_ => { status => $ALGO_STATUS_RESERVED, description => q{Reserved}, } } ( 123 .. 251 )
    ),
    252 => {
        status      => $ALGO_STATUS_NOT_ZONE_SIGN,
        description => q{Reserved for Indirect Keys},
        mnemonic    => q{INDIRECT},
        sig         => 0,
    },
    253 => {
        status      => $ALGO_STATUS_PRIVATE,
        description => q{private algorithm},
        mnemonic    => q{PRIVATEDNS},
        sig         => 1,
    },
    254 => {
        status      => $ALGO_STATUS_PRIVATE,
        description => q{private algorithm OID},
        mnemonic    => q{PRIVATEOID},
        sig         => 1,
    },
    255 => {
        status      => $ALGO_STATUS_RESERVED,
        description => q{Reserved},
    },
);

Readonly::Hash our %rsa_key_size_details => (
    5 => {
        min_size  => 512,
        max_size  => 4096,
        rec_size  => 2048,
        reference => q{RFC 3110},
    },
    7 => {
        min_size  => 512,
        max_size  => 4096,
        rec_size  => 2048,
        reference => q{RFC 5155},
    },
    8 => {
        min_size  => 512,
        max_size  => 4096,
        rec_size  => 2048,
        reference => q{RFC 5702},
    },
    10 => {
        min_size  => 1024,
        max_size  => 4096,
        rec_size  => 2048,
        reference => q{RFC 5702},
    },
);

Readonly::Hash our %digest_algorithms => (
    0 => q{Reserved},
    1 => q{SHA-1},
    2 => q{SHA-256},
    3 => q{GOST R 34.11-94},
    4 => q{SHA-384},
    (
        map { $_ => q{Unassigned} } ( 5 .. 255 )
    ),
);

###
### Entry points
###

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    if ( Zonemaster::Engine::Util::should_run_test( q{dnssec07} ) ) {
        push @results, $class->dnssec07( $zone );
    }

    if ( Zonemaster::Engine::Util::should_run_test( q{dnssec07} ) and grep { $_->tag eq 'NEITHER_DNSKEY_NOR_DS' } @results ) {
        push @results,
          info(
            NOT_SIGNED => {
                zone => q{} . $zone->name
            }
          );

    } else {

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec01} ) ) {
            push @results, $class->dnssec01( $zone );
        }

        if ( none { $_->tag eq 'NO_RESPONSE_DS' } @results ) {
            if ( Zonemaster::Engine::Util::should_run_test( q{dnssec02} ) ) {
                push @results, $class->dnssec02( $zone );
            }
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec03} ) ) {
            push @results, $class->dnssec03( $zone );
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec04} ) ) {
            push @results, $class->dnssec04( $zone );
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec05} ) ) {
            push @results, $class->dnssec05( $zone );
        }
    
        if ( grep { $_->tag eq q{DNSKEY_BUT_NOT_DS} or $_->tag eq q{DNSKEY_AND_DS} } @results ) {
            if ( Zonemaster::Engine::Util::should_run_test( q{dnssec06} ) ) {
                push @results, $class->dnssec06( $zone );
            }
        }
        else {
            push @results,
              info( ADDITIONAL_DNSKEY_SKIPPED => {} );
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec08} ) ) {
            push @results, $class->dnssec08( $zone );
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec09} ) ) {
            push @results, $class->dnssec09( $zone );
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec10} ) ) {
            push @results, $class->dnssec10( $zone );
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec11} ) ) {
            push @results, $class->dnssec11( $zone );
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec13} ) ) {
            push @results, $class->dnssec13( $zone );
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec14} ) ) {
            push @results, $class->dnssec14( $zone );
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec15} ) ) {
            push @results, $class->dnssec15( $zone );
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec16} ) ) {
            push @results, $class->dnssec16( $zone );
        }

        if ( Zonemaster::Engine::Util::should_run_test( q{dnssec17} ) ) {
            push @results, $class->dnssec17( $zone );
        }

    }

    push @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } );

    return @results;
} ## end sub all

###
### Metadata Exposure
###

sub metadata {
    my ( $class ) = @_;

    return {
        dnssec01 => [
            qw(
              DS_ALGORITHM_DEPRECATED
              DS_ALGORITHM_MISSING
              DS_ALGORITHM_NOT_DS
              DS_ALGORITHM_OK
              DS_ALGORITHM_RESERVED
              DS_ALGO_SHA1_DEPRECATED
              NO_RESPONSE_DS
              UNEXPECTED_RESPONSE_DS
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        dnssec02 => [
            qw(
              BROKEN_DS
              BROKEN_RRSIG
              DNSKEY_KSK_NOT_SEP
              DNSKEY_NOT_ZONE_SIGN
              DS_MATCHES
              NO_MATCHING_DNSKEY
              NO_MATCHING_RRSIG
              NO_RESPONSE
              NO_RESPONSE_DNSKEY
              NO_RRSIG_DNSKEY
              TEST_CASE_END
              TEST_CASE_START
              UNEXPECTED_RESPONSE_DS
              )
        ],
        dnssec03 => [
            qw(
              NO_NSEC3PARAM
              NO_DNSKEY
              MANY_ITERATIONS
              TOO_MANY_ITERATIONS
              ITERATIONS_OK
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        dnssec04 => [
            qw(
              RRSIG_EXPIRATION
              RRSIG_EXPIRED
              REMAINING_SHORT
              REMAINING_LONG
              DURATION_LONG
              DURATION_OK
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        dnssec05 => [
            qw(
              ALGORITHM_DEPRECATED
              ALGORITHM_NOT_RECOMMENDED
              ALGORITHM_NOT_ZONE_SIGN
              ALGORITHM_OK
              ALGORITHM_PRIVATE
              ALGORITHM_RESERVED
              ALGORITHM_UNASSIGNED
              IPV4_DISABLED
              IPV6_DISABLED
              KEY_DETAILS
              NO_RESPONSE
              NO_RESPONSE_DNSKEY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        dnssec06 => [
            qw(
              EXTRA_PROCESSING_OK
              EXTRA_PROCESSING_BROKEN
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        dnssec07 => [
            qw(
              ADDITIONAL_DNSKEY_SKIPPED
              DNSKEY_BUT_NOT_DS
              DNSKEY_AND_DS
              NEITHER_DNSKEY_NOR_DS
              DS_BUT_NOT_DNSKEY
              NOT_SIGNED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        dnssec08 => [
            qw(
              DS08_ALGO_NOT_SUPPORTED_BY_ZM
              DS08_DNSKEY_RRSIG_EXPIRED
              DS08_DNSKEY_RRSIG_NOT_YET_VALID
              DS08_MISSING_RRSIG_IN_RESPONSE
              DS08_NO_MATCHING_DNSKEY
              DS08_RRSIG_NOT_VALID_BY_DNSKEY
              )
        ],
        dnssec09 => [
            qw(
              DS09_ALGO_NOT_SUPPORTED_BY_ZM
              DS09_MISSING_RRSIG_IN_RESPONSE
              DS09_NO_MATCHING_DNSKEY
              DS09_RRSIG_NOT_VALID_BY_DNSKEY
              DS09_SOA_RRSIG_EXPIRED
              DS09_SOA_RRSIG_NOT_YET_VALID
              )
        ],
        dnssec10 => [
            qw(
              BROKEN_DNSSEC
              HAS_NSEC
              HAS_NSEC3
              INCONSISTENT_DNSSEC
              INCONSISTENT_NSEC_NSEC3
              INVALID_RCODE
              MIXED_NSEC_NSEC3
              NO_NSEC_NSEC3
              NO_RESPONSE
              NSEC3_COVERS_NOT
              NSEC3_NOT_SIGNED
              NSEC3_SIG_VERIFY_ERROR
              NSEC_COVERS_NOT
              NSEC_NOT_SIGNED
              NSEC_SIG_VERIFY_ERROR
              TEST_ABORTED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        dnssec11 => [
            qw(
              DS11_INCONSISTENT_DS
              DS11_INCONSISTENT_SIGNED_ZONE
              DS11_UNDETERMINED_DS
              DS11_UNDETERMINED_SIGNED_ZONE
              DS11_PARENT_WITHOUT_DS
              DS11_PARENT_WITH_DS
              DS11_NS_WITH_SIGNED_ZONE
              DS11_NS_WITH_UNSIGNED_ZONE
              DS11_DS_BUT_UNSIGNED_ZONE
              ),
        ],
        dnssec13 => [
            qw(
              DS13_ALGO_NOT_SIGNED_DNSKEY
              DS13_ALGO_NOT_SIGNED_NS
              DS13_ALGO_NOT_SIGNED_SOA
              ),
        ],
        dnssec14 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_DNSKEY
              DNSKEY_SMALLER_THAN_REC
              DNSKEY_TOO_SMALL_FOR_ALGO
              DNSKEY_TOO_LARGE_FOR_ALGO
              IPV4_DISABLED
              IPV6_DISABLED
              KEY_SIZE_OK
              TEST_CASE_END
              TEST_CASE_START
              ),
        ],
        dnssec15 => [
            qw(
              DS15_HAS_CDNSKEY_NO_CDS
              DS15_HAS_CDS_AND_CDNSKEY
              DS15_HAS_CDS_NO_CDNSKEY
              DS15_INCONSISTENT_CDNSKEY
              DS15_INCONSISTENT_CDS
              DS15_MISMATCH_CDS_CDNSKEY
              DS15_NO_CDS_CDNSKEY
              ),
        ],
        dnssec16 => [
            qw(
              DS16_CDS_INVALID_RRSIG
              DS16_CDS_MATCHES_NO_DNSKEY
              DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY
              DS16_CDS_UNSIGNED
              DS16_CDS_WITHOUT_DNSKEY
              DS16_DELETE_CDS
              DS16_DNSKEY_NOT_SIGNED_BY_CDS
              DS16_MIXED_DELETE_CDS
              ),
        ],
        dnssec17 => [
            qw(
              DS17_CDNSKEY_INVALID_RRSIG
              DS17_CDNSKEY_MATCHES_NO_DNSKEY
              DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY
              DS17_CDNSKEY_UNSIGNED
              DS17_CDNSKEY_WITHOUT_DNSKEY
              DS17_DELETE_CDNSKEY
              DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY
              DS17_MIXED_DELETE_CDNSKEY
              ),
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    ADDITIONAL_DNSKEY_SKIPPED => sub {
        __x    # DNSSEC:ADDITIONAL_DNSKEY_SKIPPED
          'No DNSKEYs found. Additional tests skipped.', @_;
    },
    ALGORITHM_DEPRECATED => sub {
        __x    # DNSSEC:ALGORITHM_DEPRECATED
          'The DNSKEY with tag {keytag} uses deprecated algorithm number '
          . '{algo_num} ({algo_descr}).',
          @_;
    },
    ALGORITHM_NOT_RECOMMENDED => sub {
        __x    # DNSSEC:ALGORITHM_NOT_RECOMMENDED
          'The DNSKEY with tag {keytag} uses an algorithm number '
          . '{algo_num} ({algo_descr}) which is not recommended to be used.',
          @_;
    },
    ALGORITHM_NOT_ZONE_SIGN => sub {
        __x    # DNSSEC:ALGORITHM_NOT_ZONE_SIGN
          'The DNSKEY with tag {keytag} uses algorithm number not meant for '
          . 'zone signing, algorithm number {algo_num} ({algo_descr}).',
          @_;
    },
    ALGORITHM_OK => sub {
        __x    # DNSSEC:ALGORITHM_OK
          'The DNSKEY with tag {keytag} uses algorithm number {algo_num} '
          . '({algo_descr}), which is OK.',
          @_;
    },
    ALGORITHM_PRIVATE => sub {
        __x    # DNSSEC:ALGORITHM_PRIVATE
          'The DNSKEY with tag {keytag} uses private algorithm number '
          . '{algo_num} ({algo_descr}).',
          @_;
    },
    ALGORITHM_RESERVED => sub {
        __x    # DNSSEC:ALGORITHM_RESERVED
          'The DNSKEY with tag {keytag} uses reserved algorithm number '
          . '{algo_num} ({algo_descr}).',
          @_;
    },
    ALGORITHM_UNASSIGNED => sub {
        __x    # DNSSEC:ALGORITHM_UNASSIGNED
          'The DNSKEY with tag {keytag} uses unassigned algorithm number '
          . '{algo_num} ({algo_descr}).',
          @_;
    },
    BROKEN_DNSSEC => sub {
        __x    # DNSSEC:BROKEN_DNSSEC
          'All nameservers for zone {domain} responds with neither NSEC nor NSEC3 records when such '
          . 'records are expected.',
          @_;
    },
    BROKEN_DS => sub {
        __x    # DNSSEC:BROKEN_DS
          'DNSKEY record with tag {keytag} returned by nameserver {ns} does not match '
          . 'the algorithm and hash values in a DS record with same tag in parent zone.',
          @_;
    },
    BROKEN_RRSIG => sub {
        __x    # DNSSEC:BROKEN_RRSIG
          'The RRSIG of the DNSKEY RRset created by tag {keytag} returned by nameserver {ns} '
          . 'failed to be verified with error \'{error}\' (a DS record with same tag is present in the '
          . 'parent zone).',
          @_;
    },
    DNSKEY_AND_DS => sub {
        __x    # DNSSEC:DNSKEY_AND_DS
          '{parent} sent a DS record, and {child} a DNSKEY record.', @_;
    },
    DNSKEY_BUT_NOT_DS => sub {
        __x    # DNSSEC:DNSKEY_BUT_NOT_DS
          '{child} sent a DNSKEY record, but {parent} did not send a DS record.', @_;
    },
    DNSKEY_KSK_NOT_SEP => sub {
        __x    # DNSSEC:DNSKEY_KSK_NOT_SEP
          'Flags field of DNSKEY record with tag {keytag} returned by nameserver {ns} '
          . 'has not SEP bit set although DS with same tag is present in parent.',
          @_;
    },
    DNSKEY_NOT_ZONE_SIGN => sub {
        __x    # DNSSEC:DNSKEY_NOT_ZONE_SIGN
          'Flags field of DNSKEY record with tag {keytag} returned by nameserver {ns} '
          . 'has not ZONE bit set although DS with same tag is present in parent.',
          @_;
    },
    DNSKEY_SMALLER_THAN_REC => sub {
        __x    # DNSSEC:DNSKEY_SMALLER_THAN_REC
          'DNSKEY with tag {keytag} and using algorithm {algo_num} '
          . '({algo_descr}) has a size ({keysize}) smaller than the '
          . 'recommended one ({keysizerec}).',
          @_;
    },
    DNSKEY_TOO_SMALL_FOR_ALGO => sub {
        __x    # DNSSEC:DNSKEY_TOO_SMALL_FOR_ALGO
          'DNSKEY with tag {keytag} and using algorithm {algo_num} '
          . '({algo_descr}) has a size ({keysize}) smaller than the minimum '
          . 'one ({keysizemin}).',
          @_;
    },
    DNSKEY_TOO_LARGE_FOR_ALGO => sub {
        __x    # DNSSEC:DNSKEY_TOO_LARGE_FOR_ALGO
          'DNSKEY with tag {keytag} and using algorithm {algo_num} '
          . '({algo_descr}) has a size ({keysize}) larger than the maximum one '
          . '({keysizemax}).',
          @_;
    },
    DS08_ALGO_NOT_SUPPORTED_BY_ZM => sub {
        __x    # DNSSEC:DS08_ALGO_NOT_SUPPORTED_BY_ZM
          'DNSKEY with tag {keytag} uses unsupported algorithm {algo_num} '
          . '({algo_mnemo}) by this installation of Zonemaster. Fetched from '
          . 'the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS08_DNSKEY_RRSIG_EXPIRED => sub {
        __x    # DNSSEC:DS08_DNSKEY_RRSIG_EXPIRED
          'RRSIG with keytag {keytag} and covering type DNSKEY has already expired. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS08_DNSKEY_RRSIG_NOT_YET_VALID => sub {
        __x    # DNSSEC:DS08_DNSKEY_RRSIG_NOT_YET_VALID
          'RRSIG with keytag {keytag} and covering type DNSKEY has inception date in '
          . 'the future. Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS08_MISSING_RRSIG_IN_RESPONSE => sub {
        __x    # DNSSEC:DS08_MISSING_RRSIG_IN_RESPONSE
          'The DNSKEY RRset is not signed, which is against expectation. Fetched '
          . 'from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS08_NO_MATCHING_DNSKEY => sub {
        __x    # DNSSEC:DS08_NO_MATCHING_DNSKEY
          'The DNSKEY RRset is signed with an RRSIG with tag {keytag} which does '
          . 'not match any DNSKEY record. Fetched from the nameservers with IP '
          . 'addresses "{ns_ip_list}".',
          @_;
    },
    DS08_RRSIG_NOT_VALID_BY_DNSKEY => sub {
        __x    # DNSSEC:DS08_RRSIG_NOT_VALID_BY_DNSKEY
          'The DNSKEY RRset is signed with an RRSIG with tag {keytag} which cannot '
          . 'be validated by the matching DNSKEY. Fetched from the nameservers with IP '
          . 'addresses "{ns_ip_list}".',
          @_;
    },
    DS09_ALGO_NOT_SUPPORTED_BY_ZM => sub {
        __x    # DNSSEC:DS09_ALGO_NOT_SUPPORTED_BY_ZM
          'DNSKEY with tag {keytag} uses unsupported algorithm {algo_num} '
          . '({algo_mnemo}) by this installation of Zonemaster. Fetched from '
          . 'the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS09_MISSING_RRSIG_IN_RESPONSE => sub {
        __x    # DNSSEC:DS09_MISSING_RRSIG_IN_RESPONSE
          'The SOA RRset is not signed, which is against expectation. Fetched '
          . 'from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS09_NO_MATCHING_DNSKEY => sub {
        __x    # DNSSEC:DS09_NO_MATCHING_DNSKEY
          'The SOA RRset is signed with an RRSIG with tag {keytag} which does '
          . 'not match any DNSKEY record. Fetched from the nameservers with IP '
          . 'addresses "{ns_ip_list}".',
          @_;
    },
    DS09_RRSIG_NOT_VALID_BY_DNSKEY => sub {
        __x    # DNSSEC:DS09_RRSIG_NOT_VALID_BY_DNSKEY
          'The SOA RRset is signed with an RRSIG with tag {keytag} which cannot '
          . 'be validated by the matching DNSKEY. Fetched from the nameservers with IP '
          . 'addresses "{ns_ip_list}".',
          @_;
    },
    DS09_SOA_RRSIG_EXPIRED => sub {
        __x    # DNSSEC:DS09_SOA_RRSIG_EXPIRED
          'RRSIG with keytag {keytag} and covering type SOA has already expired. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS09_SOA_RRSIG_NOT_YET_VALID => sub {
        __x    # DNSSEC:DS09_SOA_RRSIG_NOT_YET_VALID
          'RRSIG with keytag {keytag} and covering type SOA has inception date in '
          . 'the future. Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS11_INCONSISTENT_DS => sub {
        __x    # DNSSEC:DS11_INCONSISTENT_DS
          'Parent name servers are inconsistent on the existence of DS.',
          @_;
    },
    DS11_INCONSISTENT_SIGNED_ZONE => sub {
        __x    # DNSSEC:DS11_INCONSISTENT_SIGNED_ZONE
          'Name servers for the child zone are inconsistent on whether the '
          . 'zone is signed or not.',
          @_;
    },
    DS11_UNDETERMINED_DS => sub {
        __x    # DNSSEC:DS11_UNDETERMINED_DS
          'It cannot be determined if the parent zone has DS for the child '
          . 'zone or not.',
          @_;
    },
    DS11_UNDETERMINED_SIGNED_ZONE => sub {
        __x    # DNSSEC:DS11_UNDETERMINED_SIGNED_ZONE
          'It cannot be determined if the child zone is signed or not.',
          @_;
    },
    DS11_PARENT_WITHOUT_DS => sub {
        __x    # DNSSEC:DS11_PARENT_WITHOUT_DS
          'No DS record for the child zone found on parent nameservers with IP '
          . 'addresses "{ns_ip_list}".',
          @_;
    },
    DS11_PARENT_WITH_DS => sub {
        __x    # DNSSEC:DS11_PARENT_WITH_DS
          'DS record for the child zone found on parent nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS11_NS_WITH_SIGNED_ZONE => sub {
        __x    # DNSSEC:DS11_NS_WITH_SIGNED_ZONE
          'Signed child zone found on nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS11_NS_WITH_UNSIGNED_ZONE => sub {
        __x    # DNSSEC:DS11_NS_WITH_UNSIGNED_ZONE
          'Unsigned child zone found on nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS11_DS_BUT_UNSIGNED_ZONE => sub {
        __x    # DNSSEC:DS11_DS_BUT_UNSIGNED_ZONE
          'The child zone is unsigned, but the parent zone has DS record.',
          @_;
    },
    DS13_ALGO_NOT_SIGNED_DNSKEY => sub {
        __x    # DNSSEC:DS13_ALGO_NOT_SIGNED_DNSKEY
          'The DNSKEY RRset is not signed by algorithm {algo_num} ({algo_mnemo}) '
          . 'present in the DNSKEY RRset. Fetched from the nameservers with IP '
          . 'addresses "{ns_ip_list}".',
          @_;
    },
    DS13_ALGO_NOT_SIGNED_NS => sub {
        __x    # DNSSEC:DS13_ALGO_NOT_SIGNED_NS
          'The NS RRset is not signed by algorithm {algo_num} ({algo_mnemo}) '
          . 'present in the DNSKEY RRset. Fetched from the nameservers with IP '
          . 'addresses "{ns_ip_list}".',
          @_;
    },
    DS13_ALGO_NOT_SIGNED_SOA => sub {
        __x    # DNSSEC:DS13_ALGO_NOT_SIGNED_SOA
          'The SOA RRset is not signed by algorithm {algo_num} ({algo_mnemo}) '
          . 'present in the DNSKEY RRset. Fetched from the nameservers with IP '
          . 'addresses "{ns_ip_list}".',
          @_;
    },
    DS15_HAS_CDNSKEY_NO_CDS => sub {
        __x    # DS15_HAS_CDNSKEY_NO_CDS
          'CDNSKEY RRset is found on nameservers that resolve to IP addresses '
          . '({ns_ip_list}), but no CDS RRset.',
          @_;
    },
    DS15_HAS_CDS_AND_CDNSKEY => sub {
        __x    # DS15_HAS_CDS_AND_CDNSKEY
          'CDNSKEY and CDS RRsets are found on nameservers that resolve to IP addresses '
          . '({ns_ip_list}).',
          @_;
    },
    DS15_HAS_CDS_NO_CDNSKEY => sub {
        __x    # DS15_HAS_CDS_NO_CDNSKEY
          'CDS RRset is found on nameservers that resolve to IP addresses '
          . '({ns_ip_list}), but no CDNSKEY RRset.',
          @_;
    },
    DS15_INCONSISTENT_CDNSKEY => sub {
        __x    # DS15_INCONSISTENT_CDNSKEY
          'All servers do not have the same CDNSKEY RRset.', @_;
    },
    DS15_INCONSISTENT_CDS => sub {
        __x    # DS15_INCONSISTENT_CDS
          'All servers do not have the same CDS RRset.', @_;
    },
    DS15_MISMATCH_CDS_CDNSKEY => sub {
        __x    # DS15_MISMATCH_CDS_CDNSKEY
          'Both CDS and CDNSKEY RRsets are found on nameservers that resolve to IP '
          . 'addresses ({ns_ip_list}) but they do not match.',
          @_;
    },
    DS15_NO_CDS_CDNSKEY => sub {
        __x    # DS15_NO_CDS_CDNSKEY
          'No CDS or CDNSKEY RRsets are found on any name server.', @_;
    },
    DS16_CDS_INVALID_RRSIG => sub {
        __x    # DS16_CDS_INVALID_RRSIG
          'The CDS RRset is signed with an RRSIG with tag {keytag}, but the RRSIG does '
          . 'not match the DNSKEY with the same key tag. Fetched from the nameservers '
          . 'with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS16_CDS_MATCHES_NO_DNSKEY => sub {
        __x    # DS16_CDS_MATCHES_NO_DNSKEY
          'The CDS record with tag {keytag} does not match any DNSKEY record. Fetched '
          . 'from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY => sub {
        __x    # DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY
          'The CDS RRset is signed by RRSIG with tag {keytag} but that is not in the '
          . 'DNSKEY RRset. Fetched from the nameservers with P addresses "{ns_ip_list}".',
          @_;
    },
    DS16_CDS_UNSIGNED => sub {
        __x    # DS16_CDS_UNSIGNED
          'The CDS RRset is not signed. Fetched from the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS16_CDS_WITHOUT_DNSKEY => sub {
        __x    # DS16_CDS_WITHOUT_DNSKEY
          'A CDS RRset exists, but no DNSKEY record exists. Fetched from the '
          . 'nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS16_DELETE_CDS => sub {
        __x    # DS16_DELETE_CDS
          'A single "delete" CDS record is found on the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS16_DNSKEY_NOT_SIGNED_BY_CDS => sub {
        __x    # DS16_DNSKEY_NOT_SIGNED_BY_CDS
          'The DNSKEY RRset is not signed by the DNSKEY that the CDS record with tag '
          . '{keytag} points to. Fetched from the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS16_MIXED_DELETE_CDS => sub {
        __x    # DS16_MIXED_DELETE_CDS
          'The CDS RRset is a mixture between "delete" record and other records. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_INVALID_RRSIG => sub {
        __x    # DS17_CDNSKEY_INVALID_RRSIG
          'The CDNSKEY RRset is signed with an RRSIG with tag {keytag}, but the RRSIG does '
          . 'not match the DNSKEY with the same key tag. Fetched from the nameservers '
          . 'with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_MATCHES_NO_DNSKEY => sub {
        __x    # DS17_CDNSKEY_MATCHES_NO_DNSKEY
          'The CDNSKEY record with tag {keytag} does not match any DNSKEY record. Fetched '
          . 'from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY => sub {
        __x    # DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY
          'The CDNSKEY RRset is signed by RRSIG with tag {keytag} but that is not in the '
          . 'DNSKEY RRset. Fetched from the nameservers with P addresses "{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_UNSIGNED => sub {
        __x    # DS17_CDNSKEY_UNSIGNED
          'The CDNSKEY RRset is not signed. Fetched from the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_WITHOUT_DNSKEY => sub {
        __x    # DS17_CDNSKEY_WITHOUT_DNSKEY
          'A CDNSKEY RRset exists, but no DNSKEY record exists. Fetched from the '
          . 'nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS17_DELETE_CDNSKEY => sub {
        __x    # DS17_DELETE_CDNSKEY
          'A single "delete" CDNSKEY record is found on the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY => sub {
        __x    # DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY
          'The DNSKEY RRset is not signed by the DNSKEY that the CDNSKEY record with tag '
          . '{keytag} points to. Fetched from the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS17_MIXED_DELETE_CDNSKEY => sub {
        __x    # DS17_MIXED_DELETE_CDNSKEY
          'The CDNSKEY RRset is a mixture between "delete" record and other records. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS_ALGORITHM_NOT_DS => sub {
        __x    # DNSSEC:DS_ALGORITHM_NOT_DS
          '{ns} returned a DS record created by algorithm {algo_num} '
          . '({algo_mnemo}) which is not meant for DS. The DS record is for '
          . 'the DNSKEY record with keytag {keytag} in zone {domain}.',
          @_;
    },
    DS_ALGORITHM_DEPRECATED => sub {
        __x    # DNSSEC:DS_ALGORITHM_DEPRECATED
          '{ns} returned a DS record created by algorithm {algo_num} '
          . '({algo_mnemo}), which is deprecated. The DS record is for the '
          . 'DNSKEY record with keytag {keytag} in zone {domain}.',
          @_;
    },
    DS_ALGORITHM_MISSING => sub {
        __x    # DNSSEC:DS_ALGORITHM_MISSING
          '{ns} returned no DS record created by algorithm {algo_num} '
          . '({algo_mnemo}) for zone {domain}, which is required.',
          @_;
    },
    DS_ALGORITHM_OK => sub {
        __x    # DNSSEC:DS_ALGORITHM_OK
          '{ns} returned a DS record created by algorithm {algo_num} '
          . '({algo_mnemo}), which is OK. The DS record is for the DNSKEY '
          . 'record with keytag {keytag} in zone {domain}.',
          @_;
    },
    DS_ALGORITHM_RESERVED => sub {
        __x    # DNSSEC:DS_ALGORITHM_RESERVED
          '{ns} returned a DS record created by with an algorithm not assigned '
          . '(algorithm number {algo_num}), which is not OK. The DS record is '
          . 'for the DNSKEY record with keytag {keytag} in zone {domain}.',
          @_;
    },
    DS_ALGO_SHA1_DEPRECATED => sub {
        __x    # DNSSEC:DS_ALGO_SHA1_DEPRECATED
          'Nameserver {ns} returned a DS record created by algorithm '
          . '{algo_num} ({algo_mnemo}) which is deprecated, while it is still '
          . 'widely used. The DS record is for the DNSKEY record with keytag '
          . '{keytag} in zone {domain}.',
          @_;
    },
    DS_BUT_NOT_DNSKEY => sub {
        __x    # DNSSEC:DS_BUT_NOT_DNSKEY
          '{parent} sent a DS record, but {child} did not send a DNSKEY record.', @_;
    },
    DS_MATCHES => sub {
        __x    # DNSSEC:DS_MATCHES
          'The DS records in the parent zone match DNSKEY records in the child zone.', @_;
    },
    DURATION_LONG => sub {
        __x    # DNSSEC:DURATION_LONG
          'RRSIG with keytag {keytag} and covering type(s) {types} '
          . 'has a duration of {duration} seconds, which is too long.',
          @_;
    },
    DURATION_OK => sub {
        __x    # DNSSEC:DURATION_OK
          'RRSIG with keytag {keytag} and covering type(s) {types} '
          . 'has a duration of {duration} seconds, which is just fine.',
          @_;
    },
    EXTRA_PROCESSING_BROKEN => sub {
        __x    # DNSSEC:EXTRA_PROCESSING_BROKEN
          'Server at {server} sent {keys} DNSKEY records, and {sigs} RRSIG records.', @_;
    },
    EXTRA_PROCESSING_OK => sub {
        __x    # DNSSEC:EXTRA_PROCESSING_OK
          'Server at {server} sent {keys} DNSKEY records and {sigs} RRSIG records.', @_;
    },
    HAS_NSEC3 => sub {
        __x    # DNSSEC:HAS_NSEC3
          'The zone has NSEC3 records.', @_;
    },
    HAS_NSEC => sub {
        __x    # DNSSEC:HAS_NSEC
          'The zone has NSEC records.', @_;
    },
    INCONSISTENT_DNSSEC => sub {
        __x    # DNSSEC:INCONSISTENT_DNSSEC
          'Some, but not all, nameservers for zone {domain} respond with neither NSEC nor NSEC3 records when '
          . 'such records are expected.',
          @_;
    },
    INCONSISTENT_NSEC_NSEC3 => sub {
        __x    # DNSSEC:INCONSISTENT_NSEC_NSEC3
          'Some nameservers for zone {domain} respond with NSEC records and others respond with NSEC3 records. '
          . 'Consistency is expected.',
          @_;
    },
    IPV4_DISABLED => sub {
        __x    # DNSSEC:IPV4_DISABLED
          'IPv4 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IPV6_DISABLED => sub {
        __x    # DNSSEC:IPV6_DISABLED
          'IPv6 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    ITERATIONS_OK => sub {
        __x    # DNSSEC:ITERATIONS_OK
          'The number of NSEC3 iterations is {count}, which is OK.', @_;
    },
    KEY_DETAILS => sub {
        __x    # DNSSEC:KEY_DETAILS
          'Key with keytag {keytag} details : Size = {keysize}, Flags ({sep}, {rfc5011}).', @_;
    },
    KEY_SIZE_OK => sub {
        __x    # DNSSEC:KEY_SIZE_OK
          'All keys from the DNSKEY RRset have the correct size.', @_;
    },
    MANY_ITERATIONS => sub {
        __x    # DNSSEC:MANY_ITERATIONS
          'The number of NSEC3 iterations is {count}, which is on the high side.', @_;
    },
    MIXED_NSEC_NSEC3 => sub {
        __x    # DNSSEC:MIXED_NSEC_NSEC3
          'Nameserver {ns} for zone {domain} responds with both NSEC and NSEC3 '
          . 'records when only one record type is expected.',
          @_;
    },
    NEITHER_DNSKEY_NOR_DS => sub {
        __x    # DNSSEC:NEITHER_DNSKEY_NOR_DS
          'There are neither DS nor DNSKEY records for the zone.', @_;
    },
    NO_DNSKEY => sub {
        __x    # DNSSEC:NO_DNSKEY
          'No DNSKEYs were returned.', @_;
    },
    NO_MATCHING_DNSKEY => sub {
        __x    # DNSSEC:NO_MATCHING_DNSKEY
          'Nameserver {ns} returned no DNSKEY record matching the DS record with tag {keytag} '
          . 'found in the parent zone.',
          @_;
    },
    NO_MATCHING_RRSIG => sub {
        __x    # DNSSEC:NO_MATCHING_RRSIG
          'Nameserver {ns} returned no signature on the DNSKEY RRset that corresponds to the '
          . 'DNSKEY with tag {keytag} even though there is a DS record in the parent zone for that '
          . 'DNSKEY record.',
          @_;
    },
    NO_NSEC3PARAM => sub {
        __x    # DNSSEC:NO_NSEC3PARAM
          '{server} returned no NSEC3PARAM records.', @_;
    },
    NO_NSEC_NSEC3 => sub {
        __x    # DNSSEC:NO_NSEC_NSEC3
          'Nameserver {ns} for zone {domain} responds with neither NSEC nor '
          . 'NSEC3 record when when such records are expected.',
          @_;
    },
    NO_RESPONSE_DNSKEY => sub {
        __x    # DNSSEC:NO_RESPONSE_DNSKEY
          'Nameserver {ns} responded with no DNSKEY record(s).', @_;
    },
    NO_RESPONSE_DS => sub {
        __x    # DNSSEC:NO_RESPONSE_DS
          '{ns} returned no DS records for {domain}.', @_;
    },
    NO_RESPONSE => sub {
        __x    # DNSSEC:NO_RESPONSE
          'Nameserver {ns} did not respond.', @_;
    },
    NO_RRSIG_DNSKEY => sub {
        __x    # DNSSEC:NO_RRSIG_DNSKEY
          'Nameserver {ns} responded with no RRSIG record(s) covering the DNSKEY RRset.', @_;
    },
    NOT_SIGNED => sub {
        __x    # DNSSEC:NOT_SIGNED
          'The zone is not signed with DNSSEC.', @_;
    },
    NSEC3_COVERS_NOT => sub {
        __x    # DNSSEC:NSEC3_COVERS_NOT
          'NSEC3 record does not cover {domain}.', @_;
    },
    NSEC3_NOT_SIGNED => sub {
        __x    # DNSSEC:NSEC3_NOT_SIGNED
          'No signature correctly signed the NSEC3 RRset.', @_;
    },
    NSEC3_SIG_VERIFY_ERROR => sub {
        __x    # DNSSEC:NSEC3_SIG_VERIFY_ERROR
          'Trying to verify NSEC3 RRset with RRSIG {keytag} gave error \'{error}\'.', @_;
    },
    NSEC_COVERS_NOT => sub {
        __x    # DNSSEC:NSEC_COVERS_NOT
          'NSEC does not cover {domain}.', @_;
    },
    NSEC_NOT_SIGNED => sub {
        __x    # DNSSEC:NSEC_NOT_SIGNED
          'No signature correctly signed the NSEC RRset.', @_;
    },
    NSEC_SIG_VERIFY_ERROR => sub {
        __x    # DNSSEC:NSEC_SIG_VERIFY_ERROR
          'Trying to verify NSEC RRset with RRSIG {keytag} gave error \'{error}\'.', @_;
    },
    REMAINING_LONG => sub {
        __x    # DNSSEC:REMAINING_LONG
          'RRSIG with keytag {keytag} and covering type(s) {types} '
          . 'has a remaining validity of {duration} seconds, which is too long.',
          @_;
    },
    REMAINING_SHORT => sub {
        __x    # DNSSEC:REMAINING_SHORT
          'RRSIG with keytag {keytag} and covering type(s) {types} '
          . 'has a remaining validity of {duration} seconds, which is too short.',
          @_;
    },
    RRSIG_EXPIRATION => sub {
        __x    # DNSSEC:RRSIG_EXPIRATION
          'RRSIG with keytag {keytag} and covering type(s) {types} expires at ' . ': {date}.', @_;
    },
    RRSIG_EXPIRED => sub {
        __x    # DNSSEC:RRSIG_EXPIRED
          'RRSIG with keytag {keytag} and covering type(s) {types} has already '
          . 'expired (expiration is: {expiration}).',
          @_;
    },
    TEST_ABORTED => sub {
        __x    # DNSSEC:TEST_ABORTED
          'Nameserver {ns} for zone {domain} responds with RCODE "NOERROR" on a query that '
          . 'is expected to give response with RCODE "NXDOMAIN". Test for NSEC and NSEC3 is aborted '
          . 'for this nameserver.',
          @_;
    },
    TEST_CASE_END => sub {
        __x    # DNSSEC:TEST_CASE_END
          'TEST_CASE_END {testcase}.', @_;
    },
    TEST_CASE_START => sub {
        __x    # DNSSEC:TEST_CASE_START
          'TEST_CASE_START {testcase}.', @_;
    },
    TOO_MANY_ITERATIONS => sub {
        __x    # DNSSEC:TOO_MANY_ITERATIONS
          'The number of NSEC3 iterations is {count}, which is too high for key length {keylength}.', @_;
    },
    UNEXPECTED_RESPONSE_DS => sub {
        __x    # DNSSEC:UNEXPECTED_RESPONSE_DS
          'Nameserver {ns} responded with an unexpected rcode ({rcode}) on a DS query for zone {domain}.', @_;
    },
);

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

sub version {
    return "$Zonemaster::Engine::Test::DNSSEC::VERSION";
}

###
### Tests
###

sub dnssec01 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    if ( my $parent = $zone->parent ) {
        foreach my $ns ( @{ $parent->ns } ) {

            if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
                push @results,
                  info(
                    IPV6_DISABLED => {
                        ns     => $ns->string,
                        rrtype => q{DS},
                    }
                  );
                next;
            }

            if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
                push @results,
                  info(
                    IPV4_DISABLED => {
                        ns     => $ns->string,
                        rrtype => q{DS},
                    }
                  );
                next;
            }

            my $ds_p = $ns->query( $zone->name, q{DS}, { usevc => 0, dnssec => 1 } );
            if ( not $ds_p ) {
                push @results,
                  info(
                    NO_RESPONSE_DS => {
                        ns     => $ns->string,
                        domain => q{} . $zone->name,
                    }
                  );
                next;
            }
            elsif ($ds_p->rcode ne q{NOERROR} ) {
                push @results,
                  info(
                    UNEXPECTED_RESPONSE_DS => {
                        ns     => $ns->string,
                        domain => q{} . $zone->name,
                        rcode  => $ds_p->rcode,
                    }
                  );
                next;
            }
            else {
                my $algorithm2 = 0;
                my @dss = $ds_p->get_records( q{DS}, q{answer} );
                foreach my $ds (@dss) {
                    my $mnemonic = $digest_algorithms{ $ds->digtype };
                    if ( $ds->digtype == 0 ) {
                        push @results,
                          info(
                            DS_ALGORITHM_NOT_DS => {
                                ns         => $ns->string,
                                domain     => q{} . $zone->name,
                                keytag     => $ds->keytag,
                                algo_num   => $ds->digtype,
                                algo_mnemo => $mnemonic,
                            }
                          );
                    }
                    elsif ( $ds->digtype == 1 ) {
                        push @results,
                          info(
                            DS_ALGO_SHA1_DEPRECATED => {
                                ns         => $ns->string,
                                domain     => q{} . $zone->name,
                                keytag     => $ds->keytag,
                                algo_num   => $ds->digtype,
                                algo_mnemo => $mnemonic,
                            }
                          );
                    }
                    elsif ( $ds->digtype == 3 ) {
                        push @results,
                          info(
                            DS_ALGORITHM_DEPRECATED => {
                                ns         => $ns->string,
                                domain     => q{} . $zone->name,
                                keytag     => $ds->keytag,
                                algo_num   => $ds->digtype,
                                algo_mnemo => $mnemonic,
                            }
                          );
                    }
                    elsif ( $ds->digtype >= 5 and $ds->digtype <= 255 ) {
                        push @results,
                          info(
                            DS_ALGORITHM_RESERVED => {
                                ns         => $ns->string,
                                domain     => q{} . $zone->name,
                                keytag     => $ds->keytag,
                                algo_num   => $ds->digtype,
                                algo_mnemo => $mnemonic,
                            }
                          );
                    }
                    else {
                        $algorithm2++ if $ds->digtype == 2;
                        push @results,
                          info(
                            DS_ALGORITHM_OK => {
                                ns         => $ns->string,
                                domain     => q{} . $zone->name,
                                keytag     => $ds->keytag,
                                algo_num   => $ds->digtype,
                                algo_mnemo => $mnemonic,
                            }
                          );
                    }
                }
                if ( not $algorithm2 ) {
                    push @results,
                      info(
                        DS_ALGORITHM_MISSING => {
                            ns         => $ns->string,
                            domain     => q{} . $zone->name,
                            algo_num   => 2,
                            algo_mnemo => $digest_algorithms{2},
                        }
                      );
                }
            }    
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec01

sub dnssec02 {
    my ( $class, $zone ) = @_;
    my %ds_records;
    my @keys;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    if ( my $parent = $zone->parent ) {
        foreach my $ns ( @{ $parent->ns } ) {
            my $ns_args = {
                ns     => $ns->string,
                zone   => q{} . $zone->name,
                rrtype => q{DS},
            };

            if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
                push @results, info( IPV6_DISABLED => $ns_args );
                next;
            }

            if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
                push @results, info( IPV4_DISABLED => $ns_args );
                next;
            }

            my $ds_p = $ns->query( $zone->name, q{DS}, { usevc => 0, dnssec => 1 } );
            if ( not $ds_p ) {
                push @results, info( NO_RESPONSE => { ns => $ns->string } );
                next;
            }
            elsif ($ds_p->rcode ne q{NOERROR} ) {
                push @results,
                  info(
                    UNEXPECTED_RESPONSE_DS => {
                        ns     => $ns->string,
                        domain => q{} . $zone->name,
                        rcode  => $ds_p->rcode,
                    }
                  );
                next;
            }
            else {
                my @dss = $ds_p->get_records( q{DS}, q{answer} );
                foreach my $ds ( @dss ) {
                    $ds_records{ $ds->keytag . q{/} . $ds->digtype . q{/} . $ds->algorithm . q{/} . $ds->hexdigest } = $ds;
                }
            }
        }

        if ( scalar values %ds_records ) {
            my @nss_del     = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
            my @nss_child   = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
            my %nss         = map { $_->name->string . q{/} . $_->address->short => $_ } @nss_del, @nss_child;
            my $keys_exists = 0;

            for my $nss_key ( sort keys %nss ) {
                my $ns = $nss{$nss_key};
                my $ns_args = {
                    ns     => $ns->string,
                    zone   => q{} . $zone->name,
                    rrtype => q{DNSKEY},
                };

                if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
                    push @results, info( IPV6_DISABLED => $ns_args );
                    next;
                }

                if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
                    push @results, info( IPV4_DISABLED => $ns_args );
                    next;
                }

                my $dnskey_p = $ns->query( $zone->name, q{DNSKEY}, { dnssec => 1, usevc => 0 } );
                if ( not $dnskey_p ) {
                    push @results, info( NO_RESPONSE => { ns => $ns->string } );
                    next;
                }
                my @keys = $dnskey_p->get_records( q{DNSKEY}, q{answer} );
                if ( not @keys ) {
                    push @results, info( NO_RESPONSE_DNSKEY => { ns => $ns->string } );
                    next;
                }
                else {
                    $keys_exists = 1;
                }

                my @key_sigs = $dnskey_p->get_records( q{RRSIG}, q{answer} );
                if ( not scalar @key_sigs ) {
                    push @results, info( NO_RRSIG_DNSKEY => { ns => $ns->string } );
                }
                else {
                    DS_LOOP: {
                        foreach my $ds ( values %ds_records ) {
                            my @matching_keys = grep { $ds->keytag == $_->keytag } @keys;
                            if ( not scalar @matching_keys ) {
                                push @results,
                                  info(
                                    NO_MATCHING_DNSKEY => {
                                        ns     => $ns->string,
                                        keytag => $ds->keytag,
                                    }
                                  );
                            }
                            foreach my $key ( @matching_keys ) {
                                if ( not $ds->verify( $key ) ) {
                                    push @results,
                                      info(
                                        BROKEN_DS => {
                                            ns     => $ns->string,
                                            keytag => $ds->keytag,
                                        }
                                      );
                                }
                                if ( not $key->flags & 256 ) { # Bit 7 (ZONE)
                                    push @results,
                                      info(
                                        DNSKEY_NOT_ZONE_SIGN => {
                                            ns     => $ns->string,
                                            keytag => $ds->keytag,
                                        }
                                      );
                                    next DS_LOOP;
                                }
                                if ( not $key->flags & 1 ) { # Bit 15 (SEP)
                                    push @results,
                                      info(
                                        DNSKEY_KSK_NOT_SEP => {
                                            ns     => $ns->string,
                                            keytag => $ds->keytag,
                                        }
                                      );
                                }
                            }
                            my @matching_sigs = grep { $ds->keytag == $_->keytag } @key_sigs;
                            if ( not scalar @matching_sigs ) {
                                push @results,
                                  info(
                                    NO_MATCHING_RRSIG => {
                                        ns     => $ns->string,
                                        keytag => $ds->keytag,
                                    }
                                  );
                            }
                            my $msg  = q{};
                            my $time = $dnskey_p->timestamp;
                            foreach my $sig ( @matching_sigs ) {
                                if ( not $sig->verify_time( \@keys, \@keys, $time, $msg ) ) {
                                    push @results,
                                      info(
                                        BROKEN_RRSIG => {
                                            ns     => $ns->string,
                                            keytag => $ds->keytag,
                                            error  => $msg,
                                        }
                                      );
                                }
                            }
                        }
                    }
                }
            }
            if ( $keys_exists ) {
                if ( not scalar grep { $_->tag ne q{NO_RESPONSE} and $_->tag ne q{DNSKEY_KSK_NOT_SEP} and $_->tag ne q{TEST_CASE_START} } @results ) {
                    push @results, info( DS_MATCHES => {} );
                }
            }
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec02

sub dnssec03 {
    my ( $self, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my $param_p = $zone->query_one( $zone->name, 'NSEC3PARAM', { dnssec => 1 } );

    my @nsec3params;
    @nsec3params = $param_p->get_records( 'NSEC3PARAM', 'answer' ) if $param_p;

    if ( @nsec3params == 0 ) {
        push @results,
          info(
            NO_NSEC3PARAM => {
                server => ( $param_p ? $param_p->answerfrom : '<no response>' ),
            }
          );
    }
    else {
        my $dk_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );

        my @dnskey;
        @dnskey = $dk_p->get_records( 'DNSKEY', 'answer' ) if $dk_p;

        my $min_len = 0;
        if ( @dnskey ) {
            $min_len = min map { $_->keysize } @dnskey;
            # Do rounding as per RFC5155 section 10.3
            if ($min_len > 2048) {
                $min_len = 4096;
            }
            elsif ($min_len > 1024) {
                $min_len = 2048;
            }
            else {
                $min_len = 1024;
            }
        }
        else {
            push @results,
              info( NO_DNSKEY => {} );
        }

        foreach my $n3p ( @nsec3params ) {
            my $iter = $n3p->iterations;
            if ( $iter > 100 ) {
                push @results,
                  info(
                    MANY_ITERATIONS => {
                        count => $iter,
                    }
                  );
                if (   (                     $min_len >= 4096 and $iter > 2500 )
                    or ( $min_len < 4096 and $min_len >= 2048 and $iter > 500  )
                    or ( $min_len < 2048 and $min_len >= 1024 and $iter > 150  ) )
                {
                    push @results,
                      info(
                        TOO_MANY_ITERATIONS => {
                            count     => $iter,
                            keylength => $min_len,
                        }
                      );
                }
            } ## end if ( $iter > 100 )
            elsif ( $min_len > 0 ) 
            {
                push @results,
                  info(
                    ITERATIONS_OK => {
                        count => $iter,
                    }
                  );
            }
        } ## end foreach my $n3p ( @nsec3params)
    } ## end else [ if ( @nsec3params == 0)]

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec03

sub dnssec04 {
    my ( $self, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my $dnskey_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $dnskey_p ) {
        return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
    }
    my @keys     = $dnskey_p->get_records( 'DNSKEY', 'answer' );
    my @key_sigs = $dnskey_p->get_records( 'RRSIG',  'answer' );

    my $soa_p = $zone->query_one( $zone->name, 'SOA', { dnssec => 1 } );
    if ( not $soa_p ) {
        return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
    }
    my @soas     = $soa_p->get_records( 'SOA',   'answer' );
    my @soa_sigs = $soa_p->get_records( 'RRSIG', 'answer' );

    foreach my $sig ( @key_sigs, @soa_sigs ) {
        push @results,
          info(
            RRSIG_EXPIRATION => {
                date   => scalar( gmtime($sig->expiration) ),
                keytag => $sig->keytag,
                types  => $sig->typecovered,
            }
          );

        my $remaining = $sig->expiration - int( $dnskey_p->timestamp );
        my $result_remaining;
        my $remaining_short_limit = Zonemaster::Engine::Profile->effective->get( q{test_cases_vars.dnssec04.REMAINING_SHORT} );
        my $remaining_long_limit  = Zonemaster::Engine::Profile->effective->get( q{test_cases_vars.dnssec04.REMAINING_LONG} );
        my $duration_long_limit   = Zonemaster::Engine::Profile->effective->get( q{test_cases_vars.dnssec04.DURATION_LONG} );

        if ( $remaining < 0 ) {    # already expired
            $result_remaining = info(
                RRSIG_EXPIRED => {
                    expiration => $sig->expiration,
                    keytag     => $sig->keytag,
                    types      => $sig->typecovered,
                }
            );
        }
        elsif ( $remaining < ( $remaining_short_limit ) ) {
            $result_remaining = info(
                REMAINING_SHORT => {
                    duration => $remaining,
                    keytag   => $sig->keytag,
                    types    => $sig->typecovered,
                }
            );
        }
        elsif ( $remaining > ( $remaining_long_limit ) ) {
            $result_remaining = info(
                REMAINING_LONG => {
                    duration => $remaining,
                    keytag   => $sig->keytag,
                    types    => $sig->typecovered,
                }
            );
        }

        my $duration = $sig->expiration - $sig->inception;
        my $result_duration;
        if ( $duration > ( $duration_long_limit ) ) {
            $result_duration = info(
                DURATION_LONG => {
                    duration => $duration,
                    keytag   => $sig->keytag,
                    types    => $sig->typecovered,
                }
            );
        }

        if ( $result_remaining or $result_duration ) {
            push @results, $result_remaining if $result_remaining;
            push @results, $result_duration  if $result_duration;
        }
        else {
            push @results,
              info(
                DURATION_OK => {
                    duration => $duration,
                    keytag   => $sig->keytag,
                    types    => $sig->typecovered,
                }
              );
        }
    } ## end foreach my $sig ( @key_sigs...)

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec04

sub dnssec05 {
    my ( $self, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;

    for my $key ( sort keys %nss ) {
        my $ns = $nss{$key};

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{DNSKEY},
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{DNSKEY},
                }
              );
            next;
        }

        my $dnskey_p = $ns->query( $zone->name, 'DNSKEY', { dnssec => 1 } );
        if ( not $dnskey_p ) {
            push @results, info( NO_RESPONSE => { ns => $ns->string } );
            next;
        }

        my @keys = $dnskey_p->get_records( 'DNSKEY', 'answer' );
        if ( not @keys ) {
            push @results, info( NO_RESPONSE_DNSKEY => { ns => $ns->string } );
            next;
        }

        foreach my $key ( @keys ) {
            my $algo      = $key->algorithm;
            my $algo_args = {
                algo_num    => $algo,
                keytag      => $key->keytag,
                algo_descr  => $algo_properties{$algo}{description},
            };

            if ( $algo_properties{$algo}{status} == $ALGO_STATUS_DEPRECATED ) {
                push @results, info( ALGORITHM_DEPRECATED => $algo_args );
            }
            elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_RESERVED ) {
                push @results, info( ALGORITHM_RESERVED => $algo_args );
            }
            elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_UNASSIGNED ) {
                push @results, info( ALGORITHM_UNASSIGNED => $algo_args );
            }
            elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_PRIVATE ) {
                push @results, info( ALGORITHM_PRIVATE => $algo_args );
            }
            elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_NOT_ZONE_SIGN ) {
                push @results, info( ALGORITHM_NOT_ZONE_SIGN => $algo_args );
            }
            elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_NOT_RECOMMENDED ) {
                push @results, info( ALGORITHM_NOT_RECOMMENDED => $algo_args );
            }
            else {
                push @results, info( ALGORITHM_OK => $algo_args );
                if ( $key->flags & 256 ) {    # This is a Key
                    push @results,
                      info(
                        KEY_DETAILS => {
                            keytag  => $key->keytag,
                            keysize => $key->keysize,
                            sep     => $key->flags & 1 ? q{SEP bit set} : q{SEP bit *not* set},
                            rfc5011 => $key->flags & 128
                            ? q{RFC 5011 revocation bit set}
                            : q{RFC 5011 revocation bit *not* set},
                        }
                      );
                }
            }

        } ## end foreach my $key ( @keys )
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec05

sub dnssec06 {
    my ( $self, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my $dnskey_aref = $zone->query_all( $zone->name, 'DNSKEY', { dnssec => 1 } );
    foreach my $dnskey_p ( @{$dnskey_aref} ) {
        next if not $dnskey_p;

        my @keys = $dnskey_p->get_records( 'DNSKEY', 'answer' );
        my @sigs = $dnskey_p->get_records( 'RRSIG',  'answer' );
        if ( @sigs > 0 and @keys > 0 ) {
            push @results,
              info(
                EXTRA_PROCESSING_OK => {
                    server => $dnskey_p->answerfrom,
                    keys   => scalar( @keys ),
                    sigs   => scalar( @sigs ),
                }
              );
        }
        elsif ( $dnskey_p->rcode eq q{NOERROR} and ( @sigs == 0 or @keys == 0 ) ) {
            push @results,
              info(
                EXTRA_PROCESSING_BROKEN => {
                    server => $dnskey_p->answerfrom,
                    keys   => scalar( @keys ),
                    sigs   => scalar( @sigs )
                }
              );
        }
    } ## end foreach my $dnskey_p ( @{$dnskey_aref...})

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec06

sub dnssec07 {
    my ( $self, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    if ( not $zone->parent ) {
        return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
    }
    my $dnskey_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $dnskey_p ) {
        return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
    }
    my ( $dnskey ) = $dnskey_p->get_records( 'DNSKEY', 'answer' );

    my $ds_p = $zone->parent->query_one( $zone->name, 'DS', { dnssec => 1 } );
    if ( not $ds_p ) {
        return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
    }
    my ( $ds ) = $ds_p->get_records( 'DS', 'answer' );

    if ( $dnskey and not $ds ) {
        push @results,
          info(
            DNSKEY_BUT_NOT_DS => {
                child  => $dnskey_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }
    elsif ( $dnskey and $ds ) {
        push @results,
          info(
            DNSKEY_AND_DS => {
                child  => $dnskey_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }
    elsif ( not $dnskey and $ds ) {
        push @results,
          info(
            DS_BUT_NOT_DNSKEY => {
                child  => $dnskey_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }
    else {
        push @results,
          info(
            NEITHER_DNSKEY_NOR_DS => {
                child  => $dnskey_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec07

sub dnssec08 {
    my ( $self, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my @dnskey_without_rrsig;
    my %dnskey_rrsig_not_yet_valid;
    my %dnskey_rrsig_expired;
    my %no_matching_dnskey;
    my %rrsig_not_valid_by_dnskey;
    my %algo_not_supported_by_zm;

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;
    my %ip_already_processed;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{DNSKEY}
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{DNSKEY}
                }
              );
            next;
        }

        my $dnskey_p = $ns->query( $zone->name, q{DNSKEY}, { dnssec => 1 } );
        if ( not $dnskey_p ) {
            next;
        }
        if ( $dnskey_p->rcode ne q{NOERROR} ) {
            next;
        }
        if ( not $dnskey_p->aa ) {
            next;
        }

        my @dnskey_records = $dnskey_p->get_records_for_name( q{DNSKEY}, $zone->name->string, q{answer} );
        if ( not scalar @dnskey_records ) {
            next;
        }
        @dnskey_records = $dnskey_p->get_records( q{DNSKEY},  q{answer} );
        my @rrsig_records = $dnskey_p->get_records( q{RRSIG},  q{answer} );

        if ( not scalar @rrsig_records ) {
            push @dnskey_without_rrsig, $ns->address->short;
            next;
        }

        my $time = $dnskey_p->timestamp;
        foreach my $rrsig_record ( @rrsig_records ) {
            if ( $rrsig_record->inception > $time ) {
                push @{ $dnskey_rrsig_not_yet_valid{$rrsig_record->keytag} }, $ns->address->short;
            }
            elsif ( $rrsig_record->expiration < $time ) {
                push @{ $dnskey_rrsig_expired{$rrsig_record->keytag} }, $ns->address->short;
            }
            else {
                my $msg = q{};
                my $validate = $rrsig_record->verify_time( \@dnskey_records, \@dnskey_records, $time, $msg );
                # Ajouter dans %algo_not_supported_by_zm 
                if ( not $validate and $msg =~ /Unknown cryptographic algorithm/ ) {
                    push @{ $algo_not_supported_by_zm{$rrsig_record->keytag}{$rrsig_record->algorithm} }, $ns->address->short;
                }
                elsif ( not scalar grep { $_->keytag == $rrsig_record->keytag } @dnskey_records ) {
                    push @{ $no_matching_dnskey{$rrsig_record->keytag} }, $ns->address->short;
                }
                elsif ( not $validate ) {
                    push @{ $rrsig_not_valid_by_dnskey{$rrsig_record->keytag} }, $ns->address->short;
                }
            }
        }
    }
    if ( scalar @dnskey_without_rrsig ) {
        push @results,
          info(
            DS08_MISSING_RRSIG_IN_RESPONSE => {
                ns_ip_list => join( q{;}, uniq sort @dnskey_without_rrsig )
            }
          );
    }
    if ( scalar keys %dnskey_rrsig_not_yet_valid ) {
        push @results, map {
          info(
            DS08_DNSKEY_RRSIG_NOT_YET_VALID => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $dnskey_rrsig_not_yet_valid{$_} } )
            }
          )
        } keys %dnskey_rrsig_not_yet_valid;
    }
    if ( scalar keys %dnskey_rrsig_expired ) {
        push @results, map {
          info(
            DS08_DNSKEY_RRSIG_EXPIRED => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $dnskey_rrsig_expired{$_} } )
            }
          )
        } keys %dnskey_rrsig_expired;
    }
    if ( scalar keys %no_matching_dnskey ) {
        push @results, map {
          info(
            DS08_NO_MATCHING_DNSKEY => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $no_matching_dnskey{$_} } )
            }
          )
        } keys %no_matching_dnskey;
    }
    if ( scalar keys %rrsig_not_valid_by_dnskey ) {
        push @results, map {
          info(
            DS08_RRSIG_NOT_VALID_BY_DNSKEY => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $rrsig_not_valid_by_dnskey{$_} } )
            }
          )
        } keys %rrsig_not_valid_by_dnskey;
    }
    if ( scalar keys %algo_not_supported_by_zm ) {
        foreach my $keytag ( keys %algo_not_supported_by_zm ) {
            push @results, map {
              info(
                DS08_ALGO_NOT_SUPPORTED_BY_ZM => {
                    keytag     => $keytag,
                    algo_num   => $_,
                    algo_mnemo => $algo_properties{$_}{mnemonic},
                    ns_ip_list => join( q{;}, uniq sort @{ $algo_not_supported_by_zm{$keytag}{$_} } )
                }
              )
            } keys %{ $algo_not_supported_by_zm{$keytag} }
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec08

sub dnssec09 {
    my ( $self, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my @soa_without_rrsig;
    my %soa_rrsig_not_yet_valid;
    my %soa_rrsig_expired;
    my %no_matching_dnskey;
    my %rrsig_not_valid_by_dnskey;
    my %algo_not_supported_by_zm;

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;
    my %ip_already_processed;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{DNSKEY}
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{DNSKEY}
                }
              );
            next;
        }

        my $dnskey_p = $ns->query( $zone->name, q{DNSKEY}, { dnssec => 1 } );
        if ( not $dnskey_p ) {
            next;
        }
        if ( $dnskey_p->rcode ne q{NOERROR} ) {
            next;
        }
        if ( not $dnskey_p->aa ) {
            next;
        }

        my @dnskey_records = $dnskey_p->get_records_for_name( q{DNSKEY}, $zone->name->string, q{answer} );
        if ( not scalar @dnskey_records ) {
            next;
        }
        @dnskey_records = $dnskey_p->get_records( q{DNSKEY},  q{answer} );

        my $soa_p = $ns->query( $zone->name, q{SOA}, { dnssec => 1, usevc => 0 } );
        if ( not $soa_p ) {
            next;
        }
        if ( $soa_p->rcode ne q{NOERROR} ) {
            next;
        }
        if ( not $soa_p->aa ) {
            next;
        }

        my @soa_records = $soa_p->get_records_for_name( q{SOA}, $zone->name->string, q{answer} );
        if ( not scalar @soa_records ) {
            next;
        }
        @soa_records = $soa_p->get_records( q{SOA}, q{answer} );
        my @rrsig_records = $soa_p->get_records( q{RRSIG},  q{answer} );

        if ( not scalar @rrsig_records ) {
            push @soa_without_rrsig, $ns->address->short;
            next;
        }

        my $time = $dnskey_p->timestamp;
        foreach my $rrsig_record ( @rrsig_records ) {
            if ( $rrsig_record->inception > $time ) {
                push @{ $soa_rrsig_not_yet_valid{$rrsig_record->keytag} }, $ns->address->short;
            }
            elsif ( $rrsig_record->expiration < $time ) {
                push @{ $soa_rrsig_expired{$rrsig_record->keytag} }, $ns->address->short;
            }
            else {
                my $msg = q{};
                my $validate = $rrsig_record->verify_time( \@soa_records, \@dnskey_records, $time, $msg );
                if ( not $validate and $msg =~ /Unknown cryptographic algorithm/ ) {
                    push @{ $algo_not_supported_by_zm{$rrsig_record->keytag}{$rrsig_record->algorithm} }, $ns->address->short;
                }
                elsif ( not scalar grep { $_->keytag == $rrsig_record->keytag } @dnskey_records ) {
                    push @{ $no_matching_dnskey{$rrsig_record->keytag} }, $ns->address->short;
                }
                elsif ( not $validate ) {
                    push @{ $rrsig_not_valid_by_dnskey{$rrsig_record->keytag} }, $ns->address->short;
                }
            }
        }
    }
    if ( scalar @soa_without_rrsig ) {
        push @results,
          info(
            DS09_MISSING_RRSIG_IN_RESPONSE => {
                ns_ip_list => join( q{;}, uniq sort @soa_without_rrsig )
            }
          );
    }
    if ( scalar keys %soa_rrsig_not_yet_valid ) {
        push @results, map {
          info(
            DS09_SOA_RRSIG_NOT_YET_VALID => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $soa_rrsig_not_yet_valid{$_} } )
            }
          )
        } keys %soa_rrsig_not_yet_valid;
    }
    if ( scalar keys %soa_rrsig_expired ) {
        push @results, map {
          info(
            DS09_SOA_RRSIG_EXPIRED => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $soa_rrsig_expired{$_} } )
            }
          )
        } keys %soa_rrsig_expired;
    }
    if ( scalar keys %no_matching_dnskey ) {
        push @results, map {
          info(
            DS09_NO_MATCHING_DNSKEY => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $no_matching_dnskey{$_} } )
            }
          )
        } keys %no_matching_dnskey;
    }
    if ( scalar keys %rrsig_not_valid_by_dnskey ) {
        push @results, map {
          info(
            DS09_RRSIG_NOT_VALID_BY_DNSKEY => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $rrsig_not_valid_by_dnskey{$_} } )
            }
          )
        } keys %rrsig_not_valid_by_dnskey;
    }
    if ( scalar keys %algo_not_supported_by_zm ) {
        foreach my $keytag ( keys %algo_not_supported_by_zm ) {
            push @results, map {
              info(
                DS09_ALGO_NOT_SUPPORTED_BY_ZM => {
                    keytag     => $keytag,
                    algo_num   => $_,
                    algo_mnemo => $algo_properties{$_}{mnemonic},
                    ns_ip_list => join( q{;}, uniq sort @{ $algo_not_supported_by_zm{$keytag}{$_} } )
                }
              )
            } keys %{ $algo_not_supported_by_zm{$keytag} }
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec09

sub dnssec10 {
    my ( $self, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my $non_existent_domain_name = $zone->name->prepend( q{xx--test-test-test} );

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;
    my (%nsec_zone, %nsec3_zone, %no_dnssec_zone);

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{A},
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{A},
                }
              );
            next;
        }

        my $a_p = $ns->query( $non_existent_domain_name , q{A}, { usevc => 0, dnssec => 1 } );
        if ( not $a_p ) {
            push @results, info( NO_RESPONSE => { ns => $ns->string } );
        }
        elsif ($a_p->rcode eq q{NOERROR} ) {
            push @results,
              info(
                TEST_ABORTED => {
                    ns     => $ns->string,
                    domain => $zone->name->string,
                }
              );
        }
        elsif ($a_p->rcode ne q{NXDOMAIN} ) {
            my $args = {
                ns    => $ns->string,
                rcode => $a_p->rcode,
            };
            push @results, info( INVALID_RCODE => $args );
        }
        else {
            my @nsec  = $a_p->get_records( q{NSEC}, q{authority} );
            my @nsec3 = $a_p->get_records( q{NSEC3}, q{authority} );
            if ( scalar @nsec and scalar @nsec3 ) {
                push @results,
                  info(
                    MIXED_NSEC_NSEC3 => {
                        ns     => $ns->string,
                        domain => $zone->name->string,
                    }
                  );
            }
            elsif ( not scalar @nsec and not scalar @nsec3 ) {
                push @results,
                  info(
                    NO_NSEC_NSEC3 => {
                        ns     => $ns->string,
                        domain => $zone->name->string,
                    }
                  );
                $no_dnssec_zone{$ns->address->short}++;
            }
            elsif ( scalar @nsec and not scalar @nsec3 ) {
                $nsec_zone{$ns->address->short}++;
                my $dnskey_p = $ns->query( $zone->name , q{DNSKEY}, { dnssec => 1 } );
                my @dnskeys = ();
                my $covered = 0;
                if ( $dnskey_p ) {
                    @dnskeys = $dnskey_p->get_records( q{DNSKEY}, q{answer} );
                }
                foreach my $nsec ( @nsec ) {
                    if ($nsec->covers( $non_existent_domain_name) ) {
                        $covered = 1;
                        my @sigs = grep { $_->typecovered eq q{NSEC} } $a_p->get_records_for_name( q{RRSIG}, $nsec->name );
                        if ( scalar @sigs ) {
                            my $ok = 0;
                            foreach my $sig ( @sigs ) {
                                my $msg = q{};
                                if ( not scalar @dnskeys ) {
                                    push @results, info( NSEC_SIG_VERIFY_ERROR => { error => q{DNSKEY missing}, keytag => $sig->keytag } );
                                }
                                elsif (
                                    $sig->verify_time(
                                        [ grep { name( $_->name ) eq name( $sig->name ) } @nsec ],
                                        \@dnskeys, $a_p->timestamp, $msg
                                    )
                                  )
                                {
                                    $ok = 1;
                                }
                                else {
                                    if ( $sig->algorithm >= 12 and $sig->algorithm <= 16 and $msg =~ /Unknown cryptographic algorithm/ ) {
                                        $msg = q{no }. $algo_properties{$sig->algorithm}{description}. q{ support};
                                    }
                                    push @results,
                                      info(
                                        NSEC_SIG_VERIFY_ERROR => {
                                            error  => $msg,
                                            keytag => $sig->keytag,
                                        }
                                      );
                                }
                            }
                        }
                        else {
                            push @results, info( NSEC_NOT_SIGNED => {} );
                        }
                    }
                }
                if ( not $covered ) {
                    push @results, info( NSEC_COVERS_NOT => { domain => $non_existent_domain_name } );
                }
            }
            elsif ( not scalar @nsec and scalar @nsec3 ) {
                $nsec3_zone{$ns->address->short}++;
                my $dnskey_p = $ns->query( $zone->name , q{DNSKEY}, { dnssec => 1 } );
                my @dnskeys = ();
                my $covered = 0;
                if ( $dnskey_p ) {
                    @dnskeys = $dnskey_p->get_records( 'DNSKEY', 'answer' );
                }
                foreach my $nsec3 ( @nsec3 ) {
                    if ( $nsec3->covers( $non_existent_domain_name ) ) {
                        $covered = 1;
                        my @sigs = grep { $_->typecovered eq 'NSEC3' } $a_p->get_records_for_name( 'RRSIG', $nsec3->name );
                        if ( scalar @sigs ) {
                            my $ok = 0;
                            foreach my $sig ( @sigs ) {
                                my $msg = q{};
                                if ( not scalar @dnskeys ) {
                                    push @results, info( NSEC3_SIG_VERIFY_ERROR => { error => 'DNSKEY missing', keytag => $sig->keytag } );
                                }
                                elsif (
                                    $sig->verify_time(
                                        [ grep { name( $_->name ) eq name( $sig->name ) } @nsec3 ],
                                        \@dnskeys, $a_p->timestamp, $msg
                                    )
                                  )
                                {
                                    $ok = 1;
                                }
                                else {
                                    if ( $sig->algorithm >= 12 and $sig->algorithm <= 16 and $msg =~ /Unknown cryptographic algorithm/ ) {
                                        $msg = q{no }. $algo_properties{$sig->algorithm}{description}. q{ support};
                                    }
                                    push @results,
                                      info(
                                        NSEC3_SIG_VERIFY_ERROR => {
                                            error  => $msg,
                                            keytag => $sig->keytag,
                                        }
                                      );
                                }
                            }
                        }
                        else {
                            push @results, info( NSEC3_NOT_SIGNED => {} );
                        }
                    }
                }
                if ( not $covered ) {
                    push @results, info( NSEC3_COVERS_NOT => { domain => $non_existent_domain_name } );
                }
            }
        }
    }

    if ( scalar keys %no_dnssec_zone and ( scalar keys %nsec_zone or scalar keys %nsec3_zone ) ) {
        push @results, info( INCONSISTENT_DNSSEC => { domain => $zone->name->string } );
    }
    elsif ( scalar keys %no_dnssec_zone and not scalar keys %nsec_zone and not scalar keys %nsec3_zone ) {
        push @results, info( BROKEN_DNSSEC => { domain => $zone->name->string } );
    }
    elsif ( scalar keys %nsec_zone and scalar keys %nsec3_zone ) {
        push @results, info( INCONSISTENT_NSEC_NSEC3 => { domain => $zone->name->string } );
    }
    elsif ( scalar keys %nsec_zone and not grep { $_->tag eq q{MIXED_NSEC_NSEC3} } @results ) {
        push @results, info( HAS_NSEC => {} );
    }
    elsif ( scalar keys %nsec3_zone and not grep { $_->tag eq q{MIXED_NSEC_NSEC3} } @results ) {
        push @results, info( HAS_NSEC3 => {} );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec10

sub dnssec11 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my @undetermined_ds;
    my @no_ds_record;
    my @has_ds_record;
    my $continue_with_child_tests = 1;

    my $parent     = Zonemaster::Engine::TestMethods->method1( $zone );
    my @nss_parent = @{ $parent->ns };
    my %nss        = map { $_->name->string . '/' . $_->address->short => $_ } @nss_parent;
    my %ip_already_processed;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{DS} 
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{DS}
                }
              );
            next;
        }

        my $ds_p = $ns->query( $zone->name, q{DS}, { dnssec => 1, usevc => 0 } );
        if ($ds_p and $ds_p->tc) {
            $ds_p = $ns->query( $zone->name, q{DS}, { dnssec => 1, usevc => 1 } );
        }

        if ( not $ds_p or $ds_p->rcode ne q{NOERROR} or not $ds_p->aa ) {
            push @undetermined_ds, $ns->address->short;
            next;
        }
        my @ds = $ds_p->get_records_for_name( q{DS}, $zone->name->string, q{answer} );
        if ( not scalar @ds ) {
            push @no_ds_record, $ns->address->short;
        }
        else {
            push @has_ds_record, $ns->address->short;
        }
    }
    undef %ip_already_processed;

    if ( scalar @undetermined_ds and not scalar @no_ds_record and not scalar @has_ds_record ) {
        push @results, info( DS11_UNDETERMINED_DS => {} );
        $continue_with_child_tests = 0;
    }
    elsif ( scalar @no_ds_record and not scalar @has_ds_record ) {
        $continue_with_child_tests = 0;
    }
    elsif ( scalar @no_ds_record and scalar @has_ds_record ) {
        push @results, info( DS11_INCONSISTENT_DS => {} );
        push @results,
          info(
            DS11_PARENT_WITHOUT_DS => {
                ns_ip_list => join( q{;}, sort @no_ds_record )
            }
          );
        push @results,
          info(
             DS11_PARENT_WITH_DS => {
                ns_ip_list => join( q{;}, sort @has_ds_record )
            }
          );
    }

    if ( $continue_with_child_tests ) {
        my @query_types = qw{SOA DNSKEY};
        my @undetermined_dnskey;
        my @no_dnskey_record;
        my @has_dnskey_record;

        my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
        my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
        my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;
        my %ip_already_processed;

        for my $nss_key ( sort keys %nss ) {
            my $ns = $nss{$nss_key};

            next if exists $ip_already_processed{$ns->address->short};
            $ip_already_processed{$ns->address->short} = 1;

            if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
                push @results, map {
                  info(
                    IPV6_DISABLED => {
                        ns     => $ns->string,
                        rrtype => $_
                    }
                  )
                } @query_types;
                next;
            }

            if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
                push @results, map {
                  info(
                    IPV4_DISABLED => {
                        ns     => $ns->string,
                        rrtype => $_
                    }
                  )
                } @query_types;
                next;
            }

            my $soa_p = $ns->query( $zone->name, q{SOA}, { usevc => 0 } );
            if ( not $soa_p ) {
                next;
            }
            if ( $soa_p->rcode ne q{NOERROR} ) {
                next;
            }
            if ( not $soa_p->aa ) {
                next;
            }
            my @soa = $soa_p->get_records_for_name( q{SOA}, $zone->name->string, q{answer} );
            if ( not scalar @soa ) {
                next;
            }

            my $dnskey_p = $ns->query( $zone->name, q{DNSKEY}, { usevc => 0 } );
            if ( $dnskey_p->tc ) {
                $dnskey_p = $ns->query( $zone->name, q{DNSKEY}, { usevc => 1 } );
            }

            if ( not $dnskey_p or $dnskey_p->rcode ne q{NOERROR} or not $dnskey_p->aa ) {
                push @undetermined_dnskey, $ns->address->short;
                next;
            }
            my @dnskey = $dnskey_p->get_records_for_name( q{DNSKEY}, $zone->name->string, q{answer} );
            if ( not scalar @dnskey ) {
                push @no_dnskey_record, $ns->address->short;
            }
            else {
                push @has_dnskey_record, $ns->address->short;
            }
        }
        undef %ip_already_processed;

        if ( scalar @undetermined_dnskey and not scalar @no_dnskey_record and not scalar @has_dnskey_record ) {
            push @results, info( DS11_UNDETERMINED_SIGNED_ZONE => {} );
        }
        elsif ( scalar @no_dnskey_record and not scalar @has_dnskey_record ) {
            push @results, info( DS11_DS_BUT_UNSIGNED_ZONE => {} );
        }
        elsif ( scalar @no_dnskey_record and scalar @has_dnskey_record ) {
            push @results, info( DS11_INCONSISTENT_SIGNED_ZONE => {} );
            push @results,
              info(
                DS11_NS_WITH_UNSIGNED_ZONE => {
                    ns_ip_list => join( q{;}, sort @no_dnskey_record )
                }
              );
            push @results,
              info(
                  DS11_NS_WITH_SIGNED_ZONE => {
                    ns_ip_list => join( q{;}, sort @has_dnskey_record )
                }
              );
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec11

sub dnssec13 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my @query_types = qw{DNSKEY SOA NS};
    my %algo_not_signed;
    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;
    my %ip_already_processed;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results, map {
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              );
            } @query_types;
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results, map {
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              )
            } @query_types;
            next;
        }

        my %dnskey_algorithm;
        foreach my $query_type ( @query_types ) {

            my $p = $ns->query( $zone->name, $query_type, { dnssec => 1, usevc => 0 } );
            if ( not $p ) {
                next;
            }
            if ( $p->rcode ne q{NOERROR} ) {
                next;
            }
            if ( not $p->aa ) {
                next;
            }
            my @type_records = $p->get_records( $query_type, q{answer} );
            if ( not scalar @type_records ) {
                next;
            }
            my @rrsig_records = $p->get_records( q{RRSIG} , q{answer} );
            if ( not scalar @rrsig_records ) {
                next;
            }

            if ( $query_type eq q{DNSKEY} ) {
                %dnskey_algorithm = map { $_->algorithm => 1 } @type_records;
            }
            foreach my $algorithm ( keys %dnskey_algorithm ) {
                if ( not scalar grep { $_->algorithm == $algorithm } @rrsig_records ) {
                    push @{ $algo_not_signed{ lc($query_type) }{$algorithm} }, $ns->address->short;
                }
            }
        }
    }

    foreach my $query_type ( @query_types ) {
        if ( exists $algo_not_signed{ lc($query_type) } ) {
            foreach my $algorithm ( keys %{ $algo_not_signed{ lc($query_type) } } ) {
                push @results,
                  info(
                    "DS13_ALGO_NOT_SIGNED_${query_type}" => {
                        ns_ip_list => join( q{;}, uniq sort @{ $algo_not_signed{ lc($query_type) }{$algorithm} }),
                        algo_num   => $algorithm,
                        algo_mnemo => $algo_properties{$algorithm}{mnemonic}
                    }
                  );
            }
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec13

sub dnssec14 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my @dnskey_rrs;

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{DNSKEY},
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => q{DNSKEY},
                }
              );
            next;
        }

        my $dnskey_p = $ns->query( $zone->name, 'DNSKEY', { dnssec => 1, usevc => 0 } );
        if ( not $dnskey_p ) {
            push @results, info( NO_RESPONSE => { ns => $ns->string } );
            next;
        }

        my @keys = $dnskey_p->get_records( 'DNSKEY', 'answer' );
        if ( not @keys ) {
            push @results, info( NO_RESPONSE_DNSKEY => { ns => $ns->string } );
            next;
        } else {
            push @dnskey_rrs, @keys;
        }
    }

    my %investigated_keys;
    foreach my $key ( @dnskey_rrs ) {
        my $algo = $key->algorithm;  

        next if not exists $rsa_key_size_details{$algo};

        # Only test once per keytag, keysize and algorithm
        my $key_ref = join ':', $key->keytag, $key->keysize, $algo;
        next if exists $investigated_keys{$key_ref};

        my $algo_args = {
            algo_num   => $algo,
            algo_descr => $algo_properties{$algo}{description},
            keytag     => $key->keytag,
            keysize    => $key->keysize,
            keysizemin => $rsa_key_size_details{$algo}{min_size},
            keysizemax => $rsa_key_size_details{$algo}{max_size},
            keysizerec => $rsa_key_size_details{$algo}{rec_size},
        };

        if ( $key->keysize < $rsa_key_size_details{$algo}{min_size} ) {
            push @results, info( DNSKEY_TOO_SMALL_FOR_ALGO => $algo_args );
        }

        if ( $key->keysize < $rsa_key_size_details{$algo}{rec_size} ) {
            push @results, info( DNSKEY_SMALLER_THAN_REC => $algo_args );
        }

        if ( $key->keysize > $rsa_key_size_details{$algo}{max_size} ) {
            push @results, info( DNSKEY_TOO_LARGE_FOR_ALGO => $algo_args );
        }

        $investigated_keys{$key_ref} = 1;

    } ## end foreach my $key ( @keys )

    if ( scalar @dnskey_rrs and scalar @results == scalar grep { $_->tag eq 'NO_RESPONSE' } @results) {
        push @results, info( KEY_SIZE_OK => {} );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec14

sub dnssec15 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my @query_types = qw{CDS CDNSKEY};
    my %cds_rrsets;
    my %cdnskey_rrsets;
    my %mismatch_cds_cdnskey;
    my %has_cds_no_cdnskey;
    my %has_cdnskey_no_cds;
    my %has_cds_and_cdnskey;

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;
    my %ip_already_processed;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results, map {
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              )
            } @query_types;
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results, map {
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              )
            } @query_types;
            next;
        }

        my $cds_p = $ns->query( $zone->name, 'CDS', { dnssec => 1, usevc => 0 } );
        if ( not $cds_p ) {
            next;
        }
        if ( not $cds_p->aa ) {
            next;
        }
        if ( $cds_p->rcode ne q{NOERROR} ) {
            next;
        }
        my @cds_records = $cds_p->get_records( q{CDS}, q{answer} );
        push @{ $cds_rrsets{ $ns->address->short } }, @cds_records;

        my $cdnskey_p = $ns->query( $zone->name, 'CDNSKEY', { dnssec => 1, usevc => 0 } );
        if ( not $cdnskey_p ) {
            next;
        }
        if ( not $cdnskey_p->aa ) {
            next;
        }
        if ( $cdnskey_p->rcode ne q{NOERROR} ) {
            next;
        }
        my @cdnskey_records = $cdnskey_p->get_records( q{CDNSKEY}, q{answer} );
        push @{ $cdnskey_rrsets{ $ns->address->short } }, @cdnskey_records;
    }
    undef %ip_already_processed;

    my $no_cds_cdnskey = 1;
    for my $ns_ip ( keys %cds_rrsets ) {
        if ( scalar @{ $cds_rrsets{ $ns_ip } } ) {
            $no_cds_cdnskey = 0;
        }
    }
    for my $ns_ip ( keys %cdnskey_rrsets ) {
        if ( scalar @{ $cdnskey_rrsets{ $ns_ip } } ) {
            $no_cds_cdnskey = 0;
        }
    }

    if ( $no_cds_cdnskey ) {
        push @results, info( DS15_NO_CDS_CDNSKEY => {} );
    }
    else {
        for my $ns_ip ( keys %cds_rrsets ) {

            if ( not exists $cdnskey_rrsets{ $ns_ip } ) {
                next;
            }

            if (
                    scalar @{ $cds_rrsets{ $ns_ip } }
                and not scalar @{ $cdnskey_rrsets{ $ns_ip } }
              )
            {
                $has_cds_no_cdnskey{ $ns_ip } = 1;
            }
            elsif (
                    scalar @{ $cdnskey_rrsets{ $ns_ip } }
                and not scalar @{ $cds_rrsets{ $ns_ip } }
              )
            {
                $has_cdnskey_no_cds{ $ns_ip } = 1;
            }
            elsif (
                    scalar @{ $cds_rrsets{ $ns_ip } }
                and scalar @{ $cdnskey_rrsets{ $ns_ip } }
              )
            {
                $has_cds_and_cdnskey{ $ns_ip } = 1;
            }
        }

        for my $ns_ip ( keys %cds_rrsets ) {
            if (
                    scalar @{ $cds_rrsets{ $ns_ip } }
                and exists $cdnskey_rrsets{ $ns_ip }
                and scalar @{ $cdnskey_rrsets{ $ns_ip } }
              )
            {
                #
                # Need a fix in Zonemaster::LDNS to prevent that trick
                #
                my (@ds, @dnskey);
                foreach my $cds ( @{ $cds_rrsets{ $ns_ip } } ) {
                    my $rr_string = $cds->string;
                    $rr_string =~ s/\s+CDS\s+/ DS /;
                    push @ds, Zonemaster::LDNS::RR->new( $rr_string );
                }
                foreach my $cdnskey ( @{ $cdnskey_rrsets{ $ns_ip } } ) {
                    my $rr_string = $cdnskey->string;
                    $rr_string =~ s/\s+CDNSKEY\s+/ DNSKEY /;
                    push @dnskey, Zonemaster::LDNS::RR->new( $rr_string );
                }
                foreach my $ds ( @ds ) {
                    my @matching_keys = grep { $ds->keytag == $_->keytag or ($ds->algorithm == 0 and $_->algorithm == 0)} @dnskey;
                    if ( not scalar @matching_keys ) {
                        $mismatch_cds_cdnskey{ $ns_ip } = 1;
                    }
                }
                foreach my $dnskey ( @dnskey ) {
                    my @matching_keys = grep { $dnskey->keytag == $_->keytag or ($dnskey->algorithm == 0 and $_->algorithm == 0)} @ds;
                    if ( not scalar @matching_keys ) {
                        $mismatch_cds_cdnskey{ $ns_ip } = 1;
                    }
                }
            }
        }

        if ( scalar keys %has_cds_no_cdnskey ) {
            push @results,
              info(
                DS15_HAS_CDS_NO_CDNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %has_cds_no_cdnskey )
                }
              );
        }

        if ( scalar keys %has_cdnskey_no_cds ) {
            push @results,
              info(
                DS15_HAS_CDNSKEY_NO_CDS => {
                    ns_ip_list => join( q{;}, sort keys %has_cdnskey_no_cds )
                }
              );
        }

        if ( scalar keys %has_cds_and_cdnskey ) {
            push @results,
              info(
                DS15_HAS_CDS_AND_CDNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %has_cds_and_cdnskey )
                }
              );
        }

        my $first_rrset_string = undef;
        for my $ns_ip ( keys %cds_rrsets ) {
            my $rrset_string;
            if ( scalar @{ $cds_rrsets{ $ns_ip } } ) {
                $rrset_string = join( "\n", sort map { $_->string } @{ $cds_rrsets{ $ns_ip } } );
            }
            else {
                $rrset_string = q{};
            }
            if ( not defined $first_rrset_string ) {
                $first_rrset_string = $rrset_string;
            }
            elsif ( $rrset_string ne $first_rrset_string ) {
                push @results, info( DS15_INCONSISTENT_CDS => {} );
                last;
            }
        }

        $first_rrset_string = undef;
        for my $ns_ip ( keys %cdnskey_rrsets ) {
            my $rrset_string;
            if ( scalar @{ $cdnskey_rrsets{ $ns_ip } } ) {
                $rrset_string = join( "\n", sort map { $_->string } @{ $cdnskey_rrsets{ $ns_ip } } );
            }
            else {
                $rrset_string = q{};
            }
            if ( not defined $first_rrset_string ) {
                $first_rrset_string = $rrset_string;
            }
            elsif ( $rrset_string ne $first_rrset_string ) {
                push @results, info( DS15_INCONSISTENT_CDNSKEY => {} );
                last;
            }
        }

        if ( scalar keys %mismatch_cds_cdnskey ) {
            push @results,
              info(
                DS15_MISMATCH_CDS_CDNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %mismatch_cds_cdnskey )
                }
              );
        }
    }
    
    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec15

sub dnssec16 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my @query_types = qw{CDS DNSKEY};
    my %cds_rrsets;
    my %dnskey_rrsets;
    my %mixed_delete_cds;
    my %delete_cds;
    my %no_dnskey_rrset;
    my %no_match_cds_with_dnskey;
    my %dnskey_not_signed_by_cds;
    my %cds_not_signed;
    my %cds_signed_by_unknown_dnskey;
    my %cds_invalid_rrsig;
    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;
    my %ip_already_processed;
    my $testing_time = time;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results, map {
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              )
            } @query_types;
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results, map {
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              )
            } @query_types;
            next;
        }

        my $cds_p = $ns->query( $zone->name, q{CDS}, { dnssec => 1, usevc => 0 } );
        if ( not $cds_p ) {
            next;
        }
        if ( not $cds_p->aa ) {
            next;
        }
        if ( $cds_p->rcode ne q{NOERROR} ) {
            next;
        }
        my @cds_records = $cds_p->get_records( q{CDS}, q{answer} );
        if ( not scalar @cds_records ) {
            next;
        }
        my @cds_rrsig_records = $cds_p->get_records( q{RRSIG} , q{answer} );
        push @{ $cds_rrsets{ $ns->address->short }{cds} }, @cds_records;
        push @{ $cds_rrsets{ $ns->address->short }{rrsig} }, @cds_rrsig_records;
        foreach my $cds ( @{ $cds_rrsets{ $ns->address->short }{cds} } ) {
            my $rr_string = $cds->string;
            $rr_string =~ s/\s+CDS\s+/ DS /;
            push @{ $cds_rrsets{ $ns->address->short }{ds} }, Zonemaster::LDNS::RR->new( $rr_string );
        }

        my $dnskey_p = $ns->query( $zone->name, q{DNSKEY}, { dnssec => 1, usevc => 0 } );
        if ( not $dnskey_p ) {
            next;
        }
        if ( not $dnskey_p->aa ) {
            next;
        }
        if ( $dnskey_p->rcode ne q{NOERROR} ) {
            next;
        }
        my @dnskey_records = $dnskey_p->get_records( q{DNSKEY}, q{answer} );
        if ( not scalar @dnskey_records ) {
            next;
        }
        my @dnskey_rrsig_records = $dnskey_p->get_records( q{RRSIG} , q{answer} );
        push @{ $dnskey_rrsets{ $ns->address->short }{dnskey} }, @dnskey_records;
        push @{ $dnskey_rrsets{ $ns->address->short }{rrsig} }, @dnskey_rrsig_records;
        $testing_time = $dnskey_p->timestamp;

    }
    undef %ip_already_processed;

    if ( scalar keys %cds_rrsets ) {
        for my $ns_ip ( keys %cds_rrsets ) {
            if ( not scalar @{ $cds_rrsets{ $ns_ip }{cds} } ) {
                next;
            }
            if ( scalar grep { $_->algorithm == 0 } @{ $cds_rrsets{ $ns_ip }{ds} } ) {
                if ( scalar grep { $_->algorithm != 0 } @{ $cds_rrsets{ $ns_ip }{ds} } ) {
                    $mixed_delete_cds{ $ns_ip } = 1;
                }
                else {
                    $delete_cds{ $ns_ip } = 1;
                }
                next;
            }
            if ( not defined $dnskey_rrsets{ $ns_ip }{dnskey} or not scalar @{ $dnskey_rrsets{ $ns_ip }{dnskey} } ) {
                $no_dnskey_rrset{ $ns_ip } = 1;
                next;
            }
            foreach my $ds ( @{ $cds_rrsets{ $ns_ip }{ds} } ) {
                if ( not scalar grep { $ds->keytag == $_->keytag } @{ $dnskey_rrsets{ $ns_ip }{dnskey} } ) {
                    push @{ $no_match_cds_with_dnskey{ $ds->keytag } }, $ns_ip;
                }
                elsif ( not scalar grep { $ds->keytag == $_->keytag } @{ $dnskey_rrsets{ $ns_ip }{rrsig} } ) {
                    push @{ $dnskey_not_signed_by_cds{ $ds->keytag } }, $ns_ip;
                }
            }
            if ( not scalar @{ $cds_rrsets{ $ns_ip }{rrsig} } ) {
                $cds_not_signed{ $ns_ip } = 1;
            }
            else {
                foreach my $rrsig ( @{ $cds_rrsets{ $ns_ip }{rrsig} } ) {
                    my $msg = q{};
                    my @matching_dnskeys = grep { $rrsig->keytag == $_->keytag } @{ $dnskey_rrsets{ $ns_ip }{dnskey} };
                    if ( not scalar @matching_dnskeys ) {
                        push @{ $cds_signed_by_unknown_dnskey{ $rrsig->keytag } }, $ns_ip;
                    }
                    elsif ( not $rrsig->verify_time( $cds_rrsets{ $ns_ip }{cds} , \@matching_dnskeys, $testing_time, $msg) ) {
                        push @{ $cds_invalid_rrsig{ $rrsig->keytag } }, $ns_ip;
                    }
                }
            }
        }

        if ( scalar keys %no_dnskey_rrset ) {
            push @results,
              info(
                DS16_CDS_WITHOUT_DNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %no_dnskey_rrset )
                }
              );
        }

        if ( scalar keys %mixed_delete_cds ) {
            push @results,
              info(
                DS16_MIXED_DELETE_CDS => {
                    ns_ip_list => join( q{;}, sort keys %mixed_delete_cds )
                }
              );
        }

        if ( scalar keys %delete_cds ) {
            push @results,
              info(
                DS16_DELETE_CDS => {
                    ns_ip_list => join( q{;}, sort keys %delete_cds )
                }
              );
        }

        if ( scalar keys %no_match_cds_with_dnskey ) {
            foreach my $keytag ( keys %no_match_cds_with_dnskey ) {
                push @results,
                  info(
                    DS16_CDS_MATCHES_NO_DNSKEY => {
                        keytag     => $keytag,
                        ns_ip_list => join( q{;}, uniq sort @{ $no_match_cds_with_dnskey{ $keytag } } )
                    }
                  );
            }
        }

        if ( scalar keys %dnskey_not_signed_by_cds ) {
            foreach my $keytag ( keys %dnskey_not_signed_by_cds ) {
                push @results,
                  info(
                    DS16_DNSKEY_NOT_SIGNED_BY_CDS => {
                        keytag     => $keytag,
                        ns_ip_list => join( q{;}, uniq sort @{ $dnskey_not_signed_by_cds{ $keytag } } )
                    }
                  );
            }
        }

        if ( scalar keys %cds_invalid_rrsig ) {
            foreach my $keytag ( keys %cds_invalid_rrsig ) {
                push @results,
                  info(
                    DS16_CDS_INVALID_RRSIG => {
                        keytag     => $keytag,
                        ns_ip_list => join( q{;}, uniq sort @{ $cds_invalid_rrsig{ $keytag } } )
                    }
                  );
            }
        }

        if ( scalar keys %cds_not_signed ) {
            push @results,
              info(
                DS16_CDS_UNSIGNED => {
                    ns_ip_list => join( q{;}, sort keys %cds_not_signed )
                }
              );
        }

        if ( scalar keys %cds_signed_by_unknown_dnskey ) {
            foreach my $keytag ( keys %cds_signed_by_unknown_dnskey ) {
                push @results,
                  info(
                    DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY => {
                        keytag     => $keytag,
                        ns_ip_list => join( q{;}, uniq sort @{ $cds_signed_by_unknown_dnskey{ $keytag } } )
                    }
                  );
            }
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec16

sub dnssec17 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );
    my @query_types = qw{CDNSKEY DNSKEY};
    my %cdnskey_rrsets;
    my %dnskey_rrsets;
    my %mixed_delete_cdnskey;
    my %delete_cdnskey;
    my %no_dnskey_rrset;
    my %no_match_cdnskey_with_dnskey;
    my %dnskey_not_signed_by_cdnskey;
    my %cdnskey_not_signed;
    my %cdnskey_signed_by_unknown_dnskey;
    my %cdnskey_invalid_rrsig;
    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;
    my %ip_already_processed;
    my $testing_time = time;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results, map {
              info(
                IPV6_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              )
            } @query_types;
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results, map {
              info(
                IPV4_DISABLED => {
                    ns     => $ns->string,
                    rrtype => $_,
                }
              )
            } @query_types;
            next;
        }

        my $cdnskey_p = $ns->query( $zone->name, q{CDNSKEY}, { dnssec => 1, usevc => 0 } );
        if ( not $cdnskey_p ) {
            next;
        }
        if ( not $cdnskey_p->aa ) {
            next;
        }
        if ( $cdnskey_p->rcode ne q{NOERROR} ) {
            next;
        }
        my @cdnskey_records = $cdnskey_p->get_records( q{CDNSKEY}, q{answer} );
        if ( not scalar @cdnskey_records ) {
            next;
        }
        my @cdnskey_rrsig_records = $cdnskey_p->get_records( q{RRSIG} , q{answer} );
        push @{ $cdnskey_rrsets{ $ns->address->short }{cdnskey} }, @cdnskey_records;
        push @{ $cdnskey_rrsets{ $ns->address->short }{rrsig} }, @cdnskey_rrsig_records;
        foreach my $cdnskey ( @{ $cdnskey_rrsets{ $ns->address->short }{cdnskey} } ) {
            my $rr_string = $cdnskey->string;
            $rr_string =~ s/\s+CDNSKEY\s+/ DNSKEY /;
            push @{ $cdnskey_rrsets{ $ns->address->short }{dnskey} }, Zonemaster::LDNS::RR->new( $rr_string );
        }

        my $dnskey_p = $ns->query( $zone->name, q{DNSKEY}, { dnssec => 1, usevc => 0 } );
        if ( not $dnskey_p ) {
            next;
        }
        if ( not $dnskey_p->aa ) {
            next;
        }
        if ( $dnskey_p->rcode ne q{NOERROR} ) {
            next;
        }
        my @dnskey_records = $dnskey_p->get_records( q{DNSKEY}, q{answer} );
        if ( not scalar @dnskey_records ) {
            next;
        }
        my @dnskey_rrsig_records = $dnskey_p->get_records( q{RRSIG} , q{answer} );
        push @{ $dnskey_rrsets{ $ns->address->short }{dnskey} }, @dnskey_records;
        push @{ $dnskey_rrsets{ $ns->address->short }{rrsig} }, @dnskey_rrsig_records;
        $testing_time = $dnskey_p->timestamp;

    }
    undef %ip_already_processed;

    if ( scalar keys %cdnskey_rrsets ) {
        for my $ns_ip ( keys %cdnskey_rrsets ) {
            if ( not scalar @{ $cdnskey_rrsets{ $ns_ip }{cdnskey} } ) {
                next;
            }
            if ( scalar grep { $_->algorithm == 0 } @{ $cdnskey_rrsets{ $ns_ip }{dnskey} } ) {
                if ( scalar grep { $_->algorithm != 0 } @{ $cdnskey_rrsets{ $ns_ip }{dnskey} } ) {
                    $mixed_delete_cdnskey{ $ns_ip } = 1;
                }
                else {
                    $delete_cdnskey{ $ns_ip } = 1;
                }
                next;
            }
            if ( not defined $dnskey_rrsets{ $ns_ip }{dnskey} or not scalar @{ $dnskey_rrsets{ $ns_ip }{dnskey} } ) {
                $no_dnskey_rrset{ $ns_ip } = 1;
                next;
            }
            foreach my $dnskey ( @{ $cdnskey_rrsets{ $ns_ip }{dnskey} } ) {
                if ( not scalar grep { $dnskey->keytag == $_->keytag } @{ $dnskey_rrsets{ $ns_ip }{dnskey} } ) {
                    push @{ $no_match_cdnskey_with_dnskey{ $dnskey->keytag } }, $ns_ip;
                }
                elsif ( not scalar grep { $dnskey->keytag == $_->keytag } @{ $dnskey_rrsets{ $ns_ip }{rrsig} } ) {
                    push @{ $dnskey_not_signed_by_cdnskey{ $dnskey->keytag } }, $ns_ip;
                }
            }
            if ( not scalar @{ $cdnskey_rrsets{ $ns_ip }{rrsig} } ) {
                $cdnskey_not_signed{ $ns_ip } = 1;
            }
            else {
                foreach my $rrsig ( @{ $cdnskey_rrsets{ $ns_ip }{rrsig} } ) {
                    my $msg = q{};
                    my @matching_dnskeys = grep { $rrsig->keytag == $_->keytag } @{ $dnskey_rrsets{ $ns_ip }{dnskey} };
                    if ( not scalar @matching_dnskeys ) {
                        push @{ $cdnskey_signed_by_unknown_dnskey{ $rrsig->keytag } }, $ns_ip;
                    }
                    elsif ( not $rrsig->verify_time( $cdnskey_rrsets{ $ns_ip }{cdnskey} , \@matching_dnskeys, $testing_time, $msg) ) {
                        push @{ $cdnskey_invalid_rrsig{ $rrsig->keytag } }, $ns_ip;
                    }
                }
            }
        }

        if ( scalar keys %no_dnskey_rrset ) {
            push @results,
              info(
                DS17_CDNSKEY_WITHOUT_DNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %no_dnskey_rrset )
                }
              );
        }

        if ( scalar keys %mixed_delete_cdnskey ) {
            push @results,
              info(
                DS17_MIXED_DELETE_CDNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %mixed_delete_cdnskey )
                }
              );
        }

        if ( scalar keys %delete_cdnskey ) {
            push @results,
              info(
                DS17_DELETE_CDNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %delete_cdnskey )
                }
              );
        }

        if ( scalar keys %no_match_cdnskey_with_dnskey ) {
            foreach my $keytag ( keys %no_match_cdnskey_with_dnskey ) {
                push @results,
                  info(
                    DS17_CDNSKEY_MATCHES_NO_DNSKEY => {
                        keytag     => $keytag,
                        ns_ip_list => join( q{;}, uniq sort @{ $no_match_cdnskey_with_dnskey{ $keytag } } )
                    }
                  );
            }
        }

        if ( scalar keys %dnskey_not_signed_by_cdnskey ) {
            foreach my $keytag ( keys %dnskey_not_signed_by_cdnskey ) {
                push @results,
                  info(
                    DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY => {
                        keytag     => $keytag,
                        ns_ip_list => join( q{;}, uniq sort @{ $dnskey_not_signed_by_cdnskey{ $keytag } } )
                    }
                  );
            }
        }

        if ( scalar keys %cdnskey_invalid_rrsig ) {
            foreach my $keytag ( keys %cdnskey_invalid_rrsig ) {
                push @results,
                  info(
                    DS17_CDNSKEY_INVALID_RRSIG => {
                        keytag     => $keytag,
                        ns_ip_list => join( q{;}, uniq sort @{ $cdnskey_invalid_rrsig{ $keytag } } )
                    }
                  );
            }
        }

        if ( scalar keys %cdnskey_not_signed ) {
            push @results,
              info(
                DS17_CDNSKEY_UNSIGNED => {
                    ns_ip_list => join( q{;}, sort keys %cdnskey_not_signed )
                }
              );
        }

        if ( scalar keys %cdnskey_signed_by_unknown_dnskey ) {
            foreach my $keytag ( keys %cdnskey_signed_by_unknown_dnskey ) {
                push @results,
                  info(
                    DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY => {
                        keytag     => $keytag,
                        ns_ip_list => join( q{;}, uniq sort @{ $cdnskey_signed_by_unknown_dnskey{ $keytag } } )
                    }
                  );
            }
        }
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub dnssec17

1;

=head1 NAME

Zonemaster::Engine::Test::DNSSEC - dnssec module showing the expected structure of Zonemaster test modules

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::DNSSEC->all($zone);

=head1 METHODS

=over

=item all($zone)

Runs the default set of tests and returns a list of log entries made by the tests.

=item metadata()

Returns a reference to a hash, the keys of which are the names of all test methods in the module, and the corresponding values are references to
lists with all the tags that the method can use in log entries.

=item tag_descriptions()

Returns a refernce to a hash with translation functions. Used by the builtin translation system.

=item policy()

Returns a reference to a hash with the default policy for the module. The keys
are message tags, and the corresponding values are their default log levels.

=item version()

Returns a version string for the module.

=back

=head1 TESTS

=over

=item dnssec01($zone)

Verifies that all DS records have digest types registered with IANA.

=item dnssec02($zone)

Verifies that all DS records have a matching DNSKEY.

=item dnssec03($zone)

Check iteration counts for NSEC3.

=item dnssec04($zone)

Checks the durations of the signatures for the DNSKEY and SOA RRsets.

=item dnssec05($zone)

Check DNSKEY algorithms.

=item dnssec06($zone)

Check for DNSSEC extra processing at child nameservers.

=item dnssec07($zone)

Check that both DS and DNSKEY are present.

=item dnssec08($zone)

Check that the DNSKEY RRset is signed.

=item dnssec09($zone)

Check that the SOA RRset is signed.

=item dnssec10($zone)

Check for the presence of either NSEC or NSEC3, with proper coverage and signatures.

=item dnssec11($zone)

Check that the delegation step from parent is properly signed.

=item dnssec13($zone)

Check that all DNSKEY algorithms are used to sign the zone.

=item dnssec14($zone)

Check for valid RSA DNSKEY key size

=item dnssec15($zone)

Check existence of CDS and CDNSKEY

=item dnssec16($zone)

Validate CDS

=item dnssec17($zone)

Validate CDNSKEY

=back

=cut
