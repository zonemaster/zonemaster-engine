package Zonemaster::Engine::Test::DNSSEC;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare( "v1.1.58" );

use Carp;
use List::Compare;
use List::MoreUtils qw[any uniq];
use List::Util qw[min];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;

use Zonemaster::LDNS::RR;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Constants qw[:algo :soa :ip];
use Zonemaster::Engine::Util qw[name should_run_test];
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::TestMethodsV2;

=head1 NAME

Zonemaster::Engine::Test::DNSSEC - Module implementing tests focused on DNSSEC

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::DNSSEC->all( $zone );

=cut

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

Readonly::Hash our %LDNS_digest_algorithms_supported => (
    1 => q{sha1},
    2 => q{sha256},
    3 => q{gost},
    4 => q{sha384},
);

=head1 METHODS

=over

=item all()

    my @logentry_array = all( $zone );

Runs the default set of tests for that module, i.e. between L<one and seventeen tests|/TESTS> depending on the tested zone.
If L<DNSSEC07|/dnssec07()> finds no DNSKEY nor DS RRs, no other test is run. If L<DNSSEC07|/dnssec07()> finds a DNSKEY RR, L<DNSSEC06|/dnssec06()> is run.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    my $has_dnskey = 1;
    if ( should_run_test( q{dnssec07} ) ) {
        push @results, $class->dnssec07( $zone );

        if ( any { $_->tag eq 'NEITHER_DNSKEY_NOR_DS' } @results ) {
            push @results,
              _emit_log(
                NOT_SIGNED => {
                    zone => q{} . $zone->name
                }
              );

            return @results;
        }

        $has_dnskey = any { $_->tag eq q{DNSKEY_BUT_NOT_DS} || $_->tag eq q{DNSKEY_AND_DS} } @results;
    }

    if ( should_run_test( q{dnssec01} ) ) {
        push @results, $class->dnssec01( $zone );
    }

    if ( should_run_test( q{dnssec02} ) ) {
        push @results, $class->dnssec02( $zone );
    }

    if ( should_run_test( q{dnssec03} ) ) {
        push @results, $class->dnssec03( $zone );
    }

    if ( should_run_test( q{dnssec04} ) ) {
        push @results, $class->dnssec04( $zone );
    }

    if ( should_run_test( q{dnssec05} ) ) {
        push @results, $class->dnssec05( $zone );
    }

    if ( should_run_test( q{dnssec06} ) ) {
        if ( $has_dnskey ) {
            push @results, $class->dnssec06( $zone );
        }
        else {
            push @results, _emit_log( ADDITIONAL_DNSKEY_SKIPPED => {} );
        }
    }

    if ( should_run_test( q{dnssec08} ) ) {
        push @results, $class->dnssec08( $zone );
    }

    if ( should_run_test( q{dnssec09} ) ) {
        push @results, $class->dnssec09( $zone );
    }

    if ( should_run_test( q{dnssec10} ) ) {
        push @results, $class->dnssec10( $zone );
    }

    if ( should_run_test( q{dnssec11} ) ) {
        push @results, $class->dnssec11( $zone );
    }

    if ( should_run_test( q{dnssec13} ) ) {
        push @results, $class->dnssec13( $zone );
    }

    if ( should_run_test( q{dnssec14} ) ) {
        push @results, $class->dnssec14( $zone );
    }

    if ( should_run_test( q{dnssec15} ) ) {
        push @results, $class->dnssec15( $zone );
    }

    if ( should_run_test( q{dnssec16} ) ) {
        push @results, $class->dnssec16( $zone );
    }

    if ( should_run_test( q{dnssec17} ) ) {
        push @results, $class->dnssec17( $zone );
    }

    if ( should_run_test( q{dnssec18} ) ) {
        push @results, $class->dnssec18( $zone );
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
        dnssec01 => [
            qw(
              DS01_DIGEST_NOT_SUPPORTED_BY_ZM
              DS01_DS_ALGO_DEPRECATED
              DS01_DS_ALGO_2_MISSING
              DS01_DS_ALGO_NOT_DS
              DS01_DS_ALGO_RESERVED
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        dnssec02 => [
            qw(
              DS02_ALGO_NOT_SUPPORTED_BY_ZM
              DS02_DNSKEY_NOT_FOR_ZONE_SIGNING
              DS02_DNSKEY_NOT_SEP
              DS02_DNSKEY_NOT_SIGNED_BY_ANY_DS
              DS02_NO_DNSKEY_FOR_DS
              DS02_NO_MATCHING_DNSKEY_RRSIG
              DS02_NO_MATCH_DS_DNSKEY
              DS02_NO_VALID_DNSKEY_FOR_ANY_DS
              DS02_RRSIG_NOT_VALID_BY_DNSKEY
              )
        ],
        dnssec03 => [
            qw(
              DS03_ERR_MULT_NSEC3
              DS03_ILLEGAL_HASH_ALGO
              DS03_ILLEGAL_ITERATION_VALUE
              DS03_ILLEGAL_SALT_LENGTH
              DS03_INCONSISTENT_HASH_ALGO
              DS03_INCONSISTENT_ITERATION
              DS03_INCONSISTENT_NSEC3_FLAGS
              DS03_INCONSISTENT_SALT_LENGTH
              DS03_LEGAL_EMPTY_SALT
              DS03_LEGAL_HASH_ALGO
              DS03_LEGAL_ITERATION_VALUE
              DS03_NO_DNSSEC_SUPPORT
              DS03_NO_NSEC3
              DS03_NSEC3_OPT_OUT_DISABLED
              DS03_NSEC3_OPT_OUT_ENABLED_NON_TLD
              DS03_NSEC3_OPT_OUT_ENABLED_TLD
              DS03_SERVER_NO_DNSSEC_SUPPORT
              DS03_SERVER_NO_NSEC3
              DS03_UNASSIGNED_FLAG_USED
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
              DS10_ALGO_NOT_SUPPORTED_BY_ZM
              DS10_ERR_MULT_NSEC
              DS10_ERR_MULT_NSEC3
              DS10_ERR_MULT_NSEC3PARAM
              DS10_EXPECTED_NSEC_NSEC3_MISSING
              DS10_HAS_NSEC
              DS10_HAS_NSEC3
              DS10_INCONSISTENT_NSEC
              DS10_INCONSISTENT_NSEC3
              DS10_INCONSISTENT_NSEC_NSEC3
              DS10_MIXED_NSEC_NSEC3
              DS10_NSEC3PARAM_GIVES_ERR_ANSWER
              DS10_NSEC3PARAM_MISMATCHES_APEX
              DS10_NSEC3PARAM_QUERY_RESPONSE_ERR
              DS10_NSEC3_ERR_TYPE_LIST
              DS10_NSEC3_MISMATCHES_APEX
              DS10_NSEC3_MISSING_SIGNATURE
              DS10_NSEC3_NODATA_MISSING_SOA
              DS10_NSEC3_NODATA_WRONG_SOA
              DS10_NSEC3_NO_VERIFIED_SIGNATURE
              DS10_NSEC3_RRSIG_EXPIRED
              DS10_NSEC3_RRSIG_NOT_YET_VALID
              DS10_NSEC3_RRSIG_NO_DNSKEY
              DS10_NSEC3_RRSIG_VERIFY_ERROR
              DS10_NSEC_ERR_TYPE_LIST
              DS10_NSEC_GIVES_ERR_ANSWER
              DS10_NSEC_MISMATCHES_APEX
              DS10_NSEC_MISSING_SIGNATURE
              DS10_NSEC_NODATA_MISSING_SOA
              DS10_NSEC_NODATA_WRONG_SOA
              DS10_NSEC_NO_VERIFIED_SIGNATURE
              DS10_NSEC_QUERY_RESPONSE_ERR
              DS10_NSEC_RRSIG_EXPIRED
              DS10_NSEC_RRSIG_NOT_YET_VALID
              DS10_NSEC_RRSIG_NO_DNSKEY
              DS10_NSEC_RRSIG_VERIFY_ERROR
              DS10_SERVER_NO_DNSSEC
              DS10_ZONE_NO_DNSSEC
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
              DS16_CDS_MATCHES_NON_SEP_DNSKEY
              DS16_CDS_MATCHES_NON_ZONE_DNSKEY
              DS16_CDS_MATCHES_NO_DNSKEY
              DS16_CDS_NOT_SIGNED_BY_CDS
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
              DS17_CDNSKEY_IS_NON_SEP
              DS17_CDNSKEY_IS_NON_ZONE
              DS17_CDNSKEY_MATCHES_NO_DNSKEY
              DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY
              DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY
              DS17_CDNSKEY_UNSIGNED
              DS17_CDNSKEY_WITHOUT_DNSKEY
              DS17_DELETE_CDNSKEY
              DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY
              DS17_MIXED_DELETE_CDNSKEY
              ),
        ],
        dnssec18 => [
            qw(
              DS18_NO_MATCH_CDS_RRSIG_DS
              DS18_NO_MATCH_CDNSKEY_RRSIG_DS
              ),
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    DNSSEC01 => sub {
        __x    # DNSSEC:DNSSEC01
          "Legal values for the DS hash digest algorithm";
    },
    DNSSEC02 => sub {
        __x    # DNSSEC:DNSSEC02
          "DS must match a valid DNSKEY in the child zone";
    },
    DNSSEC03 => sub {
        __x    # DNSSEC:DNSSEC03
          "Verify NSEC3 parameters";
    },
    DNSSEC04 => sub {
        __x    # DNSSEC:DNSSEC04
          "Check for too short or too long RRSIG lifetimes";
    },
    DNSSEC05 => sub {
        __x    # DNSSEC:DNSSEC05
          "Check for invalid DNSKEY algorithms";
    },
    DNSSEC06 => sub {
        __x    # DNSSEC:DNSSEC06
          "Verify DNSSEC additional processing";
    },
    DNSSEC07 => sub {
        __x    # DNSSEC:DNSSEC07
          "If DNSKEY at child, parent should have DS";
    },
    DNSSEC08 => sub {
        __x    # DNSSEC:DNSSEC08
          "Valid RRSIG for DNSKEY";
    },
    DNSSEC09 => sub {
        __x    # DNSSEC:DNSSEC09
          "RRSIG(SOA) must be valid and created by a valid DNSKEY";
    },
    DNSSEC10 => sub {
        __x    # DNSSEC:DNSSEC10
          "Zone contains NSEC or NSEC3 records";
    },
    DNSSEC11 => sub {
        __x    # DNSSEC:DNSSEC11
          "DS in delegation requires signed zone";
    },
    DNSSEC12 => sub {
        __x    # DNSSEC:DNSSEC12
          "Test for DNSSEC Algorithm Completeness";
    },
    DNSSEC13 => sub {
        __x    # DNSSEC:DNSSEC13
          "All DNSKEY algorithms used to sign the zone";
    },
    DNSSEC14 => sub {
        __x    # DNSSEC:DNSSEC14
          "Check for valid RSA DNSKEY key size";
    },
    DNSSEC15 => sub {
        __x    # DNSSEC:DNSSEC15
          "Existence of CDS and CDNSKEY";
    },
    DNSSEC16 => sub {
        __x    # DNSSEC:DNSSEC16
          "Validate CDS";
    },
    DNSSEC17 => sub {
        __x    # DNSSEC:DNSSEC17
          "Validate CDNSKEY";
    },
    DNSSEC18 => sub {
        __x    # DNSSEC:DNSSEC18
          "Validate trust from DS to CDS and CDNSKEY";
    },
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
    DNSKEY_AND_DS => sub {
        __x    # DNSSEC:DNSKEY_AND_DS
          '{parent} sent a DS record, and {child} a DNSKEY record.', @_;
    },
    DNSKEY_BUT_NOT_DS => sub {
        __x    # DNSSEC:DNSKEY_BUT_NOT_DS
          '{child} sent a DNSKEY record, but {parent} did not send a DS record.', @_;
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
    DS01_DIGEST_NOT_SUPPORTED_BY_ZM => sub {
        __x    # DNSSEC:DS01_DIGEST_NOT_SUPPORTED_BY_ZM
          'DS record for zone {domain} with keytag {keytag} was created by digest algorithm {ds_algo_num} '
          . '({ds_algo_mnemo}) which cannot be validated by this installation of Zonemaster. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS01_DS_ALGO_DEPRECATED => sub {
        __x    # DNSSEC:DS01_DS_ALGO_DEPRECATED
          'DS record for zone {domain} with keytag {keytag} was created by digest algorithm {ds_algo_num} '
          . '({ds_algo_mnemo}) which is deprecated. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS01_DS_ALGO_2_MISSING => sub {
        __x    # DNSSEC:DS01_DS_ALGO_2_MISSING
           'No DS record created by digest algorithm 2 (SHA-256) is present for zone {domain}.',
        @_;
    },
    DS01_DS_ALGO_NOT_DS => sub {
        __x    # DNSSEC:DS01_DS_ALGO_NOT_DS
          'DS record for zone {domain} with keytag {keytag} was created by digest algorithm {ds_algo_num} '
          . '({ds_algo_mnemo}) which is not meant for DS. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS01_DS_ALGO_RESERVED => sub {
        __x    # DNSSEC:DS01_DS_ALGO_RESERVED
          'DS record for zone {domain} with keytag {keytag} was created with an unassigned digest algorithm '
          . '(algorithm number {ds_algo_num}). '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS02_ALGO_NOT_SUPPORTED_BY_ZM => sub {
        __x    # DNSSEC:DS02_ALGO_NOT_SUPPORTED_BY_ZM
          'DNSKEY with tag {keytag} uses unsupported algorithm {algo_num} '
          . '({algo_mnemo}) by this installation of Zonemaster. Fetched from '
          . 'the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS02_DNSKEY_NOT_FOR_ZONE_SIGNING => sub {
        __x    # DNSSEC:DS02_DNSKEY_NOT_FOR_ZONE_SIGNING
          'Flags field of DNSKEY record with tag {keytag} has not ZONE bit set '
          . 'although DS with same tag is present in parent. Fetched from '
          . 'the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS02_DNSKEY_NOT_SEP => sub {
        __x    # DNSSEC:DS02_DNSKEY_NOT_SEP
          'Flags field of DNSKEY record with tag {keytag} has not SEP bit set '
          . 'although DS with same tag is present in parent. Fetched from '
          . 'the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS02_DNSKEY_NOT_SIGNED_BY_ANY_DS => sub {
        __x    # DNSSEC:DS02_DNSKEY_NOT_SIGNED_BY_ANY_DS
          'The DNSKEY RRset has not been signed by any DNSKEY matched by a DS record. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS02_NO_DNSKEY_FOR_DS => sub {
        __x    # DNSSEC:DS02_NO_DNSKEY_FOR_DS
          'The DNSKEY record with tag {keytag} that the DS refers to does not '
          . 'exist in the DNSKEY RRset. Fetched from the nameservers with IP '
          . '"{ns_ip_list}".',
          @_;
    },
    DS02_NO_MATCHING_DNSKEY_RRSIG => sub {
        __x    # DNSSEC:DS02_NO_MATCHING_DNSKEY_RRSIG
          'The DNSKEY RRset is not signed by the DNSKEY with tag {keytag} that '
          . 'the DS record refers to. Fetched from the nameservers with IP '
          . '"{ns_ip_list}".',
          @_;
    },
    DS02_NO_MATCH_DS_DNSKEY => sub {
        __x    # DNSSEC:DS02_NO_MATCH_DS_DNSKEY
          'The DS record does not match the DNSKEY with tag {keytag} by algorithm '
          . 'or digest. Fetched from the nameservers with IP "{ns_ip_list}".',
          @_;
    },
    DS02_NO_VALID_DNSKEY_FOR_ANY_DS => sub {
        __x    # DNSSEC:DS02_NO_VALID_DNSKEY_FOR_ANY_DS
          'There is no valid DNSKEY matched by any of the DS records. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS02_RRSIG_NOT_VALID_BY_DNSKEY => sub {
        __x    # DNSSEC:DS02_RRSIG_NOT_VALID_BY_DNSKEY
          'The DNSKEY RRset is signed with an RRSIG with tag {keytag} which cannot '
          . 'be validated by the matching DNSKEY. Fetched from the nameservers with IP '
          . 'addresses "{ns_ip_list}".',
          @_;
    },
    DS03_ERROR_RESPONSE_NSEC_QUERY => sub {
        __x    # DNSSEC:DS03_ERROR_RESPONSE_NSEC_QUERY
          'The following servers give erroneous response to NSEC query. Fetched from name servers "{ns_list}".', @_;
    },
    DS03_ERR_MULT_NSEC3 => sub {
        __x    # DNSSEC:DS03_ERR_MULT_NSEC3
          'Multiple NSEC3 records when one is expected. Fetched from name servers "{ns_list}".', @_;
    },
    DS03_ILLEGAL_HASH_ALGO => sub {
        __x    # DNSSEC:DS03_ILLEGAL_HASH_ALGO
          'The following servers respond with an illegal hash algorithm for NSEC3 ({algo_num}). '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_ILLEGAL_ITERATION_VALUE => sub {
        __x    # DNSSEC:DS03_ILLEGAL_ITERATION_VALUE
          'The following servers respond with the NSEC3 iteration value {int}. '
          . 'The recommended practice is to set this value to 0. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_ILLEGAL_SALT_LENGTH => sub {
        __x    # DNSSEC:DS03_ILLEGAL_SALT_LENGTH
          'The following servers respond with a non-empty salt in NSEC3 ({int} octets). '
          . 'The recommended practice is to use an empty salt. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_INCONSISTENT_HASH_ALGO => sub {
        __x    # DNSSEC:DS03_INCONSISTENT_HASH_ALGO
          'Inconsistent hash algorithm in NSEC3 in responses for the child zone from different name servers.', @_;
    },
    DS03_INCONSISTENT_ITERATION => sub {
        __x    # DNSSEC:DS03_INCONSISTENT_ITERATION
          'Inconsistent NSEC3 iteration value in responses for the child zone from different name servers.', @_;
    },
    DS03_INCONSISTENT_NSEC3_FLAGS => sub {
        __x    # DNSSEC:DS03_INCONSISTENT_NSEC3_FLAGS
          'Inconsistent NSEC3 flag list in responses for the child zone from different name servers.', @_;
    },
    DS03_INCONSISTENT_SALT_LENGTH => sub {
        __x    # DNSSEC:DS03_INCONSISTENT_SALT_LENGTH
          'Inconsistent salt length in NSEC3 in responses for the child zone from different name servers.', @_;
    },
    DS03_LEGAL_EMPTY_SALT => sub {
        __x    # DNSSEC:DS03_LEGAL_EMPTY_SALT
          'The following servers respond with a legal empty salt in NSEC3. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_LEGAL_HASH_ALGO => sub {
        __x    # DNSSEC:DS03_LEGAL_HASH_ALGO
          'The following servers respond with a legal hash algorithm in NSEC3. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_LEGAL_ITERATION_VALUE => sub {
        __x    # DNSSEC:DS03_LEGAL_ITERATION_VALUE
          'The following servers respond with NSEC3 iteration value set to zero (as recommended). '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_NO_DNSSEC_SUPPORT => sub {
        __x    # DNSSEC:DS03_NO_DNSSEC_SUPPORT
          'The zone is not DNSSEC signed or not properly DNSSEC signed. Testing for NSEC3 has been skipped. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_NO_NSEC3 => sub {
        __x    # DNSSEC:DS03_NO_NSEC3
          'The zone does not use NSEC3. Testing for NSEC3 has been skipped. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_NO_RESPONSE_NSEC_QUERY => sub {
        __x    # DNSSEC:DS03_NO_RESPONSE_NSEC_QUERY
        'The following servers do not respond to NSEC query. Fetched from name servers "{ns_list}".', @_;
    },
    DS03_NSEC3_OPT_OUT_DISABLED => sub {
        __x    # DNSSEC:DS03_NSEC3_OPT_OUT_DISABLED
          'The following servers respond with NSEC3 opt-out disabled (as recommended). '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_NSEC3_OPT_OUT_ENABLED_NON_TLD => sub {
        __x    # DNSSEC:DS03_NSEC3_OPT_OUT_ENABLED_NON_TLD
          'The following servers respond with NSEC3 opt-out enabled. '
          . 'The recommended practice is to disable opt-out. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_NSEC3_OPT_OUT_ENABLED_TLD => sub {
        __x    # DNSSEC:DS03_NSEC3_OPT_OUT_ENABLED_TLD
          'The following servers respond with NSEC3 opt-out enabled. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_SERVER_NO_DNSSEC_SUPPORT => sub {
        __x    # DNSSEC:DS03_SERVER_NO_DNSSEC_SUPPORT
          'The following name servers do not support DNSSEC or have not been properly configured. '
          . 'Testing for NSEC3 has been skipped on those servers. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_SERVER_NO_NSEC3 => sub {
        __x    # DNSSEC:DS03_SERVER_NO_NSEC3
          'The following name servers do not use NSEC3, but others do. '
          . 'Testing for NSEC3 has been skipped on the following servers. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS03_UNASSIGNED_FLAG_USED => sub {
        __x    # DNSSEC:DS03_UNASSIGNED_FLAG_USED
          'The following servers respond with an NSEC3 record where an unassigned flag is used (bit {int}). '
          . 'Fetched from name servers "{ns_list}".',
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
    DS10_ALGO_NOT_SUPPORTED_BY_ZM => sub {
        __x    # DNSSEC:DS10_ALGO_NOT_SUPPORTED_BY_ZM
          'DNSKEY with tag {keytag} uses unsupported algorithm {algo_num} '
          . '({algo_mnemo}) by this installation of Zonemaster. Fetched from '
          . 'name servers "{ns_ip_list}".',
          @_;
    },
    DS10_ERR_MULT_NSEC => sub {
        __x    # DNSSEC:DS10_ERR_MULT_NSEC
          'Multiple NSEC records when one is expected. Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_ERR_MULT_NSEC3 => sub {
        __x    # DNSSEC:DS10_ERR_MULT_NSEC3
          'Multiple NSEC3 records when one is expected. Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_ERR_MULT_NSEC3PARAM => sub {
        __x    # DNSSEC:DS10_ERR_MULT_NSEC3PARAM
          'Multiple NSEC3PARAM records when one is expected. Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_EXPECTED_NSEC_NSEC3_MISSING => sub {
        __x    # DNSSEC:DS10_EXPECTED_NSEC_NSEC3_MISSING
          'The server responded with DNSKEY but not with expected NSEC or NSEC3. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_HAS_NSEC => sub {
        __x    # DNSSEC:DS10_HAS_NSEC
          'The zone has NSEC records. Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_HAS_NSEC3 => sub {
        __x    # DNSSEC:DS10_HAS_NSEC3
          'The zone has NSEC3 records. Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_INCONSISTENT_NSEC => sub {
        __x    # DNSSEC:DS10_INCONSISTENT_NSEC
          'Inconsistent responses from zone with NSEC. Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_INCONSISTENT_NSEC3 => sub {
        __x    # DNSSEC:DS10_INCONSISTENT_NSEC3
          'Inconsistent responses from zone with NSEC3. Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_INCONSISTENT_NSEC_NSEC3 => sub {
        __x    # DNSSEC:DS10_INCONSISTENT_NSEC_NSEC3
          'The zone is inconsistent on NSEC and NSEC3. NSEC is fetched from name servers '
          . '"{ns_list_nsec}". NSEC3 is fetched from name servers "{ns_list_nsec3}".',
          @_;
    },
    DS10_MIXED_NSEC_NSEC3 => sub {
        __x    # DNSSEC:DS10_MIXED_NSEC_NSEC3
          'The zone responds with both NSEC and NSEC3, where only one of them is expected. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3PARAM_GIVES_ERR_ANSWER => sub {
        __x    # DNSSEC:DS10_NSEC3PARAM_GIVES_ERR_ANSWER
          'Unexpected DNS record in the answer section on an NSEC3PARAM query. Fetched '
          . 'from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3PARAM_MISMATCHES_APEX => sub {
        __x    # DNSSEC:DS10_NSEC3PARAM_MISMATCHES_APEX
          'The returned NSEC3PARAM record has an unexpected non-apex owner name. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3PARAM_QUERY_RESPONSE_ERR => sub {
        __x    # DNSSEC:DS10_NSEC3PARAM_QUERY_RESPONSE_ERR
          'No response or error in response on query for NSEC3PARAM. Fetched from '
          . 'name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3_ERR_TYPE_LIST => sub {
        __x    # DNSSEC:DS10_NSEC3_ERR_TYPE_LIST
          'NSEC3 record for the zone apex with incorrect type list. Fetched from '
          . 'name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3_MISMATCHES_APEX => sub {
        __x    # DNSSEC:DS10_NSEC3_MISMATCHES_APEX
          'The returned NSEC3 record unexpectedly does not match the zone name. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3_MISSING_SIGNATURE => sub {
        __x    # DNSSEC:DS10_NSEC3_MISSING_SIGNATURE
          'Missing RRSIG (signature) for the NSEC3 record or records. Fetched '
          . 'from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3_NODATA_MISSING_SOA => sub {
        __x    # DNSSEC:DS10_NSEC3_NODATA_MISSING_SOA
          'Missing SOA record in NODATA response with NSEC3. Fetched from '
          . 'name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3_NODATA_WRONG_SOA => sub {
        __x    # DNSSEC:DS10_NSEC3_NODATA_WRONG_SOA
          'Wrong owner name ("{domain}") on SOA record in NODATA response with NSEC3. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3_NO_VERIFIED_SIGNATURE => sub {
        __x    # DNSSEC:DS10_NSEC3_NO_VERIFIED_SIGNATURE
          'The RRSIG (signature) for the NSEC3 record cannot be verified. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3_RRSIG_EXPIRED => sub {
        __x    # DNSSEC:DS10_NSEC3_RRSIG_EXPIRED
          'The RRSIG (signature) with tag {keytag} for the NSEC3 record has expired. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3_RRSIG_NOT_YET_VALID => sub {
        __x    # DNSSEC:DS10_NSEC3_RRSIG_NOT_YET_VALID
          'The RRSIG (signature) with tag {keytag} for the NSEC3 record it not yet valid. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3_RRSIG_NO_DNSKEY => sub {
        __x    # DNSSEC:DS10_NSEC3_RRSIG_NO_DNSKEY
          'There is no DNSKEY record matching the RRSIG (signature) with tag {keytag} for '
          . 'the NSEC3 record. Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC3_RRSIG_VERIFY_ERROR => sub {
        __x    # DNSSEC:DS10_NSEC3_RRSIG_VERIFY_ERROR
          'The RRSIG (signature) with tag {keytag} for the NSEC3 record cannot be verified. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_ERR_TYPE_LIST => sub {
        __x    # DNSSEC:DS10_NSEC_ERR_TYPE_LIST
          'NSEC record for the zone apex with incorrect type list. Fetched from name '
          . 'servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_GIVES_ERR_ANSWER => sub {
        __x    # DNSSEC:DS10_NSEC_GIVES_ERR_ANSWER
          'Unexpected DNS record in the answer section on an NSEC query. Fetched from '
          . 'name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_MISMATCHES_APEX => sub {
        __x    # DNSSEC:DS10_NSEC_MISMATCHES_APEX
          'The returned NSEC record has an unexpected non-apex owner name. Fetched from '
          . 'name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_MISSING_SIGNATURE => sub {
        __x    # DNSSEC:DS10_NSEC_MISSING_SIGNATURE
          'Missing RRSIG (signature) for the NSEC record or records. Fetched from '
          . 'name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_NODATA_MISSING_SOA => sub {
        __x    # DNSSEC:DS10_NSEC_NODATA_MISSING_SOA
          'Missing SOA record in NODATA response with NSEC. Fetched from name '
          . 'servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_NODATA_WRONG_SOA => sub {
        __x    # DNSSEC:DS10_NSEC_NODATA_WRONG_SOA
          'Wrong owner name ("{domain}") on SOA record in NODATA response with NSEC. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_NO_VERIFIED_SIGNATURE => sub {
        __x    # DNSSEC:DS10_NSEC_NO_VERIFIED_SIGNATURE
          'There is no RRSIG (signature) for the NSEC record that can be verified. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_QUERY_RESPONSE_ERR => sub {
        __x    # DNSSEC:DS10_NSEC_QUERY_RESPONSE_ERR
          'No response or error in response on query for NSEC. Fetched from name '
          . 'servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_RRSIG_EXPIRED => sub {
        __x    # DNSSEC:DS10_NSEC_RRSIG_EXPIRED
          'The RRSIG (signature) with tag {keytag} for the NSEC record has expired. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_RRSIG_NOT_YET_VALID => sub {
        __x    # DNSSEC:DS10_NSEC_RRSIG_NOT_YET_VALID
          'The RRSIG (signature) with tag {keytag} for the NSEC record it not yet valid. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_RRSIG_NO_DNSKEY => sub {
        __x    # DNSSEC:DS10_NSEC_RRSIG_NO_DNSKEY
          'There is no DNSKEY record matching the RRSIG (signature) with tag {keytag} for '
          . 'the NSEC record. Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_NSEC_RRSIG_VERIFY_ERROR => sub {
        __x    # DNSSEC:DS10_NSEC_RRSIG_VERIFY_ERROR
          'The RRSIG (signature) with tag {keytag} for the NSEC record cannot be verified. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_SERVER_NO_DNSSEC => sub {
        __x    # DNSSEC:DS10_SERVER_NO_DNSSEC
          'The following name servers do not support DNSSEC or have not been properly '
          . 'configured. Testing for NSEC and NSEC3 has been skipped on these servers. '
          . 'Fetched from name servers "{ns_list}".',
          @_;
    },
    DS10_ZONE_NO_DNSSEC => sub {
        __x    # DNSSEC:DS10_ZONE_NO_DNSSEC
          'The zone is not DNSSEC signed or not properly DNSSEC signed. '
          . 'Testing for NSEC and NSEC3 has been skipped. Fetched from '
          . 'name servers "{ns_list}".',
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
        __x    # DNSSEC:DS15_HAS_CDNSKEY_NO_CDS
          'CDNSKEY RRset is found on nameservers that resolve to IP addresses '
          . '({ns_ip_list}), but no CDS RRset.',
          @_;
    },
    DS15_HAS_CDS_AND_CDNSKEY => sub {
        __x    # DNSSEC:DS15_HAS_CDS_AND_CDNSKEY
          'CDNSKEY and CDS RRsets are found on nameservers that resolve to IP addresses '
          . '({ns_ip_list}).',
          @_;
    },
    DS15_HAS_CDS_NO_CDNSKEY => sub {
        __x    # DNSSEC:DS15_HAS_CDS_NO_CDNSKEY
          'CDS RRset is found on nameservers that resolve to IP addresses '
          . '({ns_ip_list}), but no CDNSKEY RRset.',
          @_;
    },
    DS15_INCONSISTENT_CDNSKEY => sub {
        __x    # DNSSEC:DS15_INCONSISTENT_CDNSKEY
          'All servers do not have the same CDNSKEY RRset.', @_;
    },
    DS15_INCONSISTENT_CDS => sub {
        __x    # DNSSEC:DS15_INCONSISTENT_CDS
          'All servers do not have the same CDS RRset.', @_;
    },
    DS15_MISMATCH_CDS_CDNSKEY => sub {
        __x    # DNSSEC:DS15_MISMATCH_CDS_CDNSKEY
          'Both CDS and CDNSKEY RRsets are found on nameservers that resolve to IP '
          . 'addresses ({ns_ip_list}) but they do not match.',
          @_;
    },
    DS15_NO_CDS_CDNSKEY => sub {
        __x    # DNSSEC:DS15_NO_CDS_CDNSKEY
          'No CDS or CDNSKEY RRsets are found on any name server.', @_;
    },
    DS16_CDS_INVALID_RRSIG => sub {
        __x    # DNSSEC:DS16_CDS_INVALID_RRSIG
          'The CDS RRset is signed with an RRSIG with tag {keytag}, but the RRSIG does '
          . 'not match the DNSKEY with the same key tag. Fetched from the nameservers '
          . 'with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS16_CDS_MATCHES_NON_SEP_DNSKEY => sub {
        __x    # DNSSEC:DS16_CDS_MATCHES_NON_SEP_DNSKEY
          'The CDS record with tag {keytag} matches a DNSKEY record with SEP bit (bit 15) '
          . 'unset. Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS16_CDS_MATCHES_NON_ZONE_DNSKEY => sub {
        __x    # DNSSEC:DS16_CDS_MATCHES_NON_ZONE_DNSKEY
          'The CDS record with tag {keytag} matches a DNSKEY record with zone bit (bit 7) '
          . 'unset. Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS16_CDS_MATCHES_NO_DNSKEY => sub {
        __x    # DNSSEC:DS16_CDS_MATCHES_NO_DNSKEY
          'The CDS record with tag {keytag} does not match any DNSKEY record. Fetched '
          . 'from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS16_CDS_NOT_SIGNED_BY_CDS => sub {
        __x    # DNSSEC:DS16_CDS_NOT_SIGNED_BY_CDS
          'The CDS RRset is not signed by the DNSKEY that the CDS record with tag '
          . '{keytag} points to. Fetched from the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY => sub {
        __x    # DNSSEC:DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY
          'The CDS RRset is signed by RRSIG with tag {keytag} but that is not in the '
          . 'DNSKEY RRset. Fetched from the nameservers with P addresses "{ns_ip_list}".',
          @_;
    },
    DS16_CDS_UNSIGNED => sub {
        __x    # DNSSEC:DS16_CDS_UNSIGNED
          'The CDS RRset is not signed. Fetched from the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS16_CDS_WITHOUT_DNSKEY => sub {
        __x    # DNSSEC:DS16_CDS_WITHOUT_DNSKEY
          'A CDS RRset exists, but no DNSKEY record exists. Fetched from the '
          . 'nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS16_DELETE_CDS => sub {
        __x    # DNSSEC:DS16_DELETE_CDS
          'A single "delete" CDS record is found on the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS16_DNSKEY_NOT_SIGNED_BY_CDS => sub {
        __x    # DNSSEC:DS16_DNSKEY_NOT_SIGNED_BY_CDS
          'The DNSKEY RRset is not signed by the DNSKEY that the CDS record with tag '
          . '{keytag} points to. Fetched from the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS16_MIXED_DELETE_CDS => sub {
        __x    # DNSSEC:DS16_MIXED_DELETE_CDS
          'The CDS RRset is a mixture between "delete" record and other records. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_INVALID_RRSIG => sub {
        __x    # DNSSEC:DS17_CDNSKEY_INVALID_RRSIG
          'The CDNSKEY RRset is signed with an RRSIG with tag {keytag}, but the RRSIG does '
          . 'not match the DNSKEY with the same key tag. Fetched from the nameservers '
          . 'with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_IS_NON_SEP => sub {
        __x    # DNSSEC:DS17_CDNSKEY_IS_NON_SEP
          'The CDNSKEY record with tag {keytag} has the SEP bit (bit 15) unset. Fetched '
          . 'from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_IS_NON_ZONE => sub {
        __x    # DNSSEC:DS17_CDNSKEY_IS_NON_ZONE
          'The CDNSKEY record with tag {keytag} has the zone bit (bit 7) unset. Fetched '
          . 'from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_MATCHES_NO_DNSKEY => sub {
        __x    # DNSSEC:DS17_CDNSKEY_MATCHES_NO_DNSKEY
          'The CDNSKEY record with tag {keytag} does not match any DNSKEY record. Fetched '
          . 'from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY => sub {
        __x    # DNSSEC:DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY
          'The CDNSKEY RRset is not signed by the DNSKEY that the CDNSKEY record with tag '
          . '{keytag} points to. Fetched from the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY => sub {
        __x    # DNSSEC:DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY
          'The CDNSKEY RRset is signed by RRSIG with tag {keytag} but that is not in the '
          . 'DNSKEY RRset. Fetched from the nameservers with P addresses "{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_UNSIGNED => sub {
        __x    # DNSSEC:DS17_CDNSKEY_UNSIGNED
          'The CDNSKEY RRset is not signed. Fetched from the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS17_CDNSKEY_WITHOUT_DNSKEY => sub {
        __x    # DNSSEC:DS17_CDNSKEY_WITHOUT_DNSKEY
          'A CDNSKEY RRset exists, but no DNSKEY record exists. Fetched from the '
          . 'nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS17_DELETE_CDNSKEY => sub {
        __x    # DNSSEC:DS17_DELETE_CDNSKEY
          'A single "delete" CDNSKEY record is found on the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY => sub {
        __x    # DNSSEC:DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY
          'The DNSKEY RRset is not signed by the DNSKEY that the CDNSKEY record with tag '
          . '{keytag} points to. Fetched from the nameservers with IP addresses '
          . '"{ns_ip_list}".',
          @_;
    },
    DS17_MIXED_DELETE_CDNSKEY => sub {
        __x    # DNSSEC:DS17_MIXED_DELETE_CDNSKEY
          'The CDNSKEY RRset is a mixture between "delete" record and other records. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS18_NO_MATCH_CDS_RRSIG_DS => sub {
        __x    # DNSSEC:DS18_NO_MATCH_CDS_RRSIG_DS
          'The CDS RRset is not signed with a DNSKEY record that a DS record points to. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS18_NO_MATCH_CDNSKEY_RRSIG_DS => sub {
        __x    # DNSSEC:DS18_NO_MATCH_CDNSKEY_RRSIG_DS
          'The CDNSKEY RRset is not signed with a DNSKEY record that a DS record points to. '
          . 'Fetched from the nameservers with IP addresses "{ns_ip_list}".',
          @_;
    },
    DS_BUT_NOT_DNSKEY => sub {
        __x    # DNSSEC:DS_BUT_NOT_DNSKEY
          '{parent} sent a DS record, but {child} did not send a DNSKEY record.', @_;
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
    IPV4_DISABLED => sub {
        __x    # DNSSEC:IPV4_DISABLED
          'IPv4 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IPV6_DISABLED => sub {
        __x    # DNSSEC:IPV6_DISABLED
          'IPv6 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    KEY_DETAILS => sub {
        __x    # DNSSEC:KEY_DETAILS
          'Key with keytag {keytag} details : Size = {keysize}, Flags ({sep}, {rfc5011}).', @_;
    },
    KEY_SIZE_OK => sub {
        __x    # DNSSEC:KEY_SIZE_OK
          'All keys from the DNSKEY RRset have the correct size.', @_;
    },
    NEITHER_DNSKEY_NOR_DS => sub {
        __x    # DNSSEC:NEITHER_DNSKEY_NOR_DS
          'There are neither DS nor DNSKEY records for the zone.', @_;
    },
    NO_RESPONSE_DNSKEY => sub {
        __x    # DNSSEC:NO_RESPONSE_DNSKEY
          'Nameserver {ns} responded with no DNSKEY record(s).', @_;
    },
    NO_RESPONSE => sub {
        __x    # DNSSEC:NO_RESPONSE
          'Nameserver {ns} did not respond.', @_;
    },
    NOT_SIGNED => sub {
        __x    # DNSSEC:NOT_SIGNED
          'The zone is not signed with DNSSEC.', @_;
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
    TEST_CASE_END => sub {
        __x    # DNSSEC:TEST_CASE_END
          'TEST_CASE_END {testcase}.', @_;
    },
    TEST_CASE_START => sub {
        __x    # DNSSEC:TEST_CASE_START
          'TEST_CASE_START {testcase}.', @_;
    }
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
    return "$Zonemaster::Engine::Test::DNSSEC::VERSION";
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

sub _emit_log { my ( $tag, $argref ) = @_; return Zonemaster::Engine->logger->add( $tag, $argref, 'DNSSEC' ); }

=over

=item _ip_disabled_message()

    my $bool = _ip_disabled_message( $logentry_array_ref, $ns, @query_type_array );

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

=head1 TESTS

=over

=item dnssec01()

    my @logentry_array = dnssec01( $zone );

Runs the L<DNSSEC01 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec01.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec01 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC01';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    if ( $zone->name eq '.' and not Zonemaster::Engine::Recursor->has_fake_addresses( $zone->name->string ) ){
        return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
    }

    my %ds_records;
    if ( my $parent = $zone->parent ) {
        foreach my $ns ( @{ $parent->ns } ) {
            my $ns_ip;

            if ( Zonemaster::Engine::Recursor->has_fake_addresses( $zone->name->string ) ){
                if ( scalar %{$ns->fake_ds} == 0 ){
                    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
                }
                $ns_ip = "-";
            }
            else{
                $ns_ip = $ns->address->short;
            }

            if ( _ip_disabled_message( \@results, $ns, q{DS} ) ) {
                next;
            }

            my $ds_p = $ns->query( $zone->name, q{DS}, { usevc => 0, dnssec => 1 } );

            if ( not $ds_p or $ds_p->rcode ne q{NOERROR} or not $ds_p->has_edns or not $ds_p->do or not $ds_p->aa ) {
                next;
            }

            my @dss = $ds_p->get_records( q{DS}, q{answer} );

            my $can_continue = 0;
            foreach my $ds (@dss) {
                if ( $ds->owner eq $zone->name->fqdn ){
                    $can_continue = 1;
                    last;
                }
            }

            if ( not $can_continue ){
                next;
            }

            foreach my $ds (@dss) {
                push @{ $ds_records{$ds->digtype}{$ds->keytag} }, $ns_ip;
            }
        }

        my $algorithm2 = 0;
        if ( scalar keys %ds_records ){
            for my $ds_digtype ( keys %ds_records) {
                for my $ds_keytag ( keys %{ $ds_records{$ds_digtype} } ){
                    my $mnemonic = $digest_algorithms{ $ds_digtype };
                    if ( $ds_digtype == 0 ) {
                        push @results,
                          _emit_log(
                            DS01_DS_ALGO_NOT_DS => {
                                ns_ip_list    => join( q{;}, uniq sort @{ $ds_records{$ds_digtype}->{$ds_keytag} } ),
                                domain        => q{} . $zone->name,
                                keytag        => $ds_keytag,
                                ds_algo_num   => $ds_digtype,
                                ds_algo_mnemo => $mnemonic,
                            }
                          );
                    }
                    elsif ( $ds_digtype == 1 or $ds_digtype == 3 ) {
                        push @results,
                          _emit_log(
                            DS01_DS_ALGO_DEPRECATED => {
                                ns_ip_list => join( q{;}, uniq sort @{ $ds_records{$ds_digtype}->{$ds_keytag} } ),
                                domain     => q{} . $zone->name,
                                keytag     => $ds_keytag,
                                ds_algo_num   => $ds_digtype,
                                ds_algo_mnemo => $mnemonic,
                            }
                          );
                    }
                    elsif ( $ds_digtype >= 5 and $ds_digtype <= 255 ) {
                        push @results,
                          _emit_log(
                            DS01_DS_ALGO_RESERVED => {
                                ns_ip_list    => join( q{;}, uniq sort @{ $ds_records{$ds_digtype}->{$ds_keytag} } ),
                                domain        => q{} . $zone->name,
                                keytag        => $ds_keytag,
                                ds_algo_num   => $ds_digtype,
                            }
                          );
                    }
                    else {
                        $algorithm2++ if $ds_digtype == 2;
                    }

                    if ( not exists $LDNS_digest_algorithms_supported{$ds_digtype} ){
                        push @results,
                          _emit_log(
                            DS01_DIGEST_NOT_SUPPORTED_BY_ZM => {
                                ns_ip_list    => join( q{;}, uniq sort @{ $ds_records{$ds_digtype}->{$ds_keytag} } ),
                                domain        => q{} . $zone->name,
                                keytag        => $ds_keytag,
                                ds_algo_num   => $ds_digtype,
                                ds_algo_mnemo => $mnemonic,
                            }
                           );
                    }
                    else{
                        my $tmp_dnskey = Zonemaster::LDNS::RR->new( sprintf( '%s IN DNSKEY 256 3 13 gpqeIK2jbErZDUYZplEVOOo86PWm0KEkHtA4uZ1LSLGLJbzG7VTUcuVt dkDeIz/5+I5gtZMU0z5YW5a5r+KBRw==', $zone->name ) );
                        my $tmp_ds = $tmp_dnskey->ds( $LDNS_digest_algorithms_supported{$ds_digtype} );

                        if ( not $tmp_ds ){
                            push @results,
                              _emit_log(
                                DS01_DIGEST_NOT_SUPPORTED_BY_ZM => {
                                    ns_ip_list    => join( q{;}, uniq sort @{ $ds_records{$ds_digtype}->{$ds_keytag} } ),
                                    domain        => q{} . $zone->name,
                                    keytag        => $ds_keytag,
                                    ds_algo_num   => $ds_digtype,
                                    ds_algo_mnemo => $mnemonic,
                                }
                            );
                        }
                    }
                }
            }

            if ( not $algorithm2 ) {
                push @results,
                  _emit_log(
                    DS01_DS_ALGO_2_MISSING => {
                        domain     => q{} . $zone->name,
                    }
                  );
            }
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec01

=over

=item dnssec02()

    my @logentry_array = dnssec02( $zone );

Runs the L<DNSSEC02 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec02.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec02 {
    my ( $self, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC02';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my @ds_record;
    my %no_dnskey_for_ds;
    my %no_match_ds_dnskey;
    my %dnskey_not_for_zone_signing;
    my %dnskey_not_sep;
    my %no_matching_dnskey_rrsig;
    my %algo_not_supported_by_zm;
    my %rrsig_not_valid_by_dnskey;
    my %responding_child_ns;
    my %dnskey_matching_ds;
    my %has_dnskey_match_ds;
    my %has_rrsig_match_ds;
    my @ns_dnskey;
    my @ns_rrsig;
    my $continue_with_child_tests = 1;

    my $parent     = Zonemaster::Engine::TestMethods->method1( $zone );
    my @nss_parent = @{ $parent->ns };
    my %nss        = map { $_->name->string . '/' . $_->address->short => $_ } @nss_parent;
    my %ip_already_processed;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( _ip_disabled_message( \@results, $ns, q{DS} ) ) {
            next;
        }

        my $ds_p = $ns->query( $zone->name, q{DS}, { dnssec => 1 } );
        if ( not $ds_p or $ds_p->rcode ne q{NOERROR} or not $ds_p->has_edns or not $ds_p->do or not $ds_p->aa) {
            next;
        }
        my @tmp_ds_records = $ds_p->get_records_for_name( q{DS}, $zone->name->string, q{answer} );
        if ( not scalar @tmp_ds_records ) {
            next;
        }
        foreach my $tmp_ds_record ( @tmp_ds_records ) {
            if (
                not grep {
                          $tmp_ds_record->keytag == $_->keytag
                      and $tmp_ds_record->digtype == $_->digtype
                      and $tmp_ds_record->algorithm == $_->algorithm
                      and $tmp_ds_record->hexdigest eq $_->hexdigest
                } @ds_record
              )
            {
                push @ds_record, $tmp_ds_record;
            }
        }
    }
    undef %ip_already_processed;

    if ( not scalar @ds_record ) {
        $continue_with_child_tests = 0;
    }

    if ( $continue_with_child_tests ) {

        my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
        my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
        my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;
        my %ip_already_processed;

        for my $nss_key ( sort keys %nss ) {
            my $ns = $nss{$nss_key};

            next if exists $ip_already_processed{$ns->address->short};
            $ip_already_processed{$ns->address->short} = 1;

            if ( _ip_disabled_message( \@results, $ns, q{DNSKEY} ) ) {
                next;
            }

            my $dnskey_p = $ns->query( $zone->name, q{DNSKEY}, { dnssec => 1, usevc => 0 } );
            if ( not $dnskey_p or $dnskey_p->rcode ne q{NOERROR} or not $dnskey_p->has_edns or not $dnskey_p->do or not $dnskey_p->aa ) {
                next;
            }
            my @dnskey_rrs = $dnskey_p->get_records_for_name( q{DNSKEY}, $zone->name->string, q{answer} );
            if ( not scalar @dnskey_rrs ) {
                next;
            }

            $responding_child_ns{$ns->address->short} = 1;

            my @dnskey_rrsig = $dnskey_p->get_records_for_name( q{RRSIG}, $zone->name->string, q{answer} );

            %dnskey_matching_ds = ();

            foreach my $ds ( @ds_record ) {
                my $matching_dnskey = undef;
                my @matching_keytag_dnskeys = grep { $ds->keytag == $_->keytag } @dnskey_rrs;
                my $match_ds_dnskey = 0;

                foreach my $matching_keytag_dnskey ( @matching_keytag_dnskeys ) {
                    if ( exists $LDNS_digest_algorithms_supported{$ds->digtype()} ) {
                        my $tmp_ds = $matching_keytag_dnskey->ds($LDNS_digest_algorithms_supported{$ds->digtype()});

                        if ( not $tmp_ds or $tmp_ds->hexdigest() eq $ds->hexdigest() ) {
                            $matching_dnskey = $matching_keytag_dnskey;
                            $match_ds_dnskey = 1;
                            last;
                        }
                    }
                    else{
                        $matching_dnskey = $matching_keytag_dnskey;
                        $match_ds_dnskey = 1;
                        last;
                    }
                }

                if ( scalar @matching_keytag_dnskeys >= 1 and not $match_ds_dnskey) {
                    $matching_dnskey = shift @matching_keytag_dnskeys;
                }

                if ( not $matching_dnskey ) {
                    push @{ $no_dnskey_for_ds{$ds->keytag} }, $ns->address->short;
                }
                else {
                    if ( not $match_ds_dnskey ) {
                        push @{ $no_match_ds_dnskey{$ds->keytag} }, $ns->address->short;
                    }
                    if ( not $matching_dnskey->flags & 256 ) { # Bit 7 (ZONE)
                        push @{ $dnskey_not_for_zone_signing{$ds->keytag} }, $ns->address->short;
                        next;
                    }
                    if ( not $matching_dnskey->flags & 1 ) { # Bit 15 (SEP)
                        push @{ $dnskey_not_sep{$ds->keytag} }, $ns->address->short;
                    }

                    $dnskey_matching_ds{$matching_dnskey} = $matching_dnskey->keytag;
                    $has_dnskey_match_ds{$ns->address->short} = 1;

                    foreach my $dnskey ( keys %dnskey_matching_ds ) {
                        my @matching_keytag_rrsigs = grep { $dnskey_matching_ds{$dnskey} == $_->keytag } @dnskey_rrsig;
                        my $time = $dnskey_p->timestamp;
                        my $found_match = 0;

                        foreach my $rrsig_record ( @matching_keytag_rrsigs ) {
                            my $msg = q{};
                            # Does not work if we have a list with just a DNSKEY
                            #my @key_list = ( $matching_dnskey );
                            #my $validate = $rrsig_record->verify_time( \@key_list, \@key_list, $time, $msg );
                            my $validate = $rrsig_record->verify_time( \@dnskey_rrs, \@dnskey_rrs, $time, $msg );
                            if ( not $validate and $msg =~ /Unknown cryptographic algorithm/ ) {
                                push @{ $algo_not_supported_by_zm{$rrsig_record->keytag}{$rrsig_record->algorithm} }, $ns->address->short;
                            }
                            elsif ( not $validate ) {
                                push @{ $rrsig_not_valid_by_dnskey{$rrsig_record->keytag} }, $ns->address->short;
                            }
                            else {
                                $found_match++;
                            }
                        }

                        if ( not scalar @matching_keytag_rrsigs or not $found_match ) {
                            push @{ $no_matching_dnskey_rrsig{$dnskey_matching_ds{$dnskey}} }, $ns->address->short;
                        }
                        else {
                            $has_rrsig_match_ds{$ns->address->short} = 1;
                        }
                    }
                }
            }
        }
    }

    if ( scalar keys %no_dnskey_for_ds ) {
        push @results, map {
          _emit_log(
            DS02_NO_DNSKEY_FOR_DS => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $no_dnskey_for_ds{$_} } )
            }
          )
        } keys %no_dnskey_for_ds;
    }
    if ( scalar keys %no_match_ds_dnskey ) {
        push @results, map {
          _emit_log(
            DS02_NO_MATCH_DS_DNSKEY => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $no_match_ds_dnskey{$_} } )
            }
          )
        } keys %no_match_ds_dnskey;
    }
    if ( scalar keys %dnskey_not_for_zone_signing ) {
        push @results, map {
          _emit_log(
            DS02_DNSKEY_NOT_FOR_ZONE_SIGNING => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $dnskey_not_for_zone_signing{$_} } )
            }
          )
        } keys %dnskey_not_for_zone_signing;
    }
    if ( scalar keys %dnskey_not_sep ) {
        push @results, map {
          _emit_log(
            DS02_DNSKEY_NOT_SEP => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $dnskey_not_sep{$_} } )
            }
          )
        } keys %dnskey_not_sep;
    }
    if ( scalar keys %no_matching_dnskey_rrsig ) {
        push @results, map {
          _emit_log(
            DS02_NO_MATCHING_DNSKEY_RRSIG => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $no_matching_dnskey_rrsig{$_} } )
            }
          )
        } keys %no_matching_dnskey_rrsig;
    }
    if ( scalar keys %algo_not_supported_by_zm ) {
        foreach my $keytag ( keys %algo_not_supported_by_zm ) {
            push @results, map {
              _emit_log(
                DS02_ALGO_NOT_SUPPORTED_BY_ZM => {
                    keytag     => $keytag,
                    algo_num   => $_,
                    algo_mnemo => $algo_properties{$_}{mnemonic},
                    ns_ip_list => join( q{;}, uniq sort @{ $algo_not_supported_by_zm{$keytag}{$_} } )
                }
              )
            } keys %{ $algo_not_supported_by_zm{$keytag} };
        }
    }
    if ( scalar keys %rrsig_not_valid_by_dnskey ) {
        push @results, map {
          _emit_log(
            DS02_RRSIG_NOT_VALID_BY_DNSKEY => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $rrsig_not_valid_by_dnskey{$_} } )
            }
          )
        } keys %rrsig_not_valid_by_dnskey;
    }

    foreach my $ns_ip ( keys %responding_child_ns ) {
        push @ns_dnskey, $ns_ip if not exists $has_dnskey_match_ds{$ns_ip};
        push @ns_rrsig, $ns_ip if not exists $has_rrsig_match_ds{$ns_ip};
    }

    if ( scalar @ns_dnskey ) {
        push @results,
            _emit_log(
              DS02_NO_VALID_DNSKEY_FOR_ANY_DS => {
                ns_ip_list => join( q{;}, sort @ns_dnskey )
              }
            )
    }
    else {
        if ( scalar @ns_rrsig ) {
            push @results,
              _emit_log(
                DS02_DNSKEY_NOT_SIGNED_BY_ANY_DS => {
                    ns_ip_list => join( q{;}, sort @ns_rrsig )
                }
              )
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec02

=over

=item dnssec03()

    my @logentry_array = dnssec03( $zone );

Runs the L<DNSSEC03 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec03.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec03 {
    my ( $self, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC03';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my @responds_without_dnskey;
    my @responds_with_dnskey;
    my @responds_without_nsec3;
    my @responds_with_nsec3;
    my @multiple_nsec3;
    my %hash_algorithm;
    my %nsec3_flags;
    my %nsec3_iterations;
    my %nsec3_salt_length;
    my @no_response_nsec_query;
    my @error_response_nsec_query;

    my %ip_already_processed;

    foreach my $ns ( @{ Zonemaster::Engine::TestMethods->method4and5( $zone ) } ){
        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( _ip_disabled_message( \@results, $ns, qw{DNSKEY NSEC} ) ) {
            next;
        }

        my $p1 = $ns->query( $zone->name, q{DNSKEY}, { dnssec => 1 } );

        if ( not $p1 or $p1->rcode ne q{NOERROR} or not $p1->aa ) {
            next;
        }

        if ( not scalar $p1->get_records_for_name( q{DNSKEY}, $zone->name, q{answer} ) ) {
            push @responds_without_dnskey, $ns;
            next;
        }

        push @responds_with_dnskey, $ns;

        my $p2 = $ns->query( $zone->name, q{NSEC}, { dnssec => 1 } );

        if ( not $p2 ) {
            push @no_response_nsec_query, $ns;
            next;
        }

        if ( $p2->rcode ne q{NOERROR} or not $p2->aa ) {
            push @error_response_nsec_query, $ns;
            next;
        }

        my @nsec3_rrs = $p2->get_records( q{NSEC3}, q{authority} );

        if ( not scalar @nsec3_rrs ) {
            push @responds_without_nsec3, $ns;
            next;
        }
        else {
            push @responds_with_nsec3, $ns;

            if ( scalar @nsec3_rrs > 1 ) {
                push @multiple_nsec3, $ns;
            }

            my $rr = ( @nsec3_rrs )[0];

            push @{ $hash_algorithm{$rr->algorithm} }, $ns if defined $rr->algorithm;
            push @{ $nsec3_flags{$rr->flags} }, $ns if defined $rr->flags;
            push @{ $nsec3_iterations{$rr->iterations} }, $ns if defined $rr->iterations;

            if ( defined $rr->salt ) {
                push @{ $nsec3_salt_length{length unpack('H*', $rr->salt)} }, $ns;
            }
            else {
                push @{ $nsec3_salt_length{0} }, $ns;
            }
        }
    }

    if ( not scalar @responds_with_dnskey and scalar @responds_without_dnskey ) {
        push @results,
            _emit_log(
              DS03_NO_DNSSEC_SUPPORT => {
                ns_list => join( q{;}, sort @responds_without_dnskey )
              }
            );
    }

    if ( scalar @responds_with_dnskey and scalar @responds_without_dnskey ) {
        push @results,
            _emit_log(
              DS03_SERVER_NO_DNSSEC_SUPPORT => {
                ns_list => join( q{;}, sort @responds_without_dnskey )
              }
            );
    }

    if ( not scalar @responds_with_nsec3 and scalar @responds_without_nsec3 ) {
        push @results,
            _emit_log(
              DS03_NO_NSEC3 => {
                ns_list => join( q{;}, sort @responds_without_nsec3 )
              }
            );
    }

    if ( scalar @responds_with_nsec3 and scalar @responds_without_nsec3 ) {
        push @results,
            _emit_log(
              DS03_SERVER_NO_NSEC3 => {
                ns_list => join( q{;}, sort @responds_without_nsec3 )
              }
            );
    }

    if ( scalar @multiple_nsec3 ) {
        push @results,
            _emit_log(
              DS03_ERR_MULT_NSEC3 => {
                ns_list => join( q{;}, sort @multiple_nsec3 )
              }
            );
    }

    if ( scalar keys %hash_algorithm ) {
        if ( scalar keys %hash_algorithm > 1 ) {
            push @results,
                _emit_log(
                  DS03_INCONSISTENT_HASH_ALGO => {}
                );
        }

        foreach my $algo ( keys %hash_algorithm ) {
            if ( $algo eq '1' ) {
                push @results,
                    _emit_log(
                      DS03_LEGAL_HASH_ALGO => {
                        ns_list => join( q{;}, sort @{ $hash_algorithm{$algo} } )
                      }
                    );
            }
            else {
                push @results,
                    _emit_log(
                      DS03_ILLEGAL_HASH_ALGO => {
                        ns_list => join( q{;}, sort @{ $hash_algorithm{$algo} } ),
                        algo_num => $algo
                      }
                    );
            }
        }
    }

    if ( scalar keys %nsec3_flags ) {
        if ( scalar keys %nsec3_flags > 1 ) {
            push @results,
                _emit_log(
                  DS03_INCONSISTENT_NSEC3_FLAGS => {}
                );
        }

        foreach my $flag ( keys %nsec3_flags ) {
            # Makes a list of bit positions corresponding to flags that are set, where the most-significant bit is 0.
            my @bit_positions = grep { $flag & (1 << ( 7 - $_ ) ) } (0..7);

            foreach my $bit ( grep { $_ >= 0 and $_ <= 6 } @bit_positions ) {
                push @results,
                    _emit_log(
                      DS03_UNASSIGNED_FLAG_USED => {
                        ns_list => join( q{;}, sort @{ $nsec3_flags{$flag} } ),
                        int => $bit
                      }
                    );
            }

            if ( grep { $_ == 7 } @bit_positions ) {
                # Note below that the Public Suffix List check is not yet implemented.
                if ( $zone->name eq '.' or $zone->name->next_higher eq '.' ) {
                    push @results,
                        _emit_log(
                          DS03_NSEC3_OPT_OUT_ENABLED_TLD => {
                            ns_list => join( q{;}, sort @{ $nsec3_flags{$flag} } )
                          }
                        );
                }
                else {
                    push @results,
                        _emit_log(
                          DS03_NSEC3_OPT_OUT_ENABLED_NON_TLD => {
                            ns_list => join( q{;}, sort @{ $nsec3_flags{$flag} } )
                          }
                        );
                }
            }
            else {
                push @results,
                    _emit_log(
                      DS03_NSEC3_OPT_OUT_DISABLED => {
                        ns_list => join( q{;}, sort @{ $nsec3_flags{$flag} } )
                      }
                );
            }
        }
    }

    if ( scalar keys %nsec3_iterations ) {
        if ( scalar keys %nsec3_iterations > 1 ) {
            push @results,
                _emit_log(
                  DS03_INCONSISTENT_ITERATION => {}
                );
        }

        foreach my $iter ( keys %nsec3_iterations ) {
            if ( $iter eq '0' ) {
                push @results,
                    _emit_log(
                      DS03_LEGAL_ITERATION_VALUE => {
                        ns_list => join( q{;}, sort @{ $nsec3_iterations{$iter} } )
                      }
                    );
            }
            else {
                push @results,
                    _emit_log(
                      DS03_ILLEGAL_ITERATION_VALUE => {
                        ns_list => join( q{;}, sort @{ $nsec3_iterations{$iter} } ),
                        int => $iter
                      }
                    );
            }
        }
    }

    if ( scalar keys %nsec3_salt_length ) {
        if ( scalar keys %nsec3_salt_length > 1 ) {
            push @results,
                _emit_log(
                  DS03_INCONSISTENT_SALT_LENGTH => {}
                );
        }

        foreach my $salt ( keys %nsec3_salt_length ) {
            if ( $salt eq '0' ) {
                push @results,
                    _emit_log(
                      DS03_LEGAL_EMPTY_SALT => {
                        ns_list => join( q{;}, sort @{ $nsec3_salt_length{$salt} } )
                      }
                    );
            }
            else {
                push @results,
                    _emit_log(
                      DS03_ILLEGAL_SALT_LENGTH => {
                        ns_list => join( q{;}, sort @{ $nsec3_salt_length{$salt} } ),
                        int => $salt
                      }
                    );
            }
        }
    }

    if ( scalar @no_response_nsec_query ) {
        push @results,
            _emit_log(
              DS03_NO_RESPONSE_NSEC_QUERY => {
                ns_list => join( q{;}, sort @no_response_nsec_query )
              }
            );
    }

    if ( scalar @error_response_nsec_query ) {
        push @results,
            _emit_log(
              DS03_ERROR_RESPONSE_NSEC_QUERY => {
                ns_list => join( q{;}, sort @error_response_nsec_query )
              }
            );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec03

=over

=item dnssec04()

    my @logentry_array = dnssec04( $zone );

Runs the L<DNSSEC04 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec04.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec04 {
    my ( $self, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC04';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $dnskey_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $dnskey_p ) {
        return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
    }
    my @keys     = $dnskey_p->get_records( 'DNSKEY', 'answer' );
    my @key_sigs = $dnskey_p->get_records( 'RRSIG',  'answer' );

    my $soa_p = $zone->query_one( $zone->name, 'SOA', { dnssec => 1 } );
    if ( not $soa_p ) {
        return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
    }
    my @soas     = $soa_p->get_records( 'SOA',   'answer' );
    my @soa_sigs = $soa_p->get_records( 'RRSIG', 'answer' );

    foreach my $sig ( @key_sigs, @soa_sigs ) {
        push @results,
          _emit_log(
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
            $result_remaining = _emit_log(
                RRSIG_EXPIRED => {
                    expiration => $sig->expiration,
                    keytag     => $sig->keytag,
                    types      => $sig->typecovered,
                }
            );
        }
        elsif ( $remaining < ( $remaining_short_limit ) ) {
            $result_remaining = _emit_log(
                REMAINING_SHORT => {
                    duration => $remaining,
                    keytag   => $sig->keytag,
                    types    => $sig->typecovered,
                }
            );
        }
        elsif ( $remaining > ( $remaining_long_limit ) ) {
            $result_remaining = _emit_log(
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
            $result_duration = _emit_log(
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
              _emit_log(
                DURATION_OK => {
                    duration => $duration,
                    keytag   => $sig->keytag,
                    types    => $sig->typecovered,
                }
              );
        }
    } ## end foreach my $sig ( @key_sigs...)

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec04

=over

=item dnssec05()

    my @logentry_array = dnssec05( $zone );

Runs the L<DNSSEC05 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec05.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec05 {
    my ( $self, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC05';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;

    for my $key ( sort keys %nss ) {
        my $ns = $nss{$key};

        if ( _ip_disabled_message( \@results, $ns, q{DNSKEY} ) ) {
            next;
        }

        my $dnskey_p = $ns->query( $zone->name, 'DNSKEY', { dnssec => 1 } );
        if ( not $dnskey_p ) {
            push @results, _emit_log( NO_RESPONSE => { ns => $ns->string } );
            next;
        }

        my @keys = $dnskey_p->get_records( 'DNSKEY', 'answer' );
        if ( not @keys ) {
            push @results, _emit_log( NO_RESPONSE_DNSKEY => { ns => $ns->string } );
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
                push @results, _emit_log( ALGORITHM_DEPRECATED => $algo_args );
            }
            elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_RESERVED ) {
                push @results, _emit_log( ALGORITHM_RESERVED => $algo_args );
            }
            elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_UNASSIGNED ) {
                push @results, _emit_log( ALGORITHM_UNASSIGNED => $algo_args );
            }
            elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_PRIVATE ) {
                push @results, _emit_log( ALGORITHM_PRIVATE => $algo_args );
            }
            elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_NOT_ZONE_SIGN ) {
                push @results, _emit_log( ALGORITHM_NOT_ZONE_SIGN => $algo_args );
            }
            elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_NOT_RECOMMENDED ) {
                push @results, _emit_log( ALGORITHM_NOT_RECOMMENDED => $algo_args );
            }
            else {
                push @results, _emit_log( ALGORITHM_OK => $algo_args );
                if ( $key->flags & 256 ) {    # This is a Key
                    push @results,
                      _emit_log(
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

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec05

=over

=item dnssec06()

    my @logentry_array = dnssec06( $zone );

Runs the L<DNSSEC06 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec06.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec06 {
    my ( $self, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC06';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $dnskey_aref = $zone->query_all( $zone->name, 'DNSKEY', { dnssec => 1 } );
    foreach my $dnskey_p ( @{$dnskey_aref} ) {
        next if not $dnskey_p;

        my @keys = $dnskey_p->get_records( 'DNSKEY', 'answer' );
        my @sigs = $dnskey_p->get_records( 'RRSIG',  'answer' );
        if ( @sigs > 0 and @keys > 0 ) {
            push @results,
              _emit_log(
                EXTRA_PROCESSING_OK => {
                    server => $dnskey_p->answerfrom,
                    keys   => scalar( @keys ),
                    sigs   => scalar( @sigs ),
                }
              );
        }
        elsif ( $dnskey_p->rcode eq q{NOERROR} and ( @sigs == 0 or @keys == 0 ) ) {
            push @results,
              _emit_log(
                EXTRA_PROCESSING_BROKEN => {
                    server => $dnskey_p->answerfrom,
                    keys   => scalar( @keys ),
                    sigs   => scalar( @sigs )
                }
              );
        }
    } ## end foreach my $dnskey_p ( @{$dnskey_aref...})

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec06

=over

=item dnssec07()

    my @logentry_array = dnssec07( $zone );

Runs the L<DNSSEC07 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec07.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec07 {
    my ( $self, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC07';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    if ( not $zone->parent ) {
        return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
    }
    my $dnskey_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $dnskey_p ) {
        return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
    }
    my ( $dnskey ) = $dnskey_p->get_records( 'DNSKEY', 'answer' );

    my $ds_p = $zone->parent->query_one( $zone->name, 'DS', { dnssec => 1 } );
    if ( not $ds_p ) {
        return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
    }
    my ( $ds ) = $ds_p->get_records( 'DS', 'answer' );

    if ( $dnskey and not $ds ) {
        push @results,
          _emit_log(
            DNSKEY_BUT_NOT_DS => {
                child  => $dnskey_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }
    elsif ( $dnskey and $ds ) {
        push @results,
          _emit_log(
            DNSKEY_AND_DS => {
                child  => $dnskey_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }
    elsif ( not $dnskey and $ds ) {
        push @results,
          _emit_log(
            DS_BUT_NOT_DNSKEY => {
                child  => $dnskey_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }
    else {
        push @results,
          _emit_log(
            NEITHER_DNSKEY_NOR_DS => {
                child  => $dnskey_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec07

=over

=item dnssec08()

    my @logentry_array = dnssec08( $zone );

Runs the L<DNSSEC08 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec08.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec08 {
    my ( $self, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC08';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
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

        if ( _ip_disabled_message( \@results, $ns, q{DNSKEY} ) ) {
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
          _emit_log(
            DS08_MISSING_RRSIG_IN_RESPONSE => {
                ns_ip_list => join( q{;}, uniq sort @dnskey_without_rrsig )
            }
          );
    }
    if ( scalar keys %dnskey_rrsig_not_yet_valid ) {
        push @results, map {
          _emit_log(
            DS08_DNSKEY_RRSIG_NOT_YET_VALID => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $dnskey_rrsig_not_yet_valid{$_} } )
            }
          )
        } keys %dnskey_rrsig_not_yet_valid;
    }
    if ( scalar keys %dnskey_rrsig_expired ) {
        push @results, map {
          _emit_log(
            DS08_DNSKEY_RRSIG_EXPIRED => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $dnskey_rrsig_expired{$_} } )
            }
          )
        } keys %dnskey_rrsig_expired;
    }
    if ( scalar keys %no_matching_dnskey ) {
        push @results, map {
          _emit_log(
            DS08_NO_MATCHING_DNSKEY => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $no_matching_dnskey{$_} } )
            }
          )
        } keys %no_matching_dnskey;
    }
    if ( scalar keys %rrsig_not_valid_by_dnskey ) {
        push @results, map {
          _emit_log(
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
              _emit_log(
                DS08_ALGO_NOT_SUPPORTED_BY_ZM => {
                    keytag     => $keytag,
                    algo_num   => $_,
                    algo_mnemo => $algo_properties{$_}{mnemonic},
                    ns_ip_list => join( q{;}, uniq sort @{ $algo_not_supported_by_zm{$keytag}{$_} } )
                }
              )
            } keys %{ $algo_not_supported_by_zm{$keytag} };
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec08

=over

=item dnssec09()

    my @logentry_array = dnssec09( $zone );

Runs the L<DNSSEC09 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec09.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec09 {
    my ( $self, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC09';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
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

        if ( _ip_disabled_message( \@results, $ns, q{DNSKEY} ) ) {
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
        my @rrsig_records = $soa_p->get_records( q{RRSIG}, q{answer} );

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
          _emit_log(
            DS09_MISSING_RRSIG_IN_RESPONSE => {
                ns_ip_list => join( q{;}, uniq sort @soa_without_rrsig )
            }
          );
    }
    if ( scalar keys %soa_rrsig_not_yet_valid ) {
        push @results, map {
          _emit_log(
            DS09_SOA_RRSIG_NOT_YET_VALID => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $soa_rrsig_not_yet_valid{$_} } )
            }
          )
        } keys %soa_rrsig_not_yet_valid;
    }
    if ( scalar keys %soa_rrsig_expired ) {
        push @results, map {
          _emit_log(
            DS09_SOA_RRSIG_EXPIRED => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $soa_rrsig_expired{$_} } )
            }
          )
        } keys %soa_rrsig_expired;
    }
    if ( scalar keys %no_matching_dnskey ) {
        push @results, map {
          _emit_log(
            DS09_NO_MATCHING_DNSKEY => {
                keytag     => $_,
                ns_ip_list => join( q{;}, uniq sort @{ $no_matching_dnskey{$_} } )
            }
          )
        } keys %no_matching_dnskey;
    }
    if ( scalar keys %rrsig_not_valid_by_dnskey ) {
        push @results, map {
          _emit_log(
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
              _emit_log(
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

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec09

=over

=item dnssec10()

    my @logentry_array = dnssec10( $zone );

Runs the L<DNSSEC10 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec10.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec10 {
    my ( $class, $zone ) = @_;
    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC10';

    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $type_soa = q{SOA};
    my $type_dnskey = q{DNSKEY};
    my $type_nsec = q{NSEC};
    my $type_nsec3 = q{NSEC3};
    my $type_nsec3param = q{NSEC3PARAM};
    my @query_types = ( $type_dnskey, $type_nsec, $type_nsec3param );

    my %algo_not_supported_by_zm;
    my ( @erroneous_multiple_nsec, @erroneous_multiple_nsec3, @erroneous_multiple_nsec3param );
    my ( @nsec_in_answer, @nsec3param_in_answer );
    my ( @nsec_incorrect_type_list, @nsec3_incorrect_type_list );
    my ( @nsec_mismatches_apex, @nsec3_mismatches_apex, @nsec3param_mismatches_apex );
    my ( @nsec_missing_signature, @nsec3_missing_signature );
    my ( %nsec_nodata_wrong_soa, %nsec3_nodata_wrong_soa );
    my ( @nsec_nodata_missing_soa, @nsec3_nodata_missing_soa );
    my ( @nsec_erroneous_answer, @nsec3param_erroneous_answer );
    my ( @nsec_nsec3_nodata, @nsec3param_nsec_nodata );
    my ( %nsec_rrsig_verify_error, %nsec3_rrsig_verify_error );
    my ( %nsec_rrsig_expired, %nsec3_rrsig_expired );
    my ( %nsec_rrsig_not_yet_valid, %nsec3_rrsig_not_yet_valid );
    my ( %nsec_rrsig_no_dnskey, %nsec3_rrsig_no_dnskey );
    my ( @nsec_rrsig_verified, @nsec3_rrsig_verified );
    my ( @nsec_response_error, @nsec3param_response_error );
    my ( @with_dnskey, @without_dnskey );

    my @all_ns = uniq grep { $_->isa('Zonemaster::Engine::Nameserver') } (
                @{ Zonemaster::Engine::TestMethodsV2->get_del_ns_names_and_ips( $zone ) // [] },
                @{ Zonemaster::Engine::TestMethodsV2->get_zone_ns_names_and_ips( $zone ) // [] }
              );

    my @ignored_nss;
    my %nss;
    push @{ $nss{$_->address->short} }, $_ for @all_ns;

    my $testing_time = time;

    for my $ns_ip ( keys %nss ) {
        my $ns = $nss{$ns_ip}[0];
        my @all_ns_for_ip = @{ $nss{$ns_ip} };

        if ( _ip_disabled_message( \@results, $ns, @query_types ) ) {
            push @ignored_nss, @all_ns_for_ip;
            next;
        }

        my $dnskey_p = $ns->query( $zone->name, $type_dnskey, { dnssec => 1 } );

        if ( not $dnskey_p or $dnskey_p->rcode ne q{NOERROR} or not $dnskey_p->aa ) {
            push @ignored_nss, @all_ns_for_ip;
            next;
        }

        my @dnskey_records = $dnskey_p->get_records_for_name( $type_dnskey, $zone->name->string, q{answer} );

        if ( not scalar @dnskey_records ) {
            push @without_dnskey, @all_ns_for_ip;
            next;
        }

        push @with_dnskey, @all_ns_for_ip;

        my $nsec_p = $ns->query( $zone->name, $type_nsec, { dnssec => 1 } );

        if ( not $nsec_p or $nsec_p->rcode ne q{NOERROR} or not $nsec_p->aa ) {
            push @nsec_response_error, @all_ns_for_ip;
        }
        elsif ( $nsec_p->answer ) {
            if ( scalar $nsec_p->get_records( $type_nsec, q{answer} ) ) {
                push @nsec_in_answer, @all_ns_for_ip;

                if ( scalar $nsec_p->get_records( $type_nsec, q{answer} ) > 1 ) {
                    push @erroneous_multiple_nsec, @all_ns_for_ip;
                }
                elsif ( ($nsec_p->get_records( $type_nsec, q{answer} ))[0]->owner ne $zone->name ) {
                    push @nsec_mismatches_apex, @all_ns_for_ip;
                }
            }
            else {
                push @nsec_erroneous_answer, @all_ns_for_ip;
            }
        }
        elsif ( not $nsec_p->answer and scalar $nsec_p->get_records( $type_nsec3, q{authority} ) ) {
            my @nsec3_rrs = $nsec_p->get_records( $type_nsec3, q{authority} );

            push @nsec_nsec3_nodata, @all_ns_for_ip;

            unless ( scalar $nsec_p->get_records( $type_soa, q{authority} ) ) {
                push @nsec3_nodata_missing_soa, @all_ns_for_ip;
            }
            elsif ( ($nsec_p->get_records( $type_soa, q{authority} ))[0]->owner ne $zone->name ) {
                push @{ $nsec3_nodata_wrong_soa{$zone->name} }, @all_ns_for_ip;
            }

            if ( scalar @nsec3_rrs > 1 ) {
                push @erroneous_multiple_nsec3, @all_ns_for_ip;
            }
            else {
                unless ( $nsec3_rrs[0]->hash_name( $zone->name ) eq lc( @{ name($nsec3_rrs[0]->owner)->labels }[0] ) ) {
                    push @nsec3_mismatches_apex, @all_ns_for_ip;
                }
                else {
                    my @mandatory_typelist = qw( SOA NS DNSKEY NSEC3PARAM RRSIG );
                    my @forbidden_typelist = qw( NSEC NSEC3 );
                    my %typelist = %{ $nsec3_rrs[0]->typehref };

                    foreach my $type ( @mandatory_typelist ) {
                        if ( not exists $typelist{$type} ) {
                            push @nsec3_incorrect_type_list, @all_ns_for_ip;
                            last;
                        }
                    }

                    foreach my $type ( @forbidden_typelist ) {
                        if ( exists $typelist{$type} ) {
                            push @nsec3_incorrect_type_list, @all_ns_for_ip;
                            last;
                        }
                    }
                }

                my @nsec3_rrsig_rrs = grep { $_->typecovered eq q{NSEC3} } $nsec_p->get_records_for_name( q{RRSIG}, $nsec3_rrs[0]->name );

                unless ( scalar @nsec3_rrsig_rrs ) {
                    push @nsec3_missing_signature, @all_ns_for_ip;
                }
                else {
                    foreach my $rr ( @nsec3_rrsig_rrs ) {
                        my @matching_dnskeys = grep { $rr->keytag == $_->keytag } @dnskey_records;

                        unless ( scalar @matching_dnskeys ) {
                            push @{ $nsec3_rrsig_no_dnskey{$rr->keytag} }, @all_ns_for_ip;
                        }
                        elsif ( $rr->expiration < $testing_time ) {
                            push @{ $nsec3_rrsig_expired{$rr->keytag} }, @all_ns_for_ip;
                        }
                        elsif ( $rr->inception > $testing_time ) {
                            push @{ $nsec3_rrsig_not_yet_valid{$rr->keytag} }, @all_ns_for_ip;
                        }
                        else {
                            my $i = 1;
                            foreach my $dnskey ( @matching_dnskeys ) {
                                my $msg = q{};
                                my $validated = $rr->verify_time( [grep { name( $_->name ) eq name( $rr->name ) } @nsec3_rrs], [ $dnskey ], $testing_time, $msg );

                                if ( $validated ) {
                                    push @nsec3_rrsig_verified, @all_ns_for_ip;
                                    last;
                                }

                                if ( $i >= scalar @matching_dnskeys ) {
                                    if ( $msg =~ /Unknown cryptographic algorithm/ ) {
                                        push @{ $algo_not_supported_by_zm{$dnskey->keytag}{$dnskey->algorithm} }, @all_ns_for_ip;
                                    }
                                    else {
                                        push @{ $nsec3_rrsig_verify_error{$dnskey->keytag} }, @all_ns_for_ip;
                                    }
                                }

                                $i++;
                            }
                        }
                    }
                }
            }
        }

        my $nsec3param_p = $ns->query( $zone->name, $type_nsec3param, { dnssec => 1 } );

        if ( not $nsec3param_p or $nsec3param_p->rcode ne q{NOERROR} or not $nsec3param_p->aa ) {
            push @nsec3param_response_error, @all_ns_for_ip;
        }
        elsif ( $nsec3param_p->answer ) {
            if ( scalar $nsec3param_p->get_records( $type_nsec3param, q{answer} ) ) {
                push @nsec3param_in_answer, @all_ns_for_ip;

                if ( scalar $nsec3param_p->get_records( $type_nsec3param, q{answer} ) > 1 ) {
                    push @erroneous_multiple_nsec3param, @all_ns_for_ip;
                }
                elsif ( ($nsec3param_p->get_records( $type_nsec3param, q{answer} ))[0]->owner ne $zone->name ) {
                    push @nsec3param_mismatches_apex, @all_ns_for_ip;
                }
            }
            else {
                push @nsec3param_erroneous_answer, @all_ns_for_ip;
            }
        }
        elsif ( not $nsec3param_p->answer and scalar $nsec3param_p->get_records( $type_nsec, q{authority} ) ) {
            my @nsec_rrs = $nsec3param_p->get_records( $type_nsec, q{authority} );

            push @nsec3param_nsec_nodata, @all_ns_for_ip;

            unless ( scalar $nsec3param_p->get_records( $type_soa, q{authority} ) ) {
                push @nsec_nodata_missing_soa, @all_ns_for_ip;
            }
            elsif ( ($nsec3param_p->get_records( $type_soa, q{authority} ))[0]->owner ne $zone->name ) {
                push @{ $nsec_nodata_wrong_soa{$zone->name} }, @all_ns_for_ip;
            }

            if ( scalar @nsec_rrs > 1 ) {
                push @erroneous_multiple_nsec, @all_ns_for_ip;
            }
            else {
                unless ( $nsec_rrs[0]->owner eq $zone->name ) {
                    push @nsec_mismatches_apex, @all_ns_for_ip;
                }
                else {
                    my @mandatory_typelist = qw( SOA NS DNSKEY NSEC RRSIG );
                    my @forbidden_typelist = qw( NSEC3PARAM NSEC3 );
                    my %typelist = %{ $nsec_rrs[0]->typehref };

                    foreach my $type ( @mandatory_typelist ) {
                        if ( not exists $typelist{$type} ) {
                            push @nsec_incorrect_type_list, @all_ns_for_ip;
                            last;
                        }
                    }

                    foreach my $type ( @forbidden_typelist ) {
                        if ( exists $typelist{$type} ) {
                            push @nsec_incorrect_type_list, @all_ns_for_ip;
                            last;
                        }
                    }
                }

                my @nsec_rrsig_rrs = grep { $_->typecovered eq q{NSEC} } $nsec3param_p->get_records_for_name( q{RRSIG}, $nsec_rrs[0]->name );

                unless ( scalar @nsec_rrsig_rrs ) {
                    push @nsec_missing_signature, @all_ns_for_ip;
                }
                else {
                    foreach my $rr ( @nsec_rrsig_rrs ) {
                        my @matching_dnskeys = grep { $rr->keytag == $_->keytag } @dnskey_records;

                        unless ( scalar @matching_dnskeys ) {
                            push @{ $nsec_rrsig_no_dnskey{$rr->keytag} }, @all_ns_for_ip;
                        }
                        elsif ( $rr->expiration < $testing_time ) {
                            push @{ $nsec_rrsig_expired{$rr->keytag} }, @all_ns_for_ip;
                        }
                        elsif ( $rr->inception > $testing_time ) {
                            push @{ $nsec_rrsig_not_yet_valid{$rr->keytag} }, @all_ns_for_ip;
                        }
                        else {
                            my $i = 1;
                            foreach my $dnskey ( @matching_dnskeys ) {
                                my $msg = q{};
                                my $validated = $rr->verify_time( [grep { name( $_->name ) eq name( $rr->name ) } @nsec_rrs], [ $dnskey ], $testing_time, $msg );

                                if ( $validated ) {
                                    push @nsec_rrsig_verified, @all_ns_for_ip;
                                    last;
                                }

                                if ( $i >= scalar @matching_dnskeys ) {
                                    if ( $msg =~ /Unknown cryptographic algorithm/ ) {
                                        push @{ $algo_not_supported_by_zm{$dnskey->keytag}{$dnskey->algorithm} }, @all_ns_for_ip;
                                    }
                                    else {
                                        push @{ $nsec_rrsig_verify_error{$dnskey->keytag} }, @all_ns_for_ip;
                                    }
                                }

                                $i++;
                            }
                        }
                    }
                }
            }
        }
    }

    if ( scalar @erroneous_multiple_nsec ) {
        push @results,
          _emit_log(
            DS10_ERR_MULT_NSEC => {
                ns_list => join( q{;}, uniq sort @erroneous_multiple_nsec )
            }
          );
    }

    if ( scalar @erroneous_multiple_nsec3 ) {
        push @results,
          _emit_log(
            DS10_ERR_MULT_NSEC3 => {
                ns_list => join( q{;}, uniq sort @erroneous_multiple_nsec3 )
            }
          );
    }

    if ( scalar @erroneous_multiple_nsec3param ) {
        push @results,
          _emit_log(
            DS10_ERR_MULT_NSEC3PARAM => {
                ns_list => join( q{;}, uniq sort @erroneous_multiple_nsec3param )
            }
          );
    }

    my $lc = List::Compare->new( \@nsec_in_answer, \@nsec3param_nsec_nodata );
    my @diff = $lc->get_symmetric_difference;
    my @union = uniq map { $_->string } ( @nsec3param_in_answer, @nsec_nsec3_nodata );
    my $lc2 = List::Compare->new( \@diff, \@union );
    my @final_diff = $lc2->get_symmetric_difference;

    if ( scalar @diff and scalar @final_diff ) {
        push @results,
          _emit_log(
            DS10_INCONSISTENT_NSEC => {
                ns_list => join( q{;}, uniq sort @final_diff )
            }
          );
    }

    $lc = List::Compare->new( \@nsec3param_in_answer, \@nsec_nsec3_nodata );
    @diff = $lc->get_symmetric_difference;
    @union = uniq map { $_->string } ( @nsec_in_answer, @nsec3param_nsec_nodata );
    $lc2 = List::Compare->new( \@diff, \@union );
    @final_diff = $lc2->get_symmetric_difference;

    if ( scalar @diff and scalar @final_diff ) {
        push @results,
          _emit_log(
            DS10_INCONSISTENT_NSEC3 => {
                ns_list => join( q{;}, uniq sort @final_diff )
            }
          );
    }

    $lc = List::Compare->new( [ @nsec3param_in_answer, @nsec_nsec3_nodata ], [ @nsec_in_answer, @nsec3param_nsec_nodata ] );
    my @intersection = $lc->get_intersection;

    if ( @intersection ) {
        push @results,
          _emit_log(
            DS10_MIXED_NSEC_NSEC3 => {
                ns_list => join( q{;}, uniq sort @intersection )
            }
          );
    }

    if ( ( scalar @nsec_in_answer or @nsec3param_nsec_nodata ) and not scalar @nsec3param_in_answer and not scalar @nsec_nsec3_nodata ) {
        push @results,
          _emit_log(
            DS10_HAS_NSEC => {
                ns_list => join( q{;}, uniq sort ( @nsec_in_answer, @nsec3param_nsec_nodata ) )
            }
          );
    }

    if ( ( scalar @nsec3param_in_answer or @nsec_nsec3_nodata ) and not scalar @nsec_in_answer and not scalar @nsec3param_nsec_nodata ) {
        push @results,
          _emit_log(
            DS10_HAS_NSEC3 => {
                ns_list => join( q{;}, uniq sort ( @nsec3param_in_answer, @nsec_nsec3_nodata ) )
            }
          );
    }

    @union = ( @nsec3param_in_answer, @nsec_nsec3_nodata );
    my @second_union = ( @nsec_in_answer, @nsec3param_nsec_nodata );
    $lc = List::Compare->new( \@union, \@second_union );
    my @first = $lc->get_unique;
    my @second = $lc->get_complement;

    if ( scalar @first and scalar @second ) {
        push @results,
          _emit_log(
            DS10_INCONSISTENT_NSEC_NSEC3 => {
                ns_list => join( q{;}, uniq sort ( @union, @second_union ) )
            }
          );
    }

    if ( scalar @nsec_incorrect_type_list ) {
        push @results,
          _emit_log(
            DS10_NSEC_ERR_TYPE_LIST => {
                ns_list => join( q{;}, uniq sort @nsec_incorrect_type_list )
            }
          );
    }

    if ( scalar @nsec_mismatches_apex ) {
        push @results,
          _emit_log(
            DS10_NSEC_MISMATCHES_APEX => {
                ns_list => join( q{;}, uniq sort @nsec_mismatches_apex )
            }
          );
    }

    if ( scalar keys %nsec_nodata_wrong_soa ) {
        push @results, map {
              _emit_log(
                DS10_NSEC_NODATA_WRONG_SOA => {
                    domain => $_,
                    ns_list => join( q{;}, uniq sort @{ $nsec_nodata_wrong_soa{$_} } )
                }
              )
            } keys %nsec_nodata_wrong_soa;
    }

    if ( scalar @nsec_nodata_missing_soa ) {
        push @results,
          _emit_log(
            DS10_NSEC_NODATA_MISSING_SOA => {
                ns_list => join( q{;}, uniq sort @nsec_nodata_missing_soa )
            }
          );
    }

    if ( scalar @nsec_erroneous_answer ) {
        push @results,
          _emit_log(
            DS10_NSEC_GIVES_ERR_ANSWER => {
                ns_list => join( q{;}, uniq sort @nsec_erroneous_answer )
            }
          );
    }

    if ( scalar @nsec_response_error ) {
        push @results,
          _emit_log(
            DS10_NSEC_QUERY_RESPONSE_ERR => {
                ns_list => join( q{;}, uniq sort @nsec_response_error )
            }
          );
    }

    if ( scalar @nsec3_incorrect_type_list ) {
        push @results,
          _emit_log(
            DS10_NSEC3_ERR_TYPE_LIST => {
                ns_list => join( q{;}, uniq sort @nsec3_incorrect_type_list )
            }
          );
    }

    if ( scalar @nsec3_mismatches_apex ) {
        push @results,
          _emit_log(
            DS10_NSEC3_MISMATCHES_APEX => {
                ns_list => join( q{;}, uniq sort @nsec3_mismatches_apex )
            }
          );
    }

    if ( scalar keys %nsec3_nodata_wrong_soa ) {
        push @results, map {
              _emit_log(
                DS10_NSEC3_NODATA_WRONG_SOA => {
                    domain => $_,
                    ns_list => join( q{;}, uniq sort @{ $nsec3_nodata_wrong_soa{$_} } )
                }
              )
            } keys %nsec3_nodata_wrong_soa;
    }

    if ( scalar @nsec3_nodata_missing_soa ) {
        push @results,
          _emit_log(
            DS10_NSEC3_NODATA_MISSING_SOA => {
                ns_list => join( q{;}, uniq sort @nsec3_nodata_missing_soa )
            }
          );
    }

    if ( scalar @nsec3param_erroneous_answer ) {
        push @results,
          _emit_log(
            DS10_NSEC3PARAM_GIVES_ERR_ANSWER => {
                ns_list => join( q{;}, uniq sort @nsec3param_erroneous_answer )
            }
          );
    }

    if ( scalar @nsec3param_mismatches_apex ) {
        push @results,
          _emit_log(
            DS10_NSEC3PARAM_MISMATCHES_APEX => {
                ns_list => join( q{;}, uniq sort @nsec3param_mismatches_apex )
            }
          );
    }

    if ( scalar @nsec3param_response_error ) {
        push @results,
          _emit_log(
            DS10_NSEC3PARAM_QUERY_RESPONSE_ERR => {
                ns_list => join( q{;}, uniq sort @nsec3param_response_error )
            }
          );
    }

    if ( scalar @nsec_missing_signature ) {
        push @results,
          _emit_log(
            DS10_NSEC_MISSING_SIGNATURE => {
                ns_list => join( q{;}, uniq sort @nsec_missing_signature )
            }
          );
    }

    if ( scalar @nsec3_missing_signature ) {
        push @results,
          _emit_log(
            DS10_NSEC3_MISSING_SIGNATURE => {
                ns_list => join( q{;}, uniq sort @nsec3_missing_signature )
            }
          );
    }

    if ( scalar keys %nsec_rrsig_no_dnskey ) {
        push @results, map {
              _emit_log(
                DS10_NSEC_RRSIG_NO_DNSKEY => {
                    keytag => $_,
                    ns_list => join( q{;}, uniq sort @{ $nsec_rrsig_no_dnskey{$_} } )
                }
              )
            } keys %nsec_rrsig_no_dnskey;
    }

    if ( scalar keys %nsec_rrsig_expired ) {
        push @results, map {
              _emit_log(
                DS10_NSEC_RRSIG_EXPIRED => {
                    keytag => $_,
                    ns_list => join( q{;}, uniq sort @{ $nsec_rrsig_expired{$_} } )
                }
              )
            } keys %nsec_rrsig_expired;
    }

    if ( scalar keys %nsec_rrsig_not_yet_valid ) {
        push @results, map {
              _emit_log(
                DS10_NSEC_RRSIG_NOT_YET_VALID => {
                    keytag => $_,
                    ns_list => join( q{;}, uniq sort @{ $nsec_rrsig_not_yet_valid{$_} } )
                }
              )
            } keys %nsec_rrsig_not_yet_valid;
    }

    if ( scalar keys %nsec_rrsig_verify_error ) {
        push @results, map {
              _emit_log(
                DS10_NSEC_RRSIG_VERIFY_ERROR => {
                    keytag => $_,
                    ns_list => join( q{;}, uniq sort @{ $nsec_rrsig_verify_error{$_} } )
                }
              )
            } keys %nsec_rrsig_verify_error;
    }

    if ( values %nsec_rrsig_no_dnskey or values %nsec_rrsig_expired or values %nsec_rrsig_not_yet_valid or values %nsec_rrsig_verify_error ) {
        my @combined_ns = uniq ( values %nsec_rrsig_no_dnskey, values %nsec_rrsig_expired, values %nsec_rrsig_not_yet_valid, values %nsec_rrsig_verify_error );
        my @ns_list;
        
        foreach my $ns_aref ( @combined_ns ) {
            foreach my $ns ( @$ns_aref ) {
                push @ns_list, $ns unless grep { $_ eq $ns } @nsec_rrsig_verified;
            }
        }

        push @results,
          _emit_log(
            DS10_NSEC_NO_VERIFIED_SIGNATURE => {
                ns_list => join( q{;}, uniq sort @ns_list )
            }
          ) if scalar @ns_list;
    }

    if ( scalar keys %nsec3_rrsig_no_dnskey ) {
        push @results, map {
              _emit_log(
                DS10_NSEC3_RRSIG_NO_DNSKEY => {
                    keytag => $_,
                    ns_list => join( q{;}, uniq sort @{ $nsec3_rrsig_no_dnskey{$_} } )
                }
              )
            } keys %nsec3_rrsig_no_dnskey;
    }

    if ( scalar keys %nsec3_rrsig_expired ) {
        push @results, map {
              _emit_log(
                DS10_NSEC3_RRSIG_EXPIRED => {
                    keytag => $_,
                    ns_list => join( q{;}, uniq sort @{ $nsec3_rrsig_expired{$_} } )
                }
              )
            } keys %nsec3_rrsig_expired;
    }

    if ( scalar keys %nsec3_rrsig_not_yet_valid ) {
        push @results, map {
              _emit_log(
                DS10_NSEC3_RRSIG_NOT_YET_VALID => {
                    keytag => $_,
                    ns_list => join( q{;}, uniq sort @{ $nsec3_rrsig_not_yet_valid{$_} } )
                }
              )
            } keys %nsec3_rrsig_not_yet_valid;
    }

    if ( scalar keys %nsec3_rrsig_verify_error ) {
        push @results, map {
              _emit_log(
                DS10_NSEC3_RRSIG_VERIFY_ERROR => {
                    keytag => $_,
                    ns_list => join( q{;}, uniq sort @{ $nsec3_rrsig_verify_error{$_} } )
                }
              )
            } keys %nsec3_rrsig_verify_error;
    }

    if ( values %nsec3_rrsig_no_dnskey or values %nsec3_rrsig_expired or values %nsec3_rrsig_not_yet_valid or values %nsec3_rrsig_verify_error ) {
        my @combined_ns = uniq ( values %nsec3_rrsig_no_dnskey, values %nsec3_rrsig_expired, values %nsec3_rrsig_not_yet_valid, values %nsec3_rrsig_verify_error );
        my @ns_list;
        
        foreach my $ns_aref ( @combined_ns ) {
            foreach my $ns ( @$ns_aref ) {
                push @ns_list, $ns unless grep { $_ eq $ns } @nsec3_rrsig_verified;
            }
        }

        push @results,
          _emit_log(
            DS10_NSEC3_NO_VERIFIED_SIGNATURE => {
                ns_list => join( q{;}, uniq sort @ns_list )
            }
          ) if scalar @ns_list;
    }

    if ( scalar keys %algo_not_supported_by_zm ) {
        foreach my $keytag ( keys %algo_not_supported_by_zm ) {
            push @results, map {
              _emit_log(
                DS10_ALGO_NOT_SUPPORTED_BY_ZM => {
                    keytag     => $keytag,
                    algo_num   => $_,
                    algo_mnemo => $algo_properties{$_}{mnemonic},
                    ns_ip_list => join( q{;}, uniq sort @{ $algo_not_supported_by_zm{$keytag}{$_} } )
                }
              )
            } keys %{ $algo_not_supported_by_zm{$keytag} };
        }
    }

    if ( not scalar @with_dnskey and scalar @without_dnskey ) {
        push @results,
          _emit_log(
            DS10_ZONE_NO_DNSSEC => {
                ns_list => join( q{;}, uniq sort @without_dnskey )
            }
          );
    }

    if ( scalar @with_dnskey and scalar @without_dnskey ) {
        push @results,
          _emit_log(
            DS10_SERVER_NO_DNSSEC => {
                ns_list => join( q{;}, uniq sort @without_dnskey )
            }
          );
    }

    $lc = List::Compare->new( [ @all_ns ], [ @ignored_nss, @without_dnskey, @nsec_in_answer, @nsec3param_nsec_nodata, @nsec3param_in_answer, @nsec_nsec3_nodata ] );
    @first = $lc->get_unique;

    if ( @first ) {
        push @results,
          _emit_log(
            DS10_EXPECTED_NSEC_NSEC3_MISSING => {
                ns_list => join( q{;}, uniq sort @first )
            }
          );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec10

=over

=item dnssec11()

    my @logentry_array = dnssec11( $zone );

Runs the L<DNSSEC11 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec11.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec11 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC11';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my @undetermined_ds;
    my @no_ds_record;
    my @has_ds_record;
    my $continue_with_child_tests = 1;

    my $parent     = Zonemaster::Engine::TestMethods->method1( $zone );
    my @nss_parent = @{ $parent->ns };
    my %nss        = map { $_->name->string . '/' . $_->address->short => $_ } @nss_parent;
    my %ip_already_processed;

    my $is_undelegated = Zonemaster::Engine::Recursor->has_fake_addresses( $zone->name->string );

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        if ( $is_undelegated ){
            if ( not $ns->fake_ds->{$zone->name->string} ){
                return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
            }
            last;
        }

        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( _ip_disabled_message( \@results, $ns, q{DS} ) ) {
            next;
        }

        my $ds_p = $ns->query( $zone->name, q{DS}, { dnssec => 1, usevc => 0 } );
        if ( $ds_p and $ds_p->tc ) {
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
        push @results, _emit_log( DS11_UNDETERMINED_DS => {} );
        $continue_with_child_tests = 0;
    }
    elsif ( scalar @no_ds_record and not scalar @has_ds_record ) {
        $continue_with_child_tests = 0;
    }
    elsif ( scalar @no_ds_record and scalar @has_ds_record ) {
        push @results, _emit_log( DS11_INCONSISTENT_DS => {} );
        push @results,
          _emit_log(
            DS11_PARENT_WITHOUT_DS => {
                ns_ip_list => join( q{;}, sort @no_ds_record )
            }
          );
        push @results,
          _emit_log(
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

            if ( _ip_disabled_message( \@results, $ns, @query_types ) ) {
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
            if ( $dnskey_p and $dnskey_p->tc ) {
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
            push @results, _emit_log( DS11_UNDETERMINED_SIGNED_ZONE => {} );
        }
        elsif ( scalar @no_dnskey_record and not scalar @has_dnskey_record ) {
            push @results, _emit_log( DS11_DS_BUT_UNSIGNED_ZONE => {} );
        }
        elsif ( scalar @no_dnskey_record and scalar @has_dnskey_record ) {
            push @results, _emit_log( DS11_INCONSISTENT_SIGNED_ZONE => {} );
            push @results,
              _emit_log(
                DS11_NS_WITH_UNSIGNED_ZONE => {
                    ns_ip_list => join( q{;}, sort @no_dnskey_record )
                }
              );
            push @results,
              _emit_log(
                  DS11_NS_WITH_SIGNED_ZONE => {
                    ns_ip_list => join( q{;}, sort @has_dnskey_record )
                }
              );
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec11

=over

=item dnssec13()

    my @logentry_array = dnssec13( $zone );

Runs the L<DNSSEC13 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec13.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec13 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC13';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
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

        if ( _ip_disabled_message( \@results, $ns, @query_types ) ) {
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
                  _emit_log(
                    "DS13_ALGO_NOT_SIGNED_${query_type}" => {
                        ns_ip_list => join( q{;}, uniq sort @{ $algo_not_signed{ lc($query_type) }{$algorithm} }),
                        algo_num   => $algorithm,
                        algo_mnemo => $algo_properties{$algorithm}{mnemonic}
                    }
                  );
            }
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec13

=over

=item dnssec14()

    my @logentry_array = dnssec14( $zone );

Runs the L<DNSSEC14 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec14.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec14 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC14';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my @dnskey_rrs;

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        if ( _ip_disabled_message( \@results, $ns, q{DNSKEY} ) ) {
            next;
        }

        my $dnskey_p = $ns->query( $zone->name, 'DNSKEY', { dnssec => 1, usevc => 0 } );
        if ( not $dnskey_p ) {
            push @results, _emit_log( NO_RESPONSE => { ns => $ns->string } );
            next;
        }

        my @keys = $dnskey_p->get_records( 'DNSKEY', 'answer' );
        if ( not @keys ) {
            push @results, _emit_log( NO_RESPONSE_DNSKEY => { ns => $ns->string } );
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
            push @results, _emit_log( DNSKEY_TOO_SMALL_FOR_ALGO => $algo_args );
        }

        if ( $key->keysize < $rsa_key_size_details{$algo}{rec_size} ) {
            push @results, _emit_log( DNSKEY_SMALLER_THAN_REC => $algo_args );
        }

        if ( $key->keysize > $rsa_key_size_details{$algo}{max_size} ) {
            push @results, _emit_log( DNSKEY_TOO_LARGE_FOR_ALGO => $algo_args );
        }

        $investigated_keys{$key_ref} = 1;

    } ## end foreach my $key ( @keys )

    if ( scalar @dnskey_rrs and scalar @results == scalar grep { $_->tag eq 'NO_RESPONSE' } @results) {
        push @results, _emit_log( KEY_SIZE_OK => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec14

=over

=item dnssec15()

    my @logentry_array = dnssec15( $zone );

Runs the L<DNSSEC15 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec15.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec15 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC15';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

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

        if ( _ip_disabled_message( \@results, $ns, @query_types ) ) {
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
        push @{ $cds_rrsets{ $ns->address->short } }, @cds_records;

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
        push @results, _emit_log( DS15_NO_CDS_CDNSKEY => {} );
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
                # Quick hack. Proper fix should be available in LDNS 1.8.5: https://github.com/NLnetLabs/ldns/commit/b39813870a5fb0f4e8ff1570b3b09416aaee716c
                #
                my @dnskey;
                foreach my $cdnskey ( @{ $cdnskey_rrsets{ $ns_ip } } ) {
                    my $rr_string = $cdnskey->string;
                    $rr_string =~ s/\s+CDNSKEY\s+/ DNSKEY /;
                    push @dnskey, Zonemaster::LDNS::RR->new( $rr_string );
                }

                foreach my $cds ( @{ $cds_rrsets{ $ns_ip } } ) {
                    my @matching_keys = grep { $cds->keytag == $_->keytag or ($cds->algorithm == 0 and $_->algorithm == 0)} @dnskey;
                    if ( not scalar @matching_keys ) {
                        $mismatch_cds_cdnskey{ $ns_ip } = 1;
                    }
                }

                foreach my $dnskey ( @dnskey ) {
                    my @matching_keys = grep { $dnskey->keytag == $_->keytag or ($dnskey->algorithm == 0 and $_->algorithm == 0)} @{ $cds_rrsets{ $ns_ip } };
                    if ( not scalar @matching_keys ) {
                        $mismatch_cds_cdnskey{ $ns_ip } = 1;
                    }
                }
            }
        }

        if ( scalar keys %has_cds_no_cdnskey ) {
            push @results,
              _emit_log(
                DS15_HAS_CDS_NO_CDNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %has_cds_no_cdnskey )
                }
              );
        }

        if ( scalar keys %has_cdnskey_no_cds ) {
            push @results,
              _emit_log(
                DS15_HAS_CDNSKEY_NO_CDS => {
                    ns_ip_list => join( q{;}, sort keys %has_cdnskey_no_cds )
                }
              );
        }

        if ( scalar keys %has_cds_and_cdnskey ) {
            push @results,
              _emit_log(
                DS15_HAS_CDS_AND_CDNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %has_cds_and_cdnskey )
                }
              );
        }

        my $first = 1;
        my $first_rrlist;
        my $inconsistent_rrset = 0;
        for my $ns_ip ( keys %cds_rrsets ) {
            if ( $first ) {
                $first_rrlist = Zonemaster::LDNS::RRList->new( $cds_rrsets{ $ns_ip } );
                $first = 0;
                next;
            }

            my $rrlist = Zonemaster::LDNS::RRList->new( $cds_rrsets{ $ns_ip } );

            if ( $rrlist ne $first_rrlist ) {
                $inconsistent_rrset = 1;
                last;
            }
        }

        push @results, _emit_log( DS15_INCONSISTENT_CDS => {} ) if $inconsistent_rrset;

        $first = 1;
        $inconsistent_rrset = 0;
        for my $ns_ip ( keys %cdnskey_rrsets ) {
            if ( $first ) {
                $first_rrlist = Zonemaster::LDNS::RRList->new( $cdnskey_rrsets{ $ns_ip } );
                $first = 0;
                next;
            }

            my $rrlist = Zonemaster::LDNS::RRList->new( $cdnskey_rrsets{ $ns_ip } );

            if ( $rrlist ne $first_rrlist ) {
                $inconsistent_rrset = 1;
                last;
            }
        }

        push @results, _emit_log( DS15_INCONSISTENT_CDNSKEY => {} ) if $inconsistent_rrset;

        if ( scalar keys %mismatch_cds_cdnskey ) {
            push @results,
              _emit_log(
                DS15_MISMATCH_CDS_CDNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %mismatch_cds_cdnskey )
                }
              );
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec15

=over

=item dnssec16()

    my @logentry_array = dnssec16( $zone );

Runs the L<DNSSEC16 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec16.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec16 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC16';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my @query_types = qw{CDS DNSKEY};
    my %cds_rrsets;
    my %dnskey_rrsets;
    my %no_dnskey_rrset;
    my %mixed_delete_cds;
    my %delete_cds;
    my %no_match_cds_with_dnskey;
    my %cds_points_to_non_zone_dnskey;
    my %cds_points_to_non_sep_dnskey;
    my %dnskey_not_signed_by_cds;
    my %cds_not_signed_by_cds;
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

        if ( _ip_disabled_message( \@results, $ns, @query_types ) ) {
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
                next if $ds->algorithm == 0;
                if ( not scalar grep { $ds->keytag == $_->keytag } @{ $dnskey_rrsets{ $ns_ip }{dnskey} } ) {
                    push @{ $no_match_cds_with_dnskey{ $ds->keytag } }, $ns_ip;
                }
                elsif ( scalar grep { $ds->keytag == $_->keytag and not $_->flags & 256 } @{ $dnskey_rrsets{ $ns_ip }{dnskey} } ) {
                    push @{ $cds_points_to_non_zone_dnskey{ $ds->keytag } }, $ns_ip;
                }
                else {
                    if ( not scalar grep { $ds->keytag == $_->keytag } @{ $dnskey_rrsets{ $ns_ip }{rrsig} } ) {
                        push @{ $dnskey_not_signed_by_cds{ $ds->keytag } }, $ns_ip;
                    }
                    if ( not scalar grep { $ds->keytag == $_->keytag } @{ $cds_rrsets{ $ns_ip }{rrsig} } ) {
                        push @{ $cds_not_signed_by_cds{ $ds->keytag } }, $ns_ip;
                    }
                    if ( scalar grep { $ds->keytag == $_->keytag and not $_->flags & 1 } @{ $dnskey_rrsets{ $ns_ip }{dnskey} } ) {
                        push @{ $cds_points_to_non_sep_dnskey{ $ds->keytag } }, $ns_ip;
                    }
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
              _emit_log(
                DS16_CDS_WITHOUT_DNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %no_dnskey_rrset )
                }
              );
        }

        if ( scalar keys %mixed_delete_cds ) {
            push @results,
              _emit_log(
                DS16_MIXED_DELETE_CDS => {
                    ns_ip_list => join( q{;}, sort keys %mixed_delete_cds )
                }
              );
        }

        if ( scalar keys %delete_cds ) {
            push @results,
              _emit_log(
                DS16_DELETE_CDS => {
                    ns_ip_list => join( q{;}, sort keys %delete_cds )
                }
              );
        }

        if ( scalar keys %no_match_cds_with_dnskey ) {
            push @results, map {
              _emit_log(
                DS16_CDS_MATCHES_NO_DNSKEY => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $no_match_cds_with_dnskey{ $_ } } )
                }
              )
            } keys %no_match_cds_with_dnskey;
        }

        if ( scalar keys %cds_points_to_non_zone_dnskey ) {
            push @results, map {
              _emit_log(
                DS16_CDS_MATCHES_NON_ZONE_DNSKEY => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $cds_points_to_non_zone_dnskey{ $_ } } )
                }
              )
            } keys %cds_points_to_non_zone_dnskey;
        }

        if ( scalar keys %cds_points_to_non_sep_dnskey ) {
            push @results, map {
              _emit_log(
                DS16_CDS_MATCHES_NON_SEP_DNSKEY => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $cds_points_to_non_sep_dnskey{ $_ } } )
                }
              )
            } keys %cds_points_to_non_sep_dnskey;
        }

        if ( scalar keys %dnskey_not_signed_by_cds ) {
            push @results, map {
              _emit_log(
                DS16_DNSKEY_NOT_SIGNED_BY_CDS => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $dnskey_not_signed_by_cds{ $_ } } )
                }
              )
            } keys %dnskey_not_signed_by_cds;
        }

        if ( scalar keys %cds_not_signed_by_cds ) {
            push @results, map {
              _emit_log(
                DS16_CDS_NOT_SIGNED_BY_CDS => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $cds_not_signed_by_cds{ $_ } } )
                }
              )
            } keys %cds_not_signed_by_cds;
        }

        if ( scalar keys %cds_invalid_rrsig ) {
            push @results, map {
              _emit_log(
                DS16_CDS_INVALID_RRSIG => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $cds_invalid_rrsig{ $_ } } )
                }
              )
            } keys %cds_invalid_rrsig;
        }

        if ( scalar keys %cds_not_signed ) {
            push @results,
              _emit_log(
                DS16_CDS_UNSIGNED => {
                    ns_ip_list => join( q{;}, sort keys %cds_not_signed )
                }
              );
        }

        if ( scalar keys %cds_signed_by_unknown_dnskey ) {
            push @results, map {
              _emit_log(
                DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $cds_signed_by_unknown_dnskey{ $_ } } )
                }
              )
            } keys %cds_signed_by_unknown_dnskey;
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec16

