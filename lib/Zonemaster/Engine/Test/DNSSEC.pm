package Zonemaster::Engine::Test::DNSSEC;

use version; our $VERSION = version->declare("v1.1.8");

###
### This test module implements DNSSEC tests.
###

use strict;
use warnings;

use 5.014002;

use Zonemaster::Engine;

use Carp;
use List::MoreUtils qw[uniq none];
use List::Util qw[min];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;
use Zonemaster::Engine::Constants qw[:algo :soa :ip];
use Zonemaster::Engine::Util;

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

    }

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
              NO_RESPONSE_DS
              UNEXPECTED_RESPONSE_DS
              DS_ALGORITHM_NOT_DS
              DS_ALGORITHM_MISSING
              DS_ALGORITHM_OK
              DS_ALGORITHM_DEPRECATED
              DS_ALGORITHM_RESERVED
              )
        ],
        dnssec02 => [
            qw(
              NO_DS
              DS_FOUND
              NO_DNSKEY
              DS_RFC4509_NOT_VALID
              COMMON_KEYTAGS
              DS_MATCHES_DNSKEY
              DS_DOES_NOT_MATCH_DNSKEY
              DS_MATCH_FOUND
              DS_MATCH_NOT_FOUND
              NO_COMMON_KEYTAGS
              )
        ],
        dnssec03 => [
            qw(
              NO_NSEC3PARAM
              NO_DNSKEY
              MANY_ITERATIONS
              TOO_MANY_ITERATIONS
              ITERATIONS_OK
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
              )
        ],
        dnssec06 => [
            qw(
              EXTRA_PROCESSING_OK
              EXTRA_PROCESSING_BROKEN
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
              )
        ],
        dnssec08 => [
            qw(
              DNSKEY_SIGNATURE_OK
              DNSKEY_SIGNATURE_NOT_OK
              DNSKEY_SIGNED
              DNSKEY_NOT_SIGNED
              NO_KEYS_OR_NO_SIGS
              )
        ],
        dnssec09 => [
            qw(
              NO_KEYS_OR_NO_SIGS_OR_NO_SOA
              SOA_SIGNATURE_OK
              SOA_SIGNATURE_NOT_OK
              SOA_SIGNED
              SOA_NOT_SIGNED
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
              )
        ],
        dnssec11 => [
            qw(
              DELEGATION_NOT_SIGNED
              DELEGATION_SIGNED
              ),
        ],
        dnssec13 => [
            qw(
              ALGO_NOT_SIGNED_RRSET
              ALL_ALGO_SIGNED
              NO_RESPONSE
              NO_RESPONSE_RRSET
              RRSET_NOT_SIGNED
              RRSIG_BROKEN
              RRSIG_NOT_MATCH_DNSKEY
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
              ),
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    ADDITIONAL_DNSKEY_SKIPPED => sub {
        __x    # DNSSEC:ADDITIONAL_DNSKEY_SKIPPED
          "No DNSKEYs found. Additional tests skipped.", @_;
    },
    ALGORITHM_DEPRECATED => sub {
        __x    # DNSSEC:ALGORITHM_DEPRECATED
          "The DNSKEY with tag {keytag} uses deprecated algorithm number {algorithm}/({description}).", @_;
    },
    ALGORITHM_NOT_RECOMMENDED => sub {
        __x    # DNSSEC:ALGORITHM_NOT_RECOMMENDED
          "The DNSKEY with tag {keytag} uses an algorithm number {algorithm}/({description} which which is not recommended to be used.",
          @_;
    },
    ALGORITHM_NOT_ZONE_SIGN => sub {
        __x    # DNSSEC:ALGORITHM_NOT_ZONE_SIGN
          "The DNSKEY with tag {keytag} uses algorithm number not meant for zone signing{algorithm}/({description}).",
          @_;
    },
    ALGORITHM_OK => sub {
        __x    # DNSSEC:ALGORITHM_OK
          "The DNSKEY with tag {keytag} uses algorithm number {algorithm}/({description}), which is OK.", @_;
    },
    ALGORITHM_PRIVATE => sub {
        __x    # DNSSEC:ALGORITHM_PRIVATE
          "The DNSKEY with tag {keytag} uses private algorithm number {algorithm}/({description}).", @_;
    },
    ALGORITHM_RESERVED => sub {
        __x    # DNSSEC:ALGORITHM_RESERVED
          "The DNSKEY with tag {keytag} uses reserved algorithm number {algorithm}/({description}).", @_;
    },
    ALGORITHM_UNASSIGNED => sub {
        __x    # DNSSEC:ALGORITHM_UNASSIGNED
          "The DNSKEY with tag {keytag} uses unassigned algorithm number {algorithm}/({description}).", @_;
    },
    ALGO_NOT_SIGNED_RRSET => sub {
        __x    # DNSSEC:ALGO_NOT_SIGNED_RRSET
          "Nameserver {ns}/{address} responded with no RRSIG for RRset {rrtype} created by the algorithm {algorithm}.", @_;
    },
    ALL_ALGO_SIGNED => sub {
       __x    # DNSSEC:ALL_ALGO_SIGNED
          "All the tested RRset (SOA/DNSKEY/NS) are signed by each algorithm present in the DNSKEY RRset", @_;
    },
    BROKEN_DNSSEC => sub {
       __x    # DNSSEC:BROKEN_DNSSEC
          "All nameservers for zone {zone} responds with neither NSEC nor NSEC3 records when such records are expected.", @_;
    },
    COMMON_KEYTAGS => sub {
        __x    # DNSSEC:COMMON_KEYTAGS
          "There are both DS and DNSKEY records with key tags {keytags}.", @_;
    },
    DELEGATION_NOT_SIGNED => sub {
        __x    # DNSSEC:DELEGATION_NOT_SIGNED
          "Delegation from parent to child is not properly signed {reason}.", @_;
    },
    DELEGATION_SIGNED => sub {
        __x    # DNSSEC:DELEGATION_SIGNED
          "Delegation from parent to child is properly signed.", @_;
    },
    DNSKEY_AND_DS => sub {
        __x    # DNSSEC:DNSKEY_AND_DS
          "{parent} sent a DS record, and {child} a DNSKEY record.", @_;
    },
    DNSKEY_BUT_NOT_DS => sub {
        __x    # DNSSEC:DNSKEY_BUT_NOT_DS
          "{child} sent a DNSKEY record, but {parent} did not send a DS record.", @_;
    },
    DNSKEY_NOT_SIGNED => sub {
        __x    # DNSSEC:DNSKEY_NOT_SIGNED
          "The apex DNSKEY RRset was not correctly signed.", @_;
    },
    DNSKEY_SIGNATURE_NOT_OK => sub {
        __x    # DNSSEC:DNSKEY_SIGNATURE_NOT_OK
          "Signature for DNSKEY with tag {signature} failed to verify with error '{error}'.", @_;
    },
    DNSKEY_SIGNATURE_OK => sub {
        __x    # DNSSEC:DNSKEY_SIGNATURE_OK
          "A signature for DNSKEY with tag {signature} was correctly signed.", @_;
    },
    DNSKEY_SIGNED => sub {
        __x    # DNSSEC:DNSKEY_SIGNED
          "The apex DNSKEY RRset was correcly signed.", @_;
    },
    DNSKEY_SMALLER_THAN_REC => sub {
        __x    # DNSSEC:DNSKEY_SMALLER_THAN_REC
          "DNSKEY with tag {keytag} and using algorithm {algorithm_number} ({algorithm_description}) has a size ({keysize}) smaller than the recommended one ({keysizerec}).", @_;
    },
    DNSKEY_TOO_SMALL_FOR_ALGO => sub {
        __x    # DNSSEC:DNSKEY_TOO_SMALL_FOR_ALGO
          "DNSKEY with tag {keytag} and using algorithm {algorithm_number} ({algorithm_description}) has a size ({keysize}) smaller than the minimum one ({keysizemin}).", @_;
    },
    DNSKEY_TOO_LARGE_FOR_ALGO => sub {
        __x    # DNSSEC:DNSKEY_TOO_LARGE_FOR_ALGO
          "DNSKEY with tag {keytag} and using algorithm {algorithm_number} ({algorithm_description}) has a size ({keysize}) larger than the maximum one ({keysizemax}).", @_;
    },
    DS_ALGORITHM_NOT_DS => sub {
        __x    # DNSSEC:DS_ALGORITHM_NOT_DS
          "{ns}/{address} returned a DS record created by algorithm {algorithm_number} which is not meant for DS. The DS record is for the DNSKEY record with keytag {keytag} in zone {zone}.", @_;
    },
    DS_ALGORITHM_DEPRECATED => sub {
        __x    # DNSSEC:DS_ALGORITHM_DEPRECATED
          "{ns}/{address} returned a DS record created by algorithm ({algorithm_number}/{algorithm_mnemonic}), which is deprecated. The DS record is for the DNSKEY record with keytag {keytag} in zone {zone}.", @_;
    },
    DS_ALGORITHM_MISSING => sub {
        __x    # DNSSEC:DS_ALGORITHM_MISSING
          "{ns}/{address} returned a DS record created by algorithm {algorithm_number}/{algorithm_mnemonic}, which is OK. The DS record is for the DNSKEY record with keytag {keytag} in zone {zone}.", @_;
    },
    DS_ALGORITHM_OK => sub {
        __x    # DNSSEC:DS_ALGORITHM_OK
          "{ns}/{address} answered DS query for zone {zone} with DS record for keytag {keytag} using algorithm {algorithm_number}/{algorithm_mnemonic}, which is OK.", @_;
    },
    DS_ALGORITHM_RESERVED => sub {
        __x    # DNSSEC:DS_ALGORITHM_RESERVED
          "{ns}/{address} returned a DS record created by with an unassigned algorithm ({algorithm_number}), which is not OK. The DS record is for the DNSKEY record with keytag {keytag} in zone {zone}.", @_;
    },
    DS_BUT_NOT_DNSKEY => sub {
        __x    # DNSSEC:DS_BUT_NOT_DNSKEY
          "{parent} sent a DS record, but {child} did not send a DNSKEY record.", @_;
    },
    DS_DOES_NOT_MATCH_DNSKEY => sub {
        __x    # DNSSEC:DS_DOES_NOT_MATCH_DNSKEY
          "DS record with keytag {keytag} and digest type {digtype} does not match the DNSKEY with the same tag.", @_;
    },
    DS_FOUND => sub {
        __x    # DNSSEC:DS_FOUND
          "Found DS records with tags {keytags}.", @_;
    },
    DS_MATCHES_DNSKEY => sub {
        __x    # DNSSEC:DS_MATCHES_DNSKEY
          "DS record with keytag {keytag} and digest type {digtype} matches the DNSKEY with the same tag.", @_;
    },
    DS_MATCH_FOUND => sub {
        __x    # DNSSEC:DS_MATCH_FOUND
          "At least one DS record with a matching DNSKEY record was found.", @_;
    },
    DS_MATCH_NOT_FOUND => sub {
        __x    # DNSSEC:DS_MATCH_NOT_FOUND
          "No DS record with a matching DNSKEY record was found.", @_;
    },
    DS_RFC4509_NOT_VALID => sub {
        __x    # DNSSEC:DS_RFC4509_NOT_VALID
          "Existing DS with digest type 2, while they do not match DNSKEY records, "
          . "prevent use of DS with digest type 1 (RFC4509, section 3).",
          @_;
    },
    DURATION_LONG => sub {
        __x    # DNSSEC:DURATION_LONG
          "RRSIG with keytag {tag} and covering type(s) {types} "
          . "has a duration of {duration} seconds, which is too long.",
          @_;
    },
    DURATION_OK => sub {
        __x    # DNSSEC:DURATION_OK
          "RRSIG with keytag {tag} and covering type(s) {types} "
          . "has a duration of {duration} seconds, which is just fine.",
          @_;
    },
    EXTRA_PROCESSING_BROKEN => sub {
        __x    # DNSSEC:EXTRA_PROCESSING_BROKEN
          "Server at {server} sent {keys} DNSKEY records, and {sigs} RRSIG records.", @_;
    },
    EXTRA_PROCESSING_OK => sub {
        __x    # DNSSEC:EXTRA_PROCESSING_OK
          "Server at {server} sent {keys} DNSKEY records and {sigs} RRSIG records.", @_;
    },
    HAS_NSEC3 => sub {
        __x    # DNSSEC:HAS_NSEC3
          "The zone has NSEC3 records.", @_;
    },
    HAS_NSEC => sub {
        __x    # DNSSEC:HAS_NSEC
          "The zone has NSEC records.", @_;
    },
    INCONSISTENT_DNSSEC => sub {
        __x    # DNSSEC:INCONSISTENT_DNSSEC
          "Some, but not all, nameservers for zone {zone} respond with neither NSEC nor NSEC3 records when such records are expected.", @_;
    },
    INCONSISTENT_NSEC_NSEC3 => sub {
        __x    # DNSSEC:INCONSISTENT_NSEC_NSEC3
          "Some nameservers for zone {zone} respond with NSEC records and others respond with NSEC3 records. Consistency is expected.", @_;
    },
    INVALID_NAME_RCODE => sub {
        __x    # DNSSEC:INVALID_NAME_RCODE
          "When asked for the name {name}, which must not exist, the response had RCODE {rcode}.", @_;
    },
    IPV4_DISABLED => sub {
        __x    # DNSSEC:IPV4_DISABLED
          'IPv4 is disabled, not sending "{rrtype}" query to {ns}/{address}.', @_;
    },
    IPV6_DISABLED => sub {
        __x    # DNSSEC:IPV6_DISABLED
          'IPv6 is disabled, not sending "{rrtype}" query to {ns}/{address}.', @_;
    },
    ITERATIONS_OK => sub {
        __x    # DNSSEC:ITERATIONS_OK
          "The number of NSEC3 iterations is {count}, which is OK.", @_;
    },
    KEY_DETAILS => sub {
        __x    # DNSSEC:KEY_DETAILS
          "Key with keytag {keytag} details : Size = {keysize}, Flags ({sep}, {rfc5011}).", @_;
    },
    MANY_ITERATIONS => sub {
        __x    # DNSSEC:MANY_ITERATIONS
          "The number of NSEC3 iterations is {count}, which is on the high side.", @_;
    },
    MIXED_NSEC_NSEC3 => sub {
        __x    # DNSSEC:MIXED_NSEC_NSEC3
          "Nameserver {ns/address} for zone {zone} responds with both NSEC and NSEC3 records when only one record type is expected.", @_;
    },
    NEITHER_DNSKEY_NOR_DS => sub {
        __x    # DNSSEC:NEITHER_DNSKEY_NOR_DS
          "There are neither DS nor DNSKEY records for the zone.", @_;
    },
    NO_COMMON_KEYTAGS => sub {
        __x    # DNSSEC:NO_COMMON_KEYTAGS
          "No DS record had a DNSKEY with a matching keytag.", @_;
    },
    NO_DNSKEY => sub {
        __x    # DNSSEC:NO_DNSKEY
          "No DNSKEYs were returned.", @_;
    },
    NO_DS => sub {
        __x    # DNSSEC:NO_DS
          "{from} returned no DS records for {zone}.", @_;
    },
    NO_KEYS_OR_NO_SIGS => sub {
        __x    # DNSSEC:NO_KEYS_OR_NO_SIGS
          "Cannot test DNSKEY signatures, because we got {keys} DNSKEY records and {sigs} RRSIG records.", @_;
    },
    NO_KEYS_OR_NO_SIGS_OR_NO_SOA => sub {
        __x    # DNSSEC:NO_KEYS_OR_NO_SIGS_OR_NO_SOA
          "Cannot test SOA signatures, because we got {keys} DNSKEY records, "
          . "{sigs} RRSIG records and {soas} SOA records.",
          @_;
    },
    NO_NSEC3PARAM => sub {
        __x    # DNSSEC:NO_NSEC3PARAM
          "{server} returned no NSEC3PARAM records.", @_;
    },
    NO_NSEC_NSEC3 => sub {
        __x    # DNSSEC:NO_NSEC_NSEC3
          "Nameserver {ns/address} for zone {zone} responds with neither NSEC nor NSEC3 record when when such records are expected.", @_;
    },
    NO_RESPONSE_DNSKEY => sub {
        __x    # DNSSEC:NO_RESPONSE_DNSKEY
          "Nameserver {ns}/{address} responded with no DNSKEY record(s).", @_;
    },
    NO_RESPONES_DS => sub {
        __x    # DNSSEC:NO_RESPONSE_DS
          "{ns}/{address} returned no DS records for {zone}.", @_;
    },
    NO_RESPONSE_RRSET => sub {
        __x    # DNSSEC:NO_RESPONSE_RRSET
          "Nameserver {ns}/{address} responded with no {rrtype} record(s).", @_;
    },
    NO_RESPONSE => sub {
        __x    # DNSSEC:NO_RESPONSE
          "Nameserver {ns}/{address} did not respond.", @_;
    },
    NOT_SIGNED => sub {
        __x    # DNSSEC:NOT_SIGNED
          "The zone is not signed with DNSSEC.", @_;
    },
    NSEC3_COVERS_NOT => sub {
        __x    # DNSSEC:NSEC3_COVERS_NOT
          "NSEC3 record does not cover {name}.", @_;
    },
    NSEC3_NOT_SIGNED => sub {
        __x    # DNSSEC:NSEC3_NOT_SIGNED
          "No signature correctly signed the NSEC3 RRset.", @_;
    },
    NSEC3_SIG_VERIFY_ERROR => sub {
        __x    # DNSSEC:NSEC3_SIG_VERIFY_ERROR
          "Trying to verify NSEC3 RRset with RRSIG {sig} gave error '{error}'.", @_;
    },
    NSEC_COVERS_NOT => sub {
        __x    # DNSSEC:NSEC_COVERS_NOT
          "NSEC does not cover {name}.", @_;
    },
    NSEC_NOT_SIGNED => sub {
        __x    # DNSSEC:NSEC_NOT_SIGNED
          "No signature correctly signed the NSEC RRset.", @_;
    },
    NSEC_SIG_VERIFY_ERROR => sub {
        __x    # DNSSEC:NSEC_SIG_VERIFY_ERROR
          "Trying to verify NSEC RRset with RRSIG {sig} gave error '{error}'.", @_;
    },
    REMAINING_LONG => sub {
        __x    # DNSSEC:REMAINING_LONG
          "RRSIG with keytag {tag} and covering type(s) {types} "
          . "has a remaining validity of {duration} seconds, which is too long.",
          @_;
    },
    REMAINING_SHORT => sub {
        __x    # DNSSEC:REMAINING_SHORT
          "RRSIG with keytag {tag} and covering type(s) {types} "
          . "has a remaining validity of {duration} seconds, which is too short.",
          @_;
    },
    RRSIG_EXPIRATION => sub {
        __x    # DNSSEC:RRSIG_EXPIRATION
          "RRSIG with keytag {tag} and covering type(s) {types} expires at : {date}.", @_;
    },
    RRSET_NOT_SIGNED => sub {
        __x    # DNSSEC:RRSET_NOT_SIGNED
          "Nameserver {ns}/{address} responded with no RRSIG for {rrtype} RRset.", @_;
    },
    RRSIG_BROKEN => sub {
        __x    # DNSSEC:RRSIG_BROKEN
          "Nameserver {ns}/{address} responded with an RRSIG which can not be verified with corresponding DNSKEY (with keytag {keytag})", @_;
    },
    RRSIG_EXPIRED => sub {
        __x    # DNSSEC:RRSIG_EXPIRED
          "RRSIG with keytag {tag} and covering type(s) {types} has already expired (expiration is: {expiration}).", @_;
    },
    RRSIG_NOT_MATCH_DNSKEY => sub {
        __x    # DNSSEC:RRSIG_NOT_MATCH_DNSKEY
          "Nameserver {ns}/{address} responded with an RRSIG with unknown keytag {keytag}.", @_;
    },
    SOA_NOT_SIGNED => sub {
        __x    # DNSSEC:SOA_NOT_SIGNED
          "No RRSIG correctly signed the SOA RRset.", @_;
    },
    SOA_SIGNATURE_NOT_OK => sub {
        __x    # DNSSEC:SOA_SIGNATURE_NOT_OK
          "Trying to verify SOA RRset with signature {signature} gave error '{error}'.", @_;
    },
    SOA_SIGNATURE_OK => sub {
        __x    # DNSSEC:SOA_SIGNATURE_OK
          "RRSIG {signature} correctly signs SOA RRset.", @_;
    },
    SOA_SIGNED => sub {
        __x    # DNSSEC:SOA_SIGNED
          "At least one RRSIG correctly signs the SOA RRset.", @_;
    },
    TEST_ABORTED => sub {
        __x    # DNSSEC:TEST_ABORTED
          "Nameserver {ns/address} for zone {zone} responds with RCODE \"NOERROR\" on a query that is expected to give response with RCODE \"NXDOMAIN\". Test for NSEC and NSEC3 is aborted for this nameserver.", @_;
    },
    TOO_MANY_ITERATIONS => sub {
        __x    # DNSSEC:TOO_MANY_ITERATIONS
          "The number of NSEC3 iterations is {count}, which is too high for key length {keylength}.", @_;
    },
    UNEXPECTED_RESPONSE_DS => sub {
        __x    # DNSSEC:UNEXPECTED_RESPONSE_DS
          "{ns}/{address} responded with an unexpected rcode ({rcode}) on a DS query for zone {zone}.", @_;
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
    my @results;

    if ( my $parent = $zone->parent ) {
        foreach my $ns ( @{ $parent->ns } ) {
            my $ns_args = {
                ns      => $ns->name->string,
                address => $ns->address->short,
                zone    => q{} . $zone->name,
                rrtype  => q{DS},
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
                push @results, info( NO_RESPONSE_DS => $ns_args );
                next;
            }
            elsif ($ds_p->rcode ne q{NOERROR} ) {
                $ns_args->{rcode} = $ds_p->rcode;
                push @results, info( UNEXPECTED_RESPONSE_DS => $ns_args );
                next;
            }
            else {
                my $algorithm2 = 0;
                my @dss = $ds_p->get_records( q{DS}, q{answer} );
                foreach my $ds ( @dss ) {
                    $ns_args->{keytag} = $ds->keytag;
                    $ns_args->{algorithm_number} = $ds->digtype;
                    $ns_args->{algorithm_mnemonic} = $digest_algorithms{$ds->digtype};
                    if ( $ds->digtype == 0 ) {
                        push @results, info( DS_ALGORITHM_NOT_DS => $ns_args );
                    }
                    elsif ( $ds->digtype == 1 or $ds->digtype == 3 ) {
                        push @results, info( DS_ALGORITHM_DEPRECATED => $ns_args );
                    }
                    elsif ( $ds->digtype >= 5 and $ds->digtype <= 255 ) {
                        push @results, info( DS_ALGORITHM_RESERVED => $ns_args );
                    }
                    else {
                        $algorithm2++ if $ds->digtype == 2;
                        push @results, info( DS_ALGORITHM_OK => $ns_args );
                    }
                }
                if ( not $algorithm2 ) {
                    $ns_args->{algorithm_number} = 2;
                    $ns_args->{algorithm_mnemonic} = $digest_algorithms{2};
                    push @results, info( DS_ALGORITHM_MISSING => $ns_args );
                }
            }    
        }
    }

    return @results;
} ## end sub dnssec01

sub dnssec02 {
    my ( $class, $zone ) = @_;
    my @results;

    return if not $zone->parent;

    # 1. Retrieve the DS RR set from the parent zone. If there are no DS RR present, exit the test
    my $ds_p = $zone->parent->query_one( $zone->name, 'DS', { dnssec => 1 } );
    die "No response from parent nameservers" if not $ds_p;
    my %ds = map { $_->keytag => $_ } $ds_p->get_records( 'DS', 'answer' );

    if ( scalar( keys %ds ) == 0 ) {
        push @results,
          info(
            NO_DS => {
                zone => q{} . $zone->name,
                from => $ds_p->answerfrom,
            }
          );
    }
    else {
        push @results,
          info(
            DS_FOUND => {
                keytags => join( q{:}, map { $_->keytag } values %ds ),
            }
          );

        # 2. Retrieve the DNSKEY RR set from the child zone. If there are no DNSKEY RR present, then the test case fail
        my $dnskey_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );

        my %dnskey;
        %dnskey = map { $_->keytag => $_ } $dnskey_p->get_records( 'DNSKEY', 'answer' ) if $dnskey_p;
        if ( scalar( keys %dnskey ) == 0 ) {
            push @results,
              info( NO_DNSKEY => {} );
            return @results;
        }

        # Pick out keys with a tag that a DS has using a hash slice
        my @common = grep { exists $ds{$_->keytag} } values %dnskey;
        if ( @common ) {
            push @results,
              info(
                COMMON_KEYTAGS => {
                    keytags => join( q{:}, map { $_->keytag } @common ),
                }
              );

            my $found = 0;
            my $rfc4509_compliant = 1;
            # 4. Match all DS RR with type digest algorithm “2” with DNSKEY RR from the child. If no DS RRs with algorithm 2 matches a
            #    DNSKEY RR from the child, this test case fails.
            my %ds_digtype2 = map { $_->keytag => $_ } grep { $_->digtype == 2 } $ds_p->get_records( 'DS', 'answer' );
            if ( scalar( keys %ds_digtype2 ) >= 1 ) {
                @common = grep { exists $ds_digtype2{$_->keytag} } values %dnskey;

                foreach my $key ( @common ) {
                    if ( $ds_digtype2{ $key->keytag }->verify( $key ) ) {
                        push @results,
                          info(
                            DS_MATCHES_DNSKEY => {
                                keytag  => $key->keytag,
                                digtype => 2,
                            }
                          );
                        $found = 1;
                    }
                    else {
                        push @results,
                          info(
                            DS_DOES_NOT_MATCH_DNSKEY => {
                                keytag  => $key->keytag,
                                digtype => 2,
                            }
                          );
                    }
                }

                if ( not grep { $_->tag eq q{DS_MATCHES_DNSKEY} } @results ) {
                    $rfc4509_compliant = 0;
                    push @results,
                      info( DS_RFC4509_NOT_VALID => {} );
                }
                
            }

            # 5. Match all DS RR with type digest algorithm “1” with DNSKEY RR from the child. If no DS RRs with algorithm 1 matches a
            #    DNSKEY RR from the child, this test case fails.
            my %ds_digtype1 = map { $_->keytag => $_ } grep { $_->digtype == 1 } $ds_p->get_records( 'DS', 'answer' );
            @common = grep { exists $ds_digtype1{$_->keytag} } values %dnskey;
            foreach my $key ( @common ) {
                if ( $ds_digtype1{ $key->keytag }->verify( $key ) ) {
                    push @results,
                      info(
                        DS_MATCHES_DNSKEY => {
                            keytag  => $key->keytag,
                            digtype => 1,
                        }
                      );
                    $found = 1;
                }
                else {
                    push @results,
                      info(
                        DS_DOES_NOT_MATCH_DNSKEY => {
                            keytag  => $key->keytag,
                            digtype => 1,
                        }
                      );
                }
            }

            if ( $found ) {
                push @results,
                  info( DS_MATCH_FOUND => {} );
            }
            else {
                push @results,
                  info( DS_MATCH_NOT_FOUND => {} );
            }
        } ## end if ( @common )
        else {
            # 3. If no Key Tag from the DS RR matches any Key Tag from the DNSKEY RR, this test case fails
            push @results,
              info(
                NO_COMMON_KEYTAGS => {
                    dstags     => join( q{:}, keys %ds ),
                    dnskeytags => join( q{:}, keys %dnskey ),
                }
              );
        }
    } ## end else [ if ( scalar( keys %ds ...))]

    return @results;
} ## end sub dnssec02

