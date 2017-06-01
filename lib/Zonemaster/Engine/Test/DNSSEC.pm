package Zonemaster::Engine::Test::DNSSEC;

use version; our $VERSION = version->declare("v1.0.6");

###
### This test module implements DNSSEC tests.
###

use strict;
use warnings;

use 5.014002;

use Zonemaster::Engine;
use Zonemaster::Engine::Util;
use Zonemaster::Engine::Constants qw[:algo :soa];
use List::Util qw[min];
use List::MoreUtils qw[none];

use Carp;

### Table fetched from IANA on 2017-03-09
Readonly::Hash our %algo_properties => (
    0 => {
        status      => $ALGO_STATUS_RESERVED,
        description => q{Reserved},
    },
    1 => {
        status      => $ALGO_STATUS_DEPRECATED,
        description => q{RSA/MD5},
        mnemonic    => q{RSAMD5},
    },
    2 => {
        status      => $ALGO_STATUS_VALID,
        description => q{Diffie-Hellman},
        mnemonic    => q{DH},
    },
    3 => {
        status      => $ALGO_STATUS_VALID,
        description => q{DSA/SHA1},
        mnemonic    => q{DSA},
    },
    4 => {
        status      => $ALGO_STATUS_RESERVED,
        description => q{Reserved},
    },
    5 => {
        status      => $ALGO_STATUS_VALID,
        description => q{RSA/SHA1},
        mnemonic    => q{RSASHA1},
    },
    6 => {
        status      => $ALGO_STATUS_VALID,
        description => q{DSA-NSEC3-SHA1},
        mnemonic    => q{DSA-NSEC3-SHA1},
    },
    7 => {
        status      => $ALGO_STATUS_VALID,
        description => q{RSASHA1-NSEC3-SHA1},
        mnemonic    => q{RSASHA1-NSEC3-SHA1},
    },
    8 => {
        status      => $ALGO_STATUS_VALID,
        description => q{RSA/SHA-256},
        mnemonic    => q{RSA/SHA256},
    },
    9 => {
        status      => $ALGO_STATUS_RESERVED,
        description => q{Reserved},
    },
    10 => {
        status      => $ALGO_STATUS_VALID,
        description => q{RSA/SHA-512},
        mnemonic    => q{RSA/SHA512},
    },
    11 => {
        status      => $ALGO_STATUS_RESERVED,
        description => q{Reserved},
    },
    12 => {
        status      => $ALGO_STATUS_VALID,
        description => q{GOST R 34.10-2001},
        mnemonic    => q{ECC-GOST},
    },
    13 => {
        status      => $ALGO_STATUS_VALID,
        description => q{ECDSA Curve P-256 with SHA-256},
        mnemonic    => q{ECDSAP256SHA256},
    },
    14 => {
        status      => $ALGO_STATUS_VALID,
        description => q{ECDSA Curve P-384 with SHA-384},
        mnemonic    => q{ECDSAP384SHA384},
    },
    15 => {
        status      => $ALGO_STATUS_VALID,
        description => q{Ed25519},
        mnemonic    => q{Ed25519},
    },
    16 => {
        status      => $ALGO_STATUS_VALID,
        description => q{Ed448},
        mnemonic    => q{Ed448},
    },
    (
        map { $_ => { status => $ALGO_STATUS_UNASSIGNED, description => q{Unassigned}, } } ( 17 .. 122 )
    ),
    (
        map { $_ => { status => $ALGO_STATUS_RESERVED, description => q{Reserved}, } } ( 123 .. 251 )
    ),
    252 => {
        status      => $ALGO_STATUS_RESERVED,
        description => q{Reserved for Indirect Keys},
        mnemonic    => q{INDIRECT},
    },
    253 => {
        status      => $ALGO_STATUS_PRIVATE,
        description => q{private algorithm},
        mnemonic    => q{PRIVATEDNS},
    },
    254 => {
        status      => $ALGO_STATUS_PRIVATE,
        description => q{private algorithm OID},
        mnemonic    => q{PRIVATEOID},
    },
    255 => {
        status      => $ALGO_STATUS_RESERVED,
        description => q{Reserved},
    },
);