=over

=item dnssec17()

    my @logentry_array = dnssec17( $zone );

Runs the L<DNSSEC17 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec17.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec17 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC17';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my @query_types = qw{CDNSKEY DNSKEY};
    my %cdnskey_rrsets;
    my %dnskey_rrsets;
    my %no_dnskey_rrset;
    my %mixed_delete_cdnskey;
    my %cdnskey_is_non_zone_key;
    my %cdnskey_is_non_sep_key;
    my %delete_cdnskey;
    my %no_match_cdnskey_with_dnskey;
    my %dnskey_not_signed_by_cdnskey;
    my %cdnskey_not_signed_by_cdnskey;
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

        if ( _ip_disabled_message( \@results, $ns, @query_types ) ) {
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
                next if $dnskey->algorithm == 0;
                if ( not $dnskey->flags & 256 ) {
                    push @{ $cdnskey_is_non_zone_key{ $dnskey->keytag } }, $ns_ip;
                }
                else {
                    if ( not $dnskey->flags & 1 ) {
                        push @{ $cdnskey_is_non_sep_key{ $dnskey->keytag } }, $ns_ip;
                    }
                    if ( not scalar grep { $dnskey->keytag == $_->keytag } @{ $dnskey_rrsets{ $ns_ip }{dnskey} } ) {
                        push @{ $no_match_cdnskey_with_dnskey{ $dnskey->keytag } }, $ns_ip;
                    }
                    else {
                        if ( not scalar grep { $dnskey->keytag == $_->keytag } @{ $dnskey_rrsets{ $ns_ip }{rrsig} } ) {
                            push @{ $dnskey_not_signed_by_cdnskey{ $dnskey->keytag } }, $ns_ip;
                        }
                        if ( not scalar grep { $dnskey->keytag == $_->keytag } @{ $cdnskey_rrsets{ $ns_ip }{rrsig} } ) {
                            push @{ $cdnskey_not_signed_by_cdnskey{ $dnskey->keytag } }, $ns_ip;
                        }
                    }
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
              _emit_log(
                DS17_CDNSKEY_WITHOUT_DNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %no_dnskey_rrset )
                }
              );
        }

        if ( scalar keys %mixed_delete_cdnskey ) {
            push @results,
              _emit_log(
                DS17_MIXED_DELETE_CDNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %mixed_delete_cdnskey )
                }
              );
        }

        if ( scalar keys %delete_cdnskey ) {
            push @results,
              _emit_log(
                DS17_DELETE_CDNSKEY => {
                    ns_ip_list => join( q{;}, sort keys %delete_cdnskey )
                }
              );
        }

        if ( scalar keys %no_match_cdnskey_with_dnskey ) {
            push @results, map {
              _emit_log(
                DS17_CDNSKEY_MATCHES_NO_DNSKEY => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $no_match_cdnskey_with_dnskey{ $_ } } )
                }
              )
            } keys %no_match_cdnskey_with_dnskey;
        }

        if ( scalar keys %cdnskey_is_non_zone_key ) {
            push @results, map {
              _emit_log(
                DS17_CDNSKEY_IS_NON_ZONE => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $cdnskey_is_non_zone_key{ $_ } } )
                }
              )
            } keys %cdnskey_is_non_zone_key;
        }


        if ( scalar keys %cdnskey_is_non_sep_key ) {
            push @results, map {
              _emit_log(
                DS17_CDNSKEY_IS_NON_SEP => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $cdnskey_is_non_sep_key{ $_ } } )
                }
              )
            } keys %cdnskey_is_non_sep_key;
        }

        if ( scalar keys %dnskey_not_signed_by_cdnskey ) {
            push @results, map {
              _emit_log(
                DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $dnskey_not_signed_by_cdnskey{ $_ } } )
                }
              )
            } keys %dnskey_not_signed_by_cdnskey;
        }

        if ( scalar keys %cdnskey_not_signed_by_cdnskey ) {
            push @results, map {
              _emit_log(
                DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $cdnskey_not_signed_by_cdnskey{ $_ } } )
                }
              )
            } keys %cdnskey_not_signed_by_cdnskey;
        }

        if ( scalar keys %cdnskey_invalid_rrsig ) {
            push @results, map {
              _emit_log(
                DS17_CDNSKEY_INVALID_RRSIG => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $cdnskey_invalid_rrsig{ $_ } } )
                }
              )
            } keys %cdnskey_invalid_rrsig;
        }

        if ( scalar keys %cdnskey_not_signed ) {
            push @results,
              _emit_log(
                DS17_CDNSKEY_UNSIGNED => {
                    ns_ip_list => join( q{;}, sort keys %cdnskey_not_signed )
                }
              );
        }

        if ( scalar keys %cdnskey_signed_by_unknown_dnskey ) {
            push @results, map {
              _emit_log(
                DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY => {
                    keytag     => $_,
                    ns_ip_list => join( q{;}, uniq sort @{ $cdnskey_signed_by_unknown_dnskey{ $_ } } )
                }
              )
            } keys %cdnskey_signed_by_unknown_dnskey;
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec17

=over

=item dnssec18()

    my @logentry_array = dnssec18( $zone );

Runs the L<DNSSEC18 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/DNSSEC-TP/dnssec18.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub dnssec18 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'DNSSEC18';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my %cds_rrsets;
    my %cdnskey_rrsets;
    my %dnskey_rrsets;
    my @ds_records;
    my %ds_no_match_cds_rrsig;
    my %ds_no_match_cdnskey_rrsig;
    my $continue_with_child_tests = 1;

    my $parent     = Zonemaster::Engine::TestMethods->method1( $zone );
    my @nss_parent = @{ $parent->ns };
    my %nss        = map { $_->name->string . '/' . $_->address->short => $_ } @nss_parent;
    my %ip_already_processed;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};

        next if exists $ip_already_processed{$ns->address->short};
        $ip_already_processed{$ns->address->short} = 1;

        if ( _ip_disabled_message( \@results, $ns, q{DS} ) ) {
            next;
        }

        my $ds_p = $ns->query( $zone->name, q{DS}, { dnssec => 1, usevc => 0 } );
        if ( not $ds_p or $ds_p->rcode ne q{NOERROR} or not $ds_p->aa ) {
            next;
        }
        my @tmp_ds_records = $ds_p->get_records_for_name( q{DS}, $zone->name->string, q{answer} );
        if ( not scalar @tmp_ds_records ) {
            next;
        }
        foreach my $tmp_ds_record ( @tmp_ds_records ) {
            if (
                not grep {
                          $tmp_ds_record->keytag == $_->keytag
                      and $tmp_ds_record->digtype == $_->digtype
                      and $tmp_ds_record->algorithm == $_->algorithm
                      and $tmp_ds_record->hexdigest eq $_->hexdigest
                } @ds_records
              )
            {
                push @ds_records, $tmp_ds_record;
            }
        }
    }
    undef %ip_already_processed;

    if ( not scalar @ds_records ) {
        $continue_with_child_tests = 0;
    }

    if ( $continue_with_child_tests ) {

        my @query_types = qw{CDNSKEY CDS DNSKEY};
        my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
        my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
        my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;
        my %ip_already_processed;

        for my $nss_key ( sort keys %nss ) {
            my $ns = $nss{$nss_key};

            next if exists $ip_already_processed{$ns->address->short};
            $ip_already_processed{$ns->address->short} = 1;

            if ( _ip_disabled_message( \@results, $ns, @query_types ) ) {
                next;
            }

            my $cds_p = $ns->query( $zone->name, q{CDS}, { dnssec => 1, usevc => 0 } );
            if ( not $cds_p or not $cds_p->aa or $cds_p->rcode ne q{NOERROR} ) {
                next;
            }
            my @cds_records = $cds_p->get_records( q{CDS}, q{answer} );
            if ( scalar @cds_records ) {
                my @cds_rrsig_records = $cds_p->get_records( q{RRSIG} , q{answer} );
                push @{ $cds_rrsets{ $ns->address->short }{cds} }, @cds_records;
                push @{ $cds_rrsets{ $ns->address->short }{rrsig} }, @cds_rrsig_records;
                foreach my $cds ( @{ $cds_rrsets{ $ns->address->short }{cds} } ) {
                    my $rr_string = $cds->string;
                    $rr_string =~ s/\s+CDS\s+/ DS /;
                    push @{ $cds_rrsets{ $ns->address->short }{ds} }, Zonemaster::LDNS::RR->new( $rr_string );
                }
            }

            my $cdnskey_p = $ns->query( $zone->name, q{CDNSKEY}, { dnssec => 1, usevc => 0 } );
            if ( not $cdnskey_p or not $cdnskey_p->aa or $cdnskey_p->rcode ne q{NOERROR} ) {
                next;
            }
            my @cdnskey_records = $cdnskey_p->get_records( q{CDNSKEY}, q{answer} );
            if ( scalar @cdnskey_records ) {
                my @cdnskey_rrsig_records = $cdnskey_p->get_records( q{RRSIG} , q{answer} );
                push @{ $cdnskey_rrsets{ $ns->address->short }{cdnskey} }, @cdnskey_records;
                push @{ $cdnskey_rrsets{ $ns->address->short }{rrsig} }, @cdnskey_rrsig_records;
                foreach my $cdnskey ( @{ $cdnskey_rrsets{ $ns->address->short }{cdnskey} } ) {
                    my $rr_string = $cdnskey->string;
                    $rr_string =~ s/\s+CDNSKEY\s+/ DNSKEY /;
                    push @{ $cdnskey_rrsets{ $ns->address->short }{dnskey} }, Zonemaster::LDNS::RR->new( $rr_string );
                }
            }

            my $dnskey_p = $ns->query( $zone->name, q{DNSKEY}, { dnssec => 1, usevc => 0 } );
            if ( not $dnskey_p or $dnskey_p->rcode ne q{NOERROR} or not $dnskey_p->aa ) {
                next;
            }
            my @dnskey_records = $dnskey_p->get_records( q{DNSKEY}, q{answer} );
            if ( scalar @dnskey_records ) {
                push @{ $dnskey_rrsets{ $ns->address->short }{dnskey} }, @dnskey_records;
            }
        }
        undef %ip_already_processed;

        if (    not( not scalar keys %cds_rrsets and not scalar keys %cdnskey_rrsets )
            and not( not scalar keys %dnskey_rrsets ) )
        {
            for my $ns_ip ( keys %cds_rrsets ) {
                my (@rrsig, @dnskey);
                push @rrsig, @{ $cds_rrsets{ $ns_ip }{rrsig} };
                push @dnskey, @{ $dnskey_rrsets{ $ns_ip }{dnskey} };
                my $match = 0;
                foreach my $ds ( @ds_records ) {
                    if ( not scalar grep { $ds->keytag == $_->keytag } @dnskey ) {
                        next;
                    }
                    elsif ( scalar grep { $ds->keytag == $_->keytag } @rrsig ) {
                        $match = 1;
                        last;
                    }
                }
                if ( not $match ) {
                    $ds_no_match_cds_rrsig{ $ns_ip } = 1;
                }
            }
            for my $ns_ip ( keys %cdnskey_rrsets ) {
                my (@rrsig, @dnskey);
                push @rrsig, @{ $cdnskey_rrsets{ $ns_ip }{rrsig} };
                push @dnskey, @{ $dnskey_rrsets{ $ns_ip }{dnskey} };
                my $match = 0;
                foreach my $ds ( @ds_records ) {
                    if ( not scalar grep { $ds->keytag == $_->keytag } @dnskey ) {
                        next;
                    }
                    elsif ( scalar grep { $ds->keytag == $_->keytag } @rrsig ) {
                        $match = 1;
                        last;
                    }
                }
                if ( not $match ) {
                    $ds_no_match_cdnskey_rrsig{ $ns_ip } = 1;
                }
            }
            if ( scalar keys %ds_no_match_cds_rrsig ) {
                push @results,
                  _emit_log(
                     DS18_NO_MATCH_CDS_RRSIG_DS => {
                        ns_ip_list => join( q{;}, sort keys %ds_no_match_cds_rrsig )
                    }
                  );
            }
            if ( scalar keys %ds_no_match_cdnskey_rrsig ) {
                push @results,
                  _emit_log(
                     DS18_NO_MATCH_CDNSKEY_RRSIG_DS => {
                        ns_ip_list => join( q{;}, sort keys %ds_no_match_cdnskey_rrsig )
                    }
                  );
            }
        }
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub dnssec18

1;