sub dnssec03 {
    my ( $self, $zone ) = @_;
    my @results;

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

    return @results;
} ## end sub dnssec03

sub dnssec04 {
    my ( $self, $zone ) = @_;
    my @results;

    my $dnskey_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $dnskey_p ) {
        return;
    }
    my @keys     = $dnskey_p->get_records( 'DNSKEY', 'answer' );
    my @key_sigs = $dnskey_p->get_records( 'RRSIG',  'answer' );

    my $soa_p = $zone->query_one( $zone->name, 'SOA', { dnssec => 1 } );
    if ( not $soa_p ) {
        return;
    }
    my @soas     = $soa_p->get_records( 'SOA',   'answer' );
    my @soa_sigs = $soa_p->get_records( 'RRSIG', 'answer' );

    foreach my $sig ( @key_sigs, @soa_sigs ) {
        push @results,
          info(
            RRSIG_EXPIRATION => {
                date  => scalar( gmtime($sig->expiration) ),
                tag   => $sig->keytag,
                types => $sig->typecovered,
            }
          );

        my $remaining = $sig->expiration - int( $dnskey_p->timestamp );
        my $result_remaining;
        if ( $remaining < 0 ) {    # already expired
            $result_remaining = info(
                RRSIG_EXPIRED => {
                    expiration => $sig->expiration,
                    tag        => $sig->keytag,
                    types      => $sig->typecovered,
                }
            );
        }
        elsif ( $remaining < ( $DURATION_12_HOURS_IN_SECONDS ) ) {
            $result_remaining = info(
                REMAINING_SHORT => {
                    duration => $remaining,
                    tag      => $sig->keytag,
                    types    => $sig->typecovered,
                }
            );
        }
        elsif ( $remaining > ( $DURATION_180_DAYS_IN_SECONDS ) ) {
            $result_remaining = info(
                REMAINING_LONG => {
                    duration => $remaining,
                    tag      => $sig->keytag,
                    types    => $sig->typecovered,
                }
            );
        }

        my $duration = $sig->expiration - $sig->inception;
        my $result_duration;
        if ( $duration > ( $DURATION_180_DAYS_IN_SECONDS ) ) {
            $result_duration = info(
                DURATION_LONG => {
                    duration => $duration,
                    tag      => $sig->keytag,
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
                    tag      => $sig->keytag,
                    types    => $sig->typecovered,
                }
              );
        }
    } ## end foreach my $sig ( @key_sigs...)

    return @results;
} ## end sub dnssec04