###
### Entry points
###

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    if ( Zonemaster::Engine->config->should_run('dnssec07') ) {
        push @results, $class->dnssec07( $zone );
    }

    if ( Zonemaster::Engine->config->should_run('dnssec07') and grep { $_->tag eq 'NEITHER_DNSKEY_NOR_DS' } @results ) {
        push @results,
          info(
            NOT_SIGNED => {
                zone => q{} . $zone->name
            }
          );

    } else {

        if ( Zonemaster::Engine->config->should_run('dnssec01') ) {
            push @results, $class->dnssec01( $zone );
        }

        if ( none { $_->tag eq 'NO_DS' } @results ) {
            if ( Zonemaster::Engine->config->should_run('dnssec02') ) {
                push @results, $class->dnssec02( $zone );
            }
        }

        if ( Zonemaster::Engine->config->should_run('dnssec03') ) {
            push @results, $class->dnssec03( $zone );
        }

        if ( Zonemaster::Engine->config->should_run('dnssec04') ) {
            push @results, $class->dnssec04( $zone );
        }

        if ( Zonemaster::Engine->config->should_run('dnssec05') ) {
            push @results, $class->dnssec05( $zone );
        }
    
        if ( grep { $_->tag eq q{DNSKEY_BUT_NOT_DS} or $_->tag eq q{DNSKEY_AND_DS} } @results ) {
            if ( Zonemaster::Engine->config->should_run('dnssec06') ) {
                push @results, $class->dnssec06( $zone );
            }
        }
        else {
            push @results,
              info( ADDITIONAL_DNSKEY_SKIPPED => {} );
        }

        if ( Zonemaster::Engine->config->should_run('dnssec08') ) {
            push @results, $class->dnssec08( $zone );
        }

        if ( Zonemaster::Engine->config->should_run('dnssec09') ) {
            push @results, $class->dnssec09( $zone );
        }

        if ( Zonemaster::Engine->config->should_run('dnssec10') ) {
            push @results, $class->dnssec10( $zone );
        }

        if ( Zonemaster::Engine->config->should_run('dnssec11') ) {
            push @results, $class->dnssec11( $zone );
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
              DS_DIGTYPE_OK
              DS_DIGTYPE_NOT_OK
              NO_DS
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
              ALGORITHM_RESERVED
              ALGORITHM_UNASSIGNED
              ALGORITHM_PRIVATE
              ALGORITHM_OK
              ALGORITHM_UNKNOWN
              KEY_DETAILS
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
              INVALID_NAME_RCODE
              NSEC_COVERS
              NSEC_COVERS_NOT
              NSEC_SIG_VERIFY_ERROR
              NSEC_SIGNED
              NSEC_NOT_SIGNED
              HAS_NSEC
              NSEC3_COVERS
              NSEC3_COVERS_NOT
              NSEC3_SIG_VERIFY_ERROR
              NSEC3_SIGNED
              NSEC3_NOT_SIGNED
              HAS_NSEC3
              HAS_NSEC3_OPTOUT )
        ],
        dnssec11 => [
            qw(
              DELEGATION_NOT_SIGNED
              DELEGATION_SIGNED
              ),
        ],
    };
} ## end sub metadata