sub dnssec05 {
    my ( $self, $zone ) = @_;
    my @results;

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;

    for my $key ( sort keys %nss ) {
        my $ns = $nss{$key};
        my $ns_args = {
            ns      => $ns->name->string,
            address => $ns->address->short,
        };

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype  => q{DNSKEY},
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype => q{DNSKEY},
                }
              );
            next;
        }

        my $dnskey_p = $ns->query( $zone->name, 'DNSKEY', { dnssec => 1 } );
        if ( not $dnskey_p ) {
            push @results, info( NO_RESPONSE => $ns_args );
            next;
        }

        my @keys = $dnskey_p->get_records( 'DNSKEY', 'answer' );
        if ( not @keys ) {
            push @results, info( NO_RESPONSE_DNSKEY => $ns_args );
            next;
        }

        foreach my $key ( @keys ) {
            my $algo      = $key->algorithm;
            my $algo_args = {
                algorithm   => $algo,
                keytag      => $key->keytag,
                description => $algo_properties{$algo}{description},
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

    return @results;
} ## end sub dnssec05

sub dnssec06 {
    my ( $self, $zone ) = @_;
    my @results;

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

    return @results;
} ## end sub dnssec06

sub dnssec07 {
    my ( $self, $zone ) = @_;
    my @results;

    return if not $zone->parent;
    my $dnskey_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $dnskey_p ) {
        return;
    }
    my ( $dnskey ) = $dnskey_p->get_records( 'DNSKEY', 'answer' );

    my $ds_p = $zone->parent->query_one( $zone->name, 'DS', { dnssec => 1 } );
    if ( not $ds_p ) {
        return;
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

    return @results;
} ## end sub dnssec07

sub dnssec08 {
    my ( $self, $zone ) = @_;
    my @results;

    my $dnskey_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $dnskey_p ) {
        return;
    }
    my @dnskeys = $dnskey_p->get_records( 'DNSKEY', 'answer' );
    my @sigs    = $dnskey_p->get_records( 'RRSIG',  'answer' );

    if ( @dnskeys == 0 or @sigs == 0 ) {
        push @results,
          info(
            NO_KEYS_OR_NO_SIGS => {
                keys => scalar( @dnskeys ),
                sigs => scalar( @sigs ),
            }
          );
        return @results;
    }

    my $ok = 0;
    foreach my $sig ( @sigs ) {
        my $msg  = q{};
        my $time = $dnskey_p->timestamp;
        if ( $sig->verify_time( \@dnskeys, \@dnskeys, $time, $msg ) ) {
            push @results,
              info(
                DNSKEY_SIGNATURE_OK => {
                    signature => $sig->keytag,
                }
              );
            $ok = $sig->keytag;
        }
        else {
            if ( $sig->algorithm >= 12 and $sig->algorithm <= 16 and $msg =~ /Unknown cryptographic algorithm/ ) {
                $msg = q{no }. $algo_properties{$sig->algorithm}{description}. q{ support};
            }
            push @results,
              info(
                DNSKEY_SIGNATURE_NOT_OK => {
                    signature => $sig->keytag,
                    error     => $msg,
                    time      => $time,
                }
              );
        }
    } ## end foreach my $sig ( @sigs )

    if ( $ok ) {
        push @results,
          info(
            DNSKEY_SIGNED => {
                keytag => $ok,
            }
          );
    }
    else {
        push @results,
          info( DNSKEY_NOT_SIGNED => {} );
    }

    return @results;
} ## end sub dnssec08

sub dnssec09 {
    my ( $self, $zone ) = @_;
    my @results;

    my $dnskey_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $dnskey_p ) {
        return;
    }
    my @dnskeys = $dnskey_p->get_records( 'DNSKEY', 'answer' );

    my $soa_p = $zone->query_one( $zone->name, 'SOA', { dnssec => 1 } );
    if ( not $soa_p ) {
        return;
    }
    my @soa  = $soa_p->get_records( 'SOA',   'answer' );
    my @sigs = $soa_p->get_records( 'RRSIG', 'answer' );

    if ( @dnskeys == 0 or @sigs == 0 or @soa == 0 ) {
        push @results,
          info(
            NO_KEYS_OR_NO_SIGS_OR_NO_SOA => {
                keys => scalar( @dnskeys ),
                sigs => scalar( @sigs ),
                soas => scalar( @soa ),
            }
          );
        return @results;
    }

    my $ok = 0;
    foreach my $sig ( @sigs ) {
        my $msg  = q{};
        my $time = $soa_p->timestamp;
        if ( $sig->verify_time( \@soa, \@dnskeys, $time, $msg ) ) {
            push @results,
              info(
                SOA_SIGNATURE_OK => {
                    signature => $sig->keytag,
                }
              );
            $ok = $sig->keytag;
        }
        else {
            if ( $sig->algorithm >= 12 and $sig->algorithm <= 16 and $msg =~ /Unknown cryptographic algorithm/ ) {
                $msg = q{no }. $algo_properties{$sig->algorithm}{description}. q{ support};
            }
            push @results,
              info(
                SOA_SIGNATURE_NOT_OK => {
                    signature => $sig->keytag,
                    error     => $msg,
                }
              );
        }
    } ## end foreach my $sig ( @sigs )

    if ( $ok ) {
        push @results,
          info(
            SOA_SIGNED => {
                keytag => $ok,
            }
          );
    }
    else {
        push @results,
          info( SOA_NOT_SIGNED => {} );
    }

    return @results;
} ## end sub dnssec09