sub translation {
    return {
        "ADDITIONAL_DNSKEY_SKIPPED" => "No DNSKEYs found. Additional tests skipped.",
        "ALGORITHM_DEPRECATED" =>
          "The DNSKEY with tag {keytag} uses deprecated algorithm number {algorithm}/({description}).",
        "ALGORITHM_OK" =>
          "The DNSKEY with tag {keytag} uses algorithm number {algorithm}/({description}), which is OK.",
        "ALGORITHM_RESERVED" =>
          "The DNSKEY with tag {keytag} uses reserved algorithm number {algorithm}/({description}).",
        "ALGORITHM_UNASSIGNED" =>
          "The DNSKEY with tag {keytag} uses unassigned algorithm number {algorithm}/({description}).",
        "ALGORITHM_PRIVATE" =>
          "The DNSKEY with tag {keytag} uses private algorithm number {algorithm}/({description}).",
        "ALGORITHM_UNKNOWN"       => "The DNSKEY with tag {keytag} uses unknown algorithm number {algorithm}.",
        "COMMON_KEYTAGS"          => "There are both DS and DNSKEY records with key tags {keytags}.",
        "DNSKEY_AND_DS"           => "{parent} sent a DS record, and {child} a DNSKEY record.",
        "DNSKEY_BUT_NOT_DS"       => "{child} sent a DNSKEY record, but {parent} did not send a DS record.",
        "DNSKEY_NOT_SIGNED"       => "The apex DNSKEY RRset was not correctly signed.",
        "DNSKEY_SIGNATURE_NOT_OK" => "Signature for DNSKEY with tag {signature} failed to verify with error '{error}'.",
        "DNSKEY_SIGNATURE_OK"     => "A signature for DNSKEY with tag {signature} was correctly signed.",
        "DNSKEY_SIGNED"           => "The apex DNSKEY RRset was correcly signed.",
        "DS_BUT_NOT_DNSKEY"       => "{parent} sent a DS record, but {child} did not send a DNSKEY record.",
        "DS_DIGTYPE_NOT_OK"       => "DS record with keytag {keytag} uses forbidden digest type {digtype}.",
        "DS_DIGTYPE_OK"           => "DS record with keytag {keytag} uses digest type {digtype}, which is OK.",
        "DS_DOES_NOT_MATCH_DNSKEY" => "DS record with keytag {keytag} and digest type {digtype} does not match the DNSKEY with the same tag.",
        "DS_FOUND"                 => "Found DS records with tags {keytags}.",
        "DS_MATCHES_DNSKEY"        => "DS record with keytag {keytag} and digest type {digtype} matches the DNSKEY with the same tag.",
        "DS_MATCH_FOUND"           => "At least one DS record with a matching DNSKEY record was found.",
        "DS_MATCH_NOT_FOUND"       => "No DS record with a matching DNSKEY record was found.",
        "DS_RFC4509_NOT_VALID"     => "Existing DS with digest type 2, while they do not match DNSKEY records, prevent use of DS with digest type 1 (RFC4509, section 3).",
        "DURATION_LONG" =>
"RRSIG with keytag {tag} and covering type(s) {types} has a duration of {duration} seconds, which is too long.",
        "DURATION_OK" =>
"RRSIG with keytag {tag} and covering type(s) {types} has a duration of {duration} seconds, which is just fine.",
        "RRSIG_EXPIRATION" =>
          "RRSIG with keytag {tag} and covering type(s) {types} expires at : {date}.",
        "RRSIG_EXPIRED" =>
          "RRSIG with keytag {tag} and covering type(s) {types} has already expired (expiration is: {expiration}).",
        "REMAINING_SHORT" =>
"RRSIG with keytag {tag} and covering type(s) {types} has a remaining validity of {duration} seconds, which is too short.",
        "REMAINING_LONG" =>
"RRSIG with keytag {tag} and covering type(s) {types} has a remaining validity of {duration} seconds, which is too long.",
        "EXTRA_PROCESSING_BROKEN" => "Server at {server} sent {keys} DNSKEY records, and {sigs} RRSIG records.",
        "EXTRA_PROCESSING_OK"     => "Server at {server} sent {keys} DNSKEY records and {sigs} RRSIG records.",
        "HAS_NSEC"                => "The zone has NSEC records.",
        "HAS_NSEC3"               => "The zone has NSEC3 records.",
        "HAS_NSEC3_OPTOUT"        => "The zone has NSEC3 opt-out records.",
        "INVALID_NAME_RCODE" => "When asked for the name {name}, which must not exist, the response had RCODE {rcode}.",
        "ITERATIONS_OK"      => "The number of NSEC3 iterations is {count}, which is OK.",
        "KEY_DETAILS"        => "Key with keytag {keytag} details : Size = {keysize}, Flags ({sep}, {rfc5011}).",
        "MANY_ITERATIONS"    => "The number of NSEC3 iterations is {count}, which is on the high side.",
        "NEITHER_DNSKEY_NOR_DS" => "There are neither DS nor DNSKEY records for the zone.",
        "NOT_SIGNED"         => "The zone is not signed with DNSSEC.",
        "NO_COMMON_KEYTAGS"     => "No DS record had a DNSKEY with a matching keytag.",
        "NO_DNSKEY"             => "No DNSKEYs were returned.",
        "NO_DS"                 => "{from} returned no DS records for {zone}.",
        "NO_KEYS_OR_NO_SIGS" =>
          "Cannot test DNSKEY signatures, because we got {keys} DNSKEY records and {sigs} RRSIG records.",
        "NO_KEYS_OR_NO_SIGS_OR_NO_SOA" =>
"Cannot test SOA signatures, because we got {keys} DNSKEY records, {sigs} RRSIG records and {soas} SOA records.",
        "NO_NSEC3PARAM"          => "{server} returned no NSEC3PARAM records.",
        "NSEC3_SIG_VERIFY_ERROR" => "Trying to verify NSEC3 RRset with RRSIG {sig} gave error '{error}'.",
        "NSEC3_COVERS"           => "NSEC3 record covers {name}.",
        "NSEC3_COVERS_NOT"       => "NSEC3 record does not cover {name}.",
        "NSEC3_NOT_SIGNED"       => "No signature correctly signed the NSEC3 RRset.",
        "NSEC3_SIGNED"           => "At least one signature correctly signed the NSEC3 RRset.",
        "NSEC_COVERS"            => "NSEC covers {name}.",
        "NSEC_COVERS_NOT"        => "NSEC does not cover {name}.",
        "NSEC_NOT_SIGNED"        => "No signature correctly signed the NSEC RRset.",
        "NSEC_SIGNED"            => "At least one signature correctly signed the NSEC RRset.",
        "NSEC_SIG_VERIFY_ERROR"  => "Trying to verify NSEC RRset with RRSIG {sig} gave error '{error}'.",
        "SOA_NOT_SIGNED"         => "No RRSIG correctly signed the SOA RRset.",
        "SOA_SIGNATURE_NOT_OK"   => "Trying to verify SOA RRset with signature {signature} gave error '{error}'.",
        "SOA_SIGNATURE_OK"       => "RRSIG {signature} correctly signs SOA RRset.",
        "SOA_SIGNED"             => "At least one RRSIG correctly signs the SOA RRset.",
        "TOO_MANY_ITERATIONS" =>
          "The number of NSEC3 iterations is {count}, which is too high for key length {keylength}.",
        "DELEGATION_NOT_SIGNED" => "Delegation from parent to child is not properly signed {reason}.",
        "DELEGATION_SIGNED"     => "Delegation from parent to child is properly signed.",
    };
} ## end sub translation