sub dnssec10 {
    my ( $self, $zone ) = @_;
    my $non_existent_domain_name = $zone->name->prepend( q{xx--test-test-test} );
    my @results;

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;
    my (%nsec_zone, %nsec3_zone, %no_dnssec_zone);

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};
        my $ns_args = {
            ns      => $ns->name->string,
            address => $ns->address->short,
        };

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            $ns_args->{rrtype} = q{A};
            push @results, info( IPV6_DISABLED => $ns_args );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            $ns_args->{rrtype} = q{A};
            push @results, info( IPV4_DISABLED => $ns_args );
            next;
        }

        my $a_p = $ns->query( $non_existent_domain_name , q{A}, { usevc => 0, dnssec => 1 } );
        if ( not $a_p ) {
            push @results, info( NO_RESPONSE => $ns_args );
        }
        elsif ($a_p->rcode eq q{NOERROR} ) {
            $ns_args->{zone} = $zone->name->string;
            push @results, info( TEST_ABORTED => $ns_args );
        }
        elsif ($a_p->rcode ne q{NXDOMAIN} ) {
            $ns_args->{rcode} = $a_p->rcode;
            push @results, info( INVALID_RCODE => $ns_args );
        }
        else {
            my @nsec  = $a_p->get_records( q{NSEC}, q{authority} );
            my @nsec3 = $a_p->get_records( q{NSEC3}, q{authority} );
            if ( scalar @nsec and scalar @nsec3 ) {
                $ns_args->{zone} = $zone->name->string;
                push @results, info( MIXED_NSEC_NSEC3 => $ns_args );
            }
            elsif ( not scalar @nsec and not scalar @nsec3 ) {
                $ns_args->{zone} = $zone->name->string;
                $no_dnssec_zone{$ns->address->short}++;
                push @results, info( NO_NSEC_NSEC3 => $ns_args );
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
                                    push @results, info( NSEC_SIG_VERIFY_ERROR => { error => q{DNSKEY missing}, sig => $sig->keytag } );
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
                                            error => $msg,
                                            sig   => $sig->keytag,
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
                    push @results, info( NSEC_COVERS_NOT => {} );
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
                                    push @results, info( NSEC3_SIG_VERIFY_ERROR => { error => 'DNSKEY missing', sig => $sig->keytag } );
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
                                            error => $msg,
                                            sig   => $sig->keytag,
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
                    push @results, info( NSEC3_COVERS_NOT => {} );
                }
            }
        }
    }

    if ( scalar keys %no_dnssec_zone and ( scalar keys %nsec_zone or scalar keys %nsec3_zone ) ) {
        push @results, info( INCONSISTENT_DNSSEC => { zone => $zone->name->string } );
    }
    elsif ( scalar keys %no_dnssec_zone and not scalar keys %nsec_zone and not scalar keys %nsec3_zone ) {
        push @results, info( BROKEN_DNSSEC => { zone => $zone->name->string } );
    }
    elsif ( scalar keys %nsec_zone and scalar keys %nsec3_zone ) {
        push @results, info( INCONSISTENT_NSEC_NSEC3 => { zone => $zone->name->string } );
    }
    elsif ( scalar keys %nsec_zone and not grep { $_->tag eq q{MIXED_NSEC_NSEC3} } @results ) {
        push @results, info( HAS_NSEC => {} );
    }
    elsif ( scalar keys %nsec3_zone and not grep { $_->tag eq q{MIXED_NSEC_NSEC3} } @results ) {
        push @results, info( HAS_NSEC3 => {} );
    }

    return @results;
} ## end sub dnssec10

### The error reporting in dnssec11 is deliberately simple, since the point of
### the test case is to give a pass/fail test for the delegation step from the
### parent as a whole.
sub dnssec11 {
    my ( $class, $zone ) = @_;
    my @results;

    my $ds_p = $zone->parent->query_auth( $zone->name->string, 'DS' );
    if ( not $ds_p ) {
        return info( DELEGATION_NOT_SIGNED => { keytag => 'none', reason => 'no_ds_packet' } );
    }

    my $dnskey_p = $zone->query_auth( $zone->name->string, 'DNSKEY', { dnssec => 1 } );
    if ( not $dnskey_p ) {
        return info( DELEGATION_NOT_SIGNED => { keytag => 'none', reason => 'no_dnskey_packet' } );
    }

    my %ds = map { $_->keytag => $_ } $ds_p->get_records_for_name( 'DS', $zone->name->string );
    my %dnskey = map { $_->keytag => $_ } $dnskey_p->get_records_for_name( 'DNSKEY', $zone->name->string );
    my %rrsig  = map { $_->keytag => $_ } $dnskey_p->get_records_for_name( 'RRSIG',  $zone->name->string );

    my $pass = 0;
    my @fail;
    if ( scalar( keys %ds ) > 0 ) {
        foreach my $tag ( keys %ds ) {
            my $ds  = $ds{$tag};
            my $key = $dnskey{$tag};
            my $sig = $rrsig{$tag};

            if ( $key ) {
                if ( $ds->verify( $key ) ) {
                    if ( $sig ) {
                        my $msg = '';
                        my $ok =
                          $sig->verify_time( [ values %dnskey ], [ values %dnskey ], $dnskey_p->timestamp, $msg );
                        if ( $ok ) {
                            $pass = $tag;
                        }
                        else {
                            if ( $sig->algorithm >= 12 and $sig->algorithm <= 16 and $msg =~ /Unknown cryptographic algorithm/ ) {
                                $msg = q{no }. $algo_properties{$sig->algorithm}{description}. q{ support};
                            }
                            push @fail, "signature: $msg" ;
                        }
                    }
                    else {
                        push @fail, 'no_signature';
                    }
                }
                else {
                    push @fail, 'dnskey_no_match';
                }
            } ## end if ( $key )
            else {
                push @fail, 'no_dnskey';
            }
        } ## end foreach my $tag ( keys %ds )
    } ## end if ( scalar( keys %ds ...))
    else {
        push @fail, 'no_ds';
    }

    if ($pass) {
        push @results, info( DELEGATION_SIGNED => { keytag => $pass } )
    } else {
        push @results, info( DELEGATION_NOT_SIGNED => { keytag => 'info', reason => join(';', @fail) } )
    }

    return @results;
} ## end sub dnssec11