sub policy {
    return {
        "ADDITIONAL_DNSKEY_SKIPPED"    => "DEBUG",
        "ALGORITHM_DEPRECATED"         => "WARNING",
        "ALGORITHM_OK"                 => "INFO",
        "ALGORITHM_RESERVED"           => "ERROR",
        "ALGORITHM_UNASSIGNED"         => "ERROR",
        "COMMON_KEYTAGS"               => "INFO",
        "DNSKEY_AND_DS"                => "DEBUG",
        "DNSKEY_BUT_NOT_DS"            => "WARNING",
        "DNSKEY_NOT_SIGNED"            => "ERROR",
        "DNSKEY_SIGNATURE_NOT_OK"      => "ERROR",
        "DNSKEY_SIGNATURE_OK"          => "DEBUG",
        "DNSKEY_SIGNED"                => "DEBUG",
        "DS_BUT_NOT_DNSKEY"            => "ERROR",
        "DS_DIGTYPE_NOT_OK"            => "ERROR",
        "DS_DIGTYPE_OK"                => "DEBUG",
        "DS_DOES_NOT_MATCH_DNSKEY"     => "ERROR",
        "DS_FOUND"                     => "INFO",
        "DS_MATCHES_DNSKEY"            => "INFO",
        "DS_MATCH_FOUND"               => "INFO",
        "DS_MATCH_NOT_FOUND"           => "ERROR",
        "DS_RFC4509_NOT_VALID"         => "ERROR",
        "DURATION_LONG"                => "WARNING",
        "DURATION_OK"                  => "DEBUG",
        "EXTRA_PROCESSING_BROKEN"      => "ERROR",
        "EXTRA_PROCESSING_OK"          => "DEBUG",
        "HAS_NSEC"                     => "INFO",
        "HAS_NSEC3"                    => "INFO",
        "HAS_NSEC3_OPTOUT"             => "INFO",
        "INVALID_NAME_RCODE"           => "NOTICE",
        "ITERATIONS_OK"                => "DEBUG",
        "KEY_DETAILS"                  => "DEBUG",
        "MANY_ITERATIONS"              => "NOTICE",
        "NEITHER_DNSKEY_NOR_DS"        => "NOTICE",
        "NOT_SIGNED"                   => "NOTICE",
        "NO_COMMON_KEYTAGS"            => "ERROR",
        "NO_DNSKEY"                    => "ERROR",
        "NO_DS"                        => "NOTICE",
        "NO_KEYS_OR_NO_SIGS"           => "DEBUG",
        "NO_KEYS_OR_NO_SIGS_OR_NO_SOA" => "DEBUG",
        "NO_NSEC3PARAM"                => "DEBUG",
        "NSEC3_SIG_VERIFY_ERROR"       => "ERROR",
        "NSEC3_COVERS"                 => "DEBUG",
        "NSEC3_COVERS_NOT"             => "WARNING",
        "NSEC3_NOT_SIGNED"             => "ERROR",
        "NSEC3_SIGNED"                 => "DEBUG",
        "NSEC_COVERS"                  => "DEBUG",
        "NSEC_COVERS_NOT"              => "WARNING",
        "NSEC_NOT_SIGNED"              => "ERROR",
        "NSEC_SIGNED"                  => "DEBUG",
        "NSEC_SIG_VERIFY_ERROR"        => "ERROR",
        "REMAINING_LONG"               => "WARNING",
        "REMAINING_SHORT"              => "WARNING",
        "RRSIG_EXPIRATION"             => "INFO",
        "RRSIG_EXPIRED"                => "ERROR",
        "SOA_NOT_SIGNED"               => "ERROR",
        "SOA_SIGNATURE_NOT_OK"         => "ERROR",
        "SOA_SIGNATURE_OK"             => "DEBUG",
        "SOA_SIGNED"                   => "DEBUG",
        "TOO_MANY_ITERATIONS"          => "WARNING",
        "DELEGATION_NOT_SIGNED"        => "NOTICE",
        "DELEGATION_SIGNED"            => "INFO",
    };
} ## end sub policy

sub version {
    return "$Zonemaster::Engine::Test::DNSSEC::VERSION";
}

###
### Tests
###

sub dnssec01 {
    my ( $class, $zone ) = @_;
    my @results;

    my %type = ( 1 => 'SHA-1', 2 => 'SHA-256', 3 => 'GOST R 34.11-94', 4 => 'SHA-384' );

    return if not $zone->parent;
    my $ds_p = $zone->parent->query_one( $zone->name, 'DS', { dnssec => 1 } );
    die "No response from parent nameservers" if not $ds_p;
    my @ds = $ds_p->get_records( 'DS', 'answer' );

    if ( @ds == 0 ) {
        push @results,
          info(
            NO_DS => {
                zone => q{} . $zone->name,
                from => $ds_p->answerfrom
            }
          );
    }
    else {
        foreach my $ds ( @ds ) {
            if ( $type{ $ds->digtype } ) {
                push @results,
                  info(
                    DS_DIGTYPE_OK => {
                        keytag  => $ds->keytag,
                        digtype => $type{ $ds->digtype },
                    }
                  );
            }
            else {
                push @results,
                  info(
                    DS_DIGTYPE_NOT_OK => {
                        keytag  => $ds->keytag,
                        digtype => $ds->digtype
                    }
                  );
            }
        } ## end foreach my $ds ( @ds )
    } ## end else [ if ( @ds == 0 ) ]

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

    my $key_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $key_p ) {
        return;
    }
    my @keys     = $key_p->get_records( 'DNSKEY', 'answer' );
    my @key_sigs = $key_p->get_records( 'RRSIG',  'answer' );

    my $soa_p = $zone->query_one( $zone->name, 'SOA', { dnssec => 1 } );
    if ( not $soa_p ) {
        return;
    }
    my @soas     = $soa_p->get_records( 'SOA',   'answer' );
    my @soa_sigs = $soa_p->get_records( 'RRSIG', 'answer' );

    foreach my $sig ( @key_sigs, @soa_sigs ) {
        my $duration  = $sig->expiration - $sig->inception;
        my $remaining = $sig->expiration - int( $key_p->timestamp );
        push @results,
          info(
            RRSIG_EXPIRATION => {
                date  => scalar( gmtime($sig->expiration) ),
                tag   => $sig->keytag,
                types => $sig->typecovered,
            }
          );
        if ( $remaining < 0 ) {    # already expired
            push @results,
              info(
                RRSIG_EXPIRED => {
                    expiration => $sig->expiration,
                    tag        => $sig->keytag,
                    types      => $sig->typecovered,
                }
              );
        }
        elsif ( $remaining < ( $DURATION_12_HOURS_IN_SECONDS ) ) {
            push @results,
              info(
                REMAINING_SHORT => {
                    duration => $remaining,
                    tag      => $sig->keytag,
                    types    => $sig->typecovered,
                }
              );
        }
        elsif ( $remaining > ( $DURATION_180_DAYS_IN_SECONDS ) ) {
            push @results,
              info(
                REMAINING_LONG => {
                    duration => $remaining,
                    tag      => $sig->keytag,
                    types    => $sig->typecovered,
                }
              );
        }
        elsif ( $duration > ( $DURATION_180_DAYS_IN_SECONDS ) ) {
            push @results,
              info(
                DURATION_LONG => {
                    duration => $duration,
                    tag      => $sig->keytag,
                    types    => $sig->typecovered,
                }
              );
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

    my $key_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $key_p ) {
        return;
    }
    my @keys = $key_p->get_records( 'DNSKEY', 'answer' );

    foreach my $key ( @keys ) {
        my $algo = $key->algorithm;
        if ( $algo_properties{$algo}{status} == $ALGO_STATUS_DEPRECATED ) {
            push @results,
              info(
                ALGORITHM_DEPRECATED => {
                    algorithm   => $algo,
                    keytag      => $key->keytag,
                    description => $algo_properties{$algo}{description},
                }
              );
        }
        elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_RESERVED ) {
            push @results,
              info(
                ALGORITHM_RESERVED => {
                    algorithm   => $algo,
                    keytag      => $key->keytag,
                    description => $algo_properties{$algo}{description},
                }
              );
        }
        elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_UNASSIGNED ) {
            push @results,
              info(
                ALGORITHM_UNASSIGNED => {
                    algorithm   => $algo,
                    keytag      => $key->keytag,
                    description => $algo_properties{$algo}{description},
                }
              );
        }
        elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_PRIVATE ) {
            push @results,
              info(
                ALGORITHM_PRIVATE => {
                    algorithm   => $algo,
                    keytag      => $key->keytag,
                    description => $algo_properties{$algo}{description},
                }
              );
        }
        elsif ( $algo_properties{$algo}{status} == $ALGO_STATUS_VALID ) {
            push @results,
              info(
                ALGORITHM_OK => {
                    algorithm   => $algo,
                    keytag      => $key->keytag,
                    description => $algo_properties{$algo}{description},
                }
              );
            if ( $key->flags & 256 ) { # This is a Key
                push @results,
                  info(
                    KEY_DETAILS => {
                        keytag  => $key->keytag,
                        keysize => $key->keysize,
                        sep     => $key->flags & 1 ? q{SEP bit set} : q{SEP bit *not* set},
                        rfc5011 => $key->flags & 128 ? q{RFC 5011 revocation bit set} : q{RFC 5011 revocation bit *not* set},
                    }
                );
            }
        }
        else {
            push @results,
              info(
                ALGORITHM_UNKNOWN => {
                    algorithm => $algo,
                    keytag    => $key->keytag,
                }
              );
        }
    } ## end foreach my $key ( @keys )

    return @results;
} ## end sub dnssec05