sub dnssec13 {
    my ( $class, $zone ) = @_;
    my @results;
    my @dnskey_rrs;
    my $all_algo_signed = 1;
    my $DNSKEY_algorithm_exists = 0;

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};
        my $ns_args = {
            ns      => $ns->name->string,
            address => $ns->address->short,
        };

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype => q{DNSKEY},
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype => q{DNSKEY},
                }
              );
            next;
        }

        my %keytags;
        my @algorithms;
        foreach my $query_type ( qw{DNSKEY SOA NS} ) {

            $ns_args->{rrtype} = $query_type;
            my $p = $ns->query( $zone->name, $query_type, { dnssec => 1, usevc => 0 } );
            if ( not $p ) {
                push @results, info( NO_RESPONSE => $ns_args );
                next;
            }

            my @rrs = $p->get_records( $query_type, q{answer} );
            if ( not scalar @rrs ) {
                $all_algo_signed = 0;
                push @results, info( NO_RESPONSE_RRSET => $ns_args );
                next;
            }

            if ( $query_type eq q{DNSKEY} ) {
                %keytags = map { $_->keytag => $_ } @rrs;                
                @algorithms = uniq map { $_->algorithm } @rrs;
                if ( scalar @algorithms ) {
                    $DNSKEY_algorithm_exists = 1;
                }
            }

            my @sigs = $p->get_records( q{RRSIG},  q{answer} );
            if ( not scalar @sigs ) {
                $all_algo_signed = 0;
                push @results, info( RRSET_NOT_SIGNED => $ns_args );
                next;
            }

            foreach my $algorithm ( @algorithms ) {
                if ( not scalar grep { $_->algorithm == $algorithm } @sigs ) {
                    $all_algo_signed = 0;
                    $ns_args->{algorithm} = $algorithm;
                    push @results, info( ALGO_NOT_SIGNED_RRSET => $ns_args );
                }
            }

            foreach my $sig ( @sigs ) {
                my @keys = ($keytags{$sig->keytag});
                if ( not scalar @keys ) {
                    $all_algo_signed = 0;
                    $ns_args->{keytag} = $sig->keytag;
                    push @results, info( RRSIG_NOT_MATCH_DNSKEY => $ns_args );
                }
                elsif ( not $sig->verify( \@rrs, \@keys ) ) {
                    $all_algo_signed = 0;
                    $ns_args->{keytag} = $sig->keytag;
                    push @results, info( RRSIG_BROKEN => $ns_args );
                }
            }

        }
    }

    if ( $DNSKEY_algorithm_exists and $all_algo_signed ) {
        push @results, info( ALL_ALGO_SIGNED => {} );
    }

    return @results;

} ## end sub dnssec13