sub dnssec06 {
    my ( $self, $zone ) = @_;
    my @results;

    my $key_aref = $zone->query_all( $zone->name, 'DNSKEY', { dnssec => 1 } );
    foreach my $key_p ( @{$key_aref} ) {
        next if not $key_p;

        my @keys = $key_p->get_records( 'DNSKEY', 'answer' );
        my @sigs = $key_p->get_records( 'RRSIG',  'answer' );
        if ( @sigs > 0 and @keys > 0 ) {
            push @results,
              info(
                EXTRA_PROCESSING_OK => {
                    server => $key_p->answerfrom,
                    keys   => scalar( @keys ),
                    sigs   => scalar( @sigs ),
                }
              );
        }
        elsif ( $key_p->rcode eq q{NOERROR} and ( @sigs == 0 or @keys == 0 ) ) {
            push @results,
              info(
                EXTRA_PROCESSING_BROKEN => {
                    server => $key_p->answerfrom,
                    keys   => scalar( @keys ),
                    sigs   => scalar( @sigs )
                }
              );
        }
    } ## end foreach my $key_p ( @{$key_aref...})

    return @results;
} ## end sub dnssec06

sub dnssec07 {
    my ( $self, $zone ) = @_;
    my @results;

    return if not $zone->parent;
    my $key_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $key_p ) {
        return;
    }
    my ( $dnskey ) = $key_p->get_records( 'DNSKEY', 'answer' );

    my $ds_p = $zone->parent->query_one( $zone->name, 'DS', { dnssec => 1 } );
    if ( not $ds_p ) {
        return;
    }
    my ( $ds ) = $ds_p->get_records( 'DS', 'answer' );

    if ( $dnskey and not $ds ) {
        push @results,
          info(
            DNSKEY_BUT_NOT_DS => {
                child  => $key_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }
    elsif ( $dnskey and $ds ) {
        push @results,
          info(
            DNSKEY_AND_DS => {
                child  => $key_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }
    elsif ( not $dnskey and $ds ) {
        push @results,
          info(
            DS_BUT_NOT_DNSKEY => {
                child  => $key_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }
    else {
        push @results,
          info(
            NEITHER_DNSKEY_NOR_DS => {
                child  => $key_p->answerfrom,
                parent => $ds_p->answerfrom,
            }
          );
    }

    return @results;
} ## end sub dnssec07

sub dnssec08 {
    my ( $self, $zone ) = @_;
    my @results;

    my $key_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $key_p ) {
        return;
    }
    my @dnskeys = $key_p->get_records( 'DNSKEY', 'answer' );
    my @sigs    = $key_p->get_records( 'RRSIG',  'answer' );

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
        my $time = $key_p->timestamp;
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
            if ($sig->algorithm == 12 and $msg =~ /Unknown cryptographic algorithm/) {
                $msg = 'no GOST support';
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

    my $key_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $key_p ) {
        return;
    }
    my @dnskeys = $key_p->get_records( 'DNSKEY', 'answer' );

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
            if ($sig->algorithm == 12 and $msg =~ /Unknown cryptographic algorithm/) {
                $msg = 'no GOST support';
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
    my @results;

    my $key_p = $zone->query_one( $zone->name, 'DNSKEY', { dnssec => 1 } );
    if ( not $key_p ) {
        return;
    }
    my @dnskeys = $key_p->get_records( 'DNSKEY', 'answer' );

    my $name = $zone->name->prepend( 'xx--example' );
    my $test_p = $zone->query_one( $name, 'A', { dnssec => 1 } );
    if ( not $test_p ) {
        return;
    }

    if ( $test_p->rcode ne 'NXDOMAIN' and $test_p->rcode ne 'NOERROR' ) {
        push @results,
          info(
            INVALID_NAME_RCODE => {
                name  => $name,
                rcode => $test_p->rcode,
            }
          );
        return @results;
    }

    my @nsec = $test_p->get_records( 'NSEC', 'authority' );
    if ( @nsec ) {
        push @results, info( HAS_NSEC => {} );
        my $covered = 0;
        foreach my $nsec ( @nsec ) {

            if ( $nsec->covers( $name ) ) {
                $covered = 1;

                my @sigs = grep { $_->typecovered eq 'NSEC' } $test_p->get_records_for_name( 'RRSIG', $nsec->name );
                my $ok = 0;
                foreach my $sig ( @sigs ) {
                    my $msg = q{};
                    if (@dnskeys == 0) {
                        push @results, info( NSEC_SIG_VERIFY_ERROR => { error => 'DNSKEY missing', sig => $sig->keytag } );
                    }
                    elsif (
                        $sig->verify_time(
                            [ grep { name( $_->name ) eq name( $sig->name ) } @nsec ],
                            \@dnskeys, $test_p->timestamp, $msg
                        )
                      )
                    {
                        $ok = 1;
                    }
                    else {
                        if ($sig->algorithm == 12 and $msg =~ /Unknown cryptographic algorithm/) {
                            $msg = 'no GOST support';
                        }
                        push @results,
                          info(
                            NSEC_SIG_VERIFY_ERROR => {
                                error => $msg,
                                sig   => $sig->keytag,
                            }
                          );
                    }

                    if ( $ok ) {
                        push @results,
                          info( NSEC_SIGNED => {} );
                    }
                    else {
                        push @results,
                          info( NSEC_NOT_SIGNED => {} );
                    }
                } ## end foreach my $sig ( @sigs )
            } ## end if ( $nsec->covers( $name...))
        } ## end foreach my $nsec ( @nsec )
        if ( $covered ) {
            push @results,
              info(
                NSEC_COVERS => {
                    name => $name,
                }
              );
        }
        else {
            push @results,
              info(
                NSEC_COVERS_NOT => {
                    name => $name,
                }
              );
        }
    } ## end if ( @nsec )

    my @nsec3 = $test_p->get_records( 'NSEC3', 'authority' );
    if ( @nsec3 ) {
        my $covered = 0;
        my $opt_out = 0;
        push @results, info( HAS_NSEC3 => {} );
        foreach my $nsec3 ( @nsec3 ) {
            if ( $nsec3->optout ) {
                $opt_out = 1;
            }
            if ( $nsec3->covers( $name ) ) {
                $covered = 1;

                my @sigs = grep { $_->typecovered eq 'NSEC3' } $test_p->get_records_for_name( 'RRSIG', $nsec3->name );
                my $ok = 0;
                foreach my $sig ( @sigs ) {
                    my $msg = q{};
                    if (
                        $sig->verify_time(
                            [ grep { name( $_->name ) eq name( $sig->name ) } @nsec3 ],
                            \@dnskeys, $test_p->timestamp, $msg
                        )
                      )
                    {
                        $ok = 1;
                    }
                    else {
                        if ($sig->algorithm == 12 and $msg =~ /Unknown cryptographic algorithm/) {
                            $msg = 'no GOST support';
                        }
                        push @results,
                          info(
                            NSEC3_SIG_VERIFY_ERROR => {
                                sig   => $sig->keytag,
                                error => $msg,
                            }
                          );
                    }
                    if ( $ok ) {
                        push @results,
                          info( NSEC3_SIGNED => {} );
                    }
                    else {
                        push @results,
                          info( NSE3C_NOT_SIGNED => {} );
                    }
                } ## end foreach my $sig ( @sigs )
            } ## end if ( $nsec3->covers( $name...))
        } ## end foreach my $nsec3 ( @nsec3 )
        if ( $covered ) {
            push @results,
              info(
                NSEC3_COVERS => {
                    name => $name,
                }
              );
        }
        else {
            push @results,
              info(
                NSEC3_COVERS_NOT => {
                    name => $name,
                }
              );
        }
        if ( $opt_out ) {
            push @results, info( HAS_NSEC3_OPTOUT => {} );
        }
    } ## end if ( @nsec3 )

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
                            if ($sig->algorithm == 12 and $msg =~ /Unknown cryptographic algorithm/) {
                                $msg = 'no GOST support';
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

=item translation()

Returns a reference to a nested hash, where the outermost keys are language
codes, the keys below that are message tags and their values are translation
strings.

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

=back

=cut