sub dnssec14 {
    my ( $class, $zone ) = @_;
    my @results;
    my @dnskey_rrs;

    my @nss_del   = @{ Zonemaster::Engine::TestMethods->method4( $zone ) };
    my @nss_child = @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
    my %nss       = map { $_->name->string . '/' . $_->address->short => $_ } @nss_del, @nss_child;

    for my $nss_key ( sort keys %nss ) {
        my $ns = $nss{$nss_key};
        my $ns_args = {
            ns      => $ns->name->string,
            address => $ns->address->short,
        };

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype => q{DNSKEY},
                }
              );
            next;
        }

        if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv4}) and $ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    rrtype => q{DNSKEY},
                }
              );
            next;
        }

        my $dnskey_p = $ns->query( $zone->name, 'DNSKEY', { dnssec => 1, usevc => 0 } );
        if ( not $dnskey_p ) {
            push @results, info( NO_RESPONSE => $ns_args );
            next;
        }

        my @keys = $dnskey_p->get_records( 'DNSKEY', 'answer' );
        if ( not @keys ) {
            push @results, info( NO_RESPONSE_DNSKEY => $ns_args );
            next;
        } else {
            push @dnskey_rrs, @keys;
        }
    }

    foreach my $key ( @dnskey_rrs ) {
        my $algo = $key->algorithm;  

        next if not exists $rsa_key_size_details{$algo};

        my $algo_args = {
            algorithm_number      => $algo,
            algorithm_description => $algo_properties{$algo},
            keytag                => $key->keytag,
            keysize               => $key->keysize,
            keysizemin            => $rsa_key_size_details{$algo}{min_size},
            keysizemax            => $rsa_key_size_details{$algo}{max_size},
            keysizerec            => $rsa_key_size_details{$algo}{rec_size},
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

    } ## end foreach my $key ( @keys )

    if ( scalar @dnskey_rrs and scalar @results == scalar grep { $_->tag eq 'NO_RESPONSE' } @results) {
        push @results, info( KEY_SIZE_OK => {} );
    }

    return @results;
} ## end sub dnssec14

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

=back

=cut
