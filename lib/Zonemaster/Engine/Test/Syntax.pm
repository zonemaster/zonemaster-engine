package Zonemaster::Engine::Test::Syntax;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare( "v1.0.10" );

use Zonemaster::Engine;

use Carp;
use Email::Valid;
use List::MoreUtils qw[uniq none any];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;
use Time::Local;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Constants qw[:name :ip];
use Zonemaster::Engine::DNSName;
use Zonemaster::Engine::Packet;
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Util;
use Zonemaster::LDNS;

###
### Entry points
###

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    push @results, $class->syntax01( $zone->name ) if Zonemaster::Engine::Util::should_run_test( q{syntax01} );
    push @results, $class->syntax02( $zone->name ) if Zonemaster::Engine::Util::should_run_test( q{syntax02} );
    push @results, $class->syntax03( $zone->name ) if Zonemaster::Engine::Util::should_run_test( q{syntax03} );

    if ( any { $_->tag eq q{ONLY_ALLOWED_CHARS} } @results ) {

        foreach my $local_nsname ( uniq map { $_->string } @{ Zonemaster::Engine::TestMethods->method2( $zone ) },
            @{ Zonemaster::Engine::TestMethods->method3( $zone ) } )
        {
            push @results, $class->syntax04( $local_nsname )
              if Zonemaster::Engine::Util::should_run_test( q{syntax04} );
        }

        push @results, $class->syntax05( $zone ) if Zonemaster::Engine::Util::should_run_test( q{syntax05} );

        if ( none { $_->tag eq q{NO_RESPONSE_SOA_QUERY} } @results ) {
            push @results, $class->syntax06( $zone ) if Zonemaster::Engine::Util::should_run_test( q{syntax06} );
            push @results, $class->syntax07( $zone ) if Zonemaster::Engine::Util::should_run_test( q{syntax07} );
        }

        push @results, $class->syntax08( $zone ) if Zonemaster::Engine::Util::should_run_test( q{syntax08} );

    }

    return @results;
} ## end sub all

###
### Metadata Exposure
###

sub metadata {
    my ( $class ) = @_;

    return {
        syntax01 => [
            qw(
              ONLY_ALLOWED_CHARS
              NON_ALLOWED_CHARS
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        syntax02 => [
            qw(
              INITIAL_HYPHEN
              TERMINAL_HYPHEN
              NO_ENDING_HYPHENS
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        syntax03 => [
            qw(
              DISCOURAGED_DOUBLE_DASH
              NO_DOUBLE_DASH
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        syntax04 => [
            qw(
              NAMESERVER_DISCOURAGED_DOUBLE_DASH
              NAMESERVER_NON_ALLOWED_CHARS
              NAMESERVER_NUMERIC_TLD
              NAMESERVER_SYNTAX_OK
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        syntax05 => [
            qw(
              RNAME_MISUSED_AT_SIGN
              RNAME_NO_AT_SIGN
              NO_RESPONSE_SOA_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        syntax06 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_SOA_QUERY
              RNAME_MAIL_DOMAIN_INVALID
              RNAME_MAIL_DOMAIN_LOCALHOST
              RNAME_MAIL_ILLEGAL_CNAME
              RNAME_RFC822_INVALID
              RNAME_RFC822_VALID
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        syntax07 => [
            qw(
              MNAME_DISCOURAGED_DOUBLE_DASH
              MNAME_NON_ALLOWED_CHARS
              MNAME_NUMERIC_TLD
              MNAME_SYNTAX_OK
              NO_RESPONSE_SOA_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        syntax08 => [
            qw(
              MX_DISCOURAGED_DOUBLE_DASH
              MX_NON_ALLOWED_CHARS
              MX_NUMERIC_TLD
              MX_SYNTAX_OK
              NO_RESPONSE_MX_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    SYNTAX01 => sub {
        __x    # SYNTAX:SYNTAX01
          'No illegal characters in the domain name', @_;
    },
    SYNTAX02 => sub {
        __x    # SYNTAX:SYNTAX02
          'No hyphen (\'-\') at the start or end of the domain name', @_;
    },
    SYNTAX03 => sub {
        __x    # SYNTAX:SYNTAX03
          'There must be no double hyphen (\'--\') in position 3 and 4 of the domain name', @_;
    },
    SYNTAX04 => sub {
        __x    # SYNTAX:SYNTAX04
          'The NS name must have a valid domain/hostname', @_;
    },
    SYNTAX05 => sub {
        __x    # SYNTAX:SYNTAX05
          'Misuse of \'@\' character in the SOA RNAME field', @_;
    },
    SYNTAX06 => sub {
        __x    # SYNTAX:SYNTAX06
          'No illegal characters in the SOA RNAME field', @_;
    },
    SYNTAX07 => sub {
        __x    # SYNTAX:SYNTAX07
          'No illegal characters in the SOA MNAME field', @_;
    },
    SYNTAX08 => sub {
        __x    # SYNTAX:SYNTAX08
          'MX name must have a valid hostname', @_;
    },
    DISCOURAGED_DOUBLE_DASH => sub {
        __x    # SYNTAX:DISCOURAGED_DOUBLE_DASH
          'Domain name ({domain}) has a label ({label}) with a double hyphen (\'--\') '
          . 'in position 3 and 4 (with a prefix which is not \'xn--\').',
          @_;
    },
    INITIAL_HYPHEN => sub {
        __x    # SYNTAX:INITIAL_HYPHEN
          'Domain name ({domain}) has a label ({label}) starting with an hyphen (\'-\').', @_;
    },
    IPV4_DISABLED => sub {
        __x    # SYNTAX:IPV4_DISABLED
          'IPv4 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    IPV6_DISABLED => sub {
        __x    # SYNTAX:IPV6_DISABLED
          'IPv6 is disabled, not sending "{rrtype}" query to {ns}.', @_;
    },
    MNAME_DISCOURAGED_DOUBLE_DASH => sub {
        __x    # SYNTAX:MNAME_DISCOURAGED_DOUBLE_DASH
          'SOA MNAME ({domain}) has a label ({label}) with a double hyphen (\'--\') '
          . 'in position 3 and 4 (with a prefix which is not \'xn--\').',
          @_;
    },
    MNAME_NON_ALLOWED_CHARS => sub {
        __x    # SYNTAX:MNAME_NON_ALLOWED_CHARS
          'Found illegal characters in SOA MNAME ({domain}).', @_;
    },
    MNAME_NUMERIC_TLD => sub {
        __x    # SYNTAX:MNAME_NUMERIC_TLD
          'SOA MNAME ({domain}) within a \'numeric only\' TLD ({tld}).', @_;
    },
    MNAME_SYNTAX_OK => sub {
        __x    # SYNTAX:MNAME_SYNTAX_OK
          'SOA MNAME ({domain}) syntax is valid.', @_;
    },
    MX_DISCOURAGED_DOUBLE_DASH => sub {
        __x    # SYNTAX:MX_DISCOURAGED_DOUBLE_DASH
          'Domain name MX ({domain}) has a label ({label}) with a double hyphen (\'--\') '
          . 'in position 3 and 4 (with a prefix which is not \'xn--\').',
          @_;
    },
    MX_NON_ALLOWED_CHARS => sub {
        __x    # SYNTAX:MX_NON_ALLOWED_CHARS
          'Found illegal characters in MX ({domain}).', @_;
    },
    MX_NUMERIC_TLD => sub {
        __x    # SYNTAX:MX_NUMERIC_TLD
          'Domain name MX ({domain}) within a \'numeric only\' TLD ({tld}).', @_;
    },
    MX_SYNTAX_OK => sub {
        __x    # SYNTAX:MX_SYNTAX_OK
          'Domain name MX ({domain}) syntax is valid.', @_;
    },
    NAMESERVER_DISCOURAGED_DOUBLE_DASH => sub {
        __x    # SYNTAX:NAMESERVER_DISCOURAGED_DOUBLE_DASH
          'Nameserver ({domain}) has a label ({label}) with a double hyphen (\'--\') '
          . 'in position 3 and 4 (with a prefix which is not \'xn--\').',
          @_;
    },
    NAMESERVER_NON_ALLOWED_CHARS => sub {
        __x    # SYNTAX:NAMESERVER_NON_ALLOWED_CHARS
          'Found illegal characters in the nameserver ({domain}).', @_;
    },
    NAMESERVER_NUMERIC_TLD => sub {
        __x    # SYNTAX:NAMESERVER_NUMERIC_TLD
          'Nameserver ({domain}) within a \'numeric only\' TLD ({tld}).', @_;
    },
    NAMESERVER_SYNTAX_OK => sub {
        __x    # SYNTAX:NAMESERVER_SYNTAX_OK
          'Nameserver ({domain}) syntax is valid.', @_;
    },
    NON_ALLOWED_CHARS => sub {
        __x    # SYNTAX:NON_ALLOWED_CHARS
          'Found illegal characters in the domain name ({domain}).', @_;
    },
    NO_DOUBLE_DASH => sub {
        __x    # SYNTAX:NO_DOUBLE_DASH
          'Domain name ({domain}) has no label with a double hyphen (\'--\') '
          . 'in position 3 and 4 (with a prefix which is not \'xn--\').',
          @_;
    },
    NO_ENDING_HYPHENS => sub {
        __x    # SYNTAX:NO_ENDING_HYPHENS
          "Neither end of any label in the domain name ({domain}) has a hyphen.", @_;
    },
    NO_RESPONSE => sub {
        __x    # SYNTAX:NO_RESPONSE
          'No response from {ns} asking for {domain}.', @_;
    },
    NO_RESPONSE_MX_QUERY => sub {
        __x    # SYNTAX:NO_RESPONSE_MX_QUERY
          'No response from nameserver(s) on MX queries.', @_;
    },
    NO_RESPONSE_SOA_QUERY => sub {
        __x    # SYNTAX:NO_RESPONSE_SOA_QUERY
          'No response from nameserver(s) on SOA queries.', @_;
    },
    ONLY_ALLOWED_CHARS => sub {
        __x    # SYNTAX:ONLY_ALLOWED_CHARS
          'No illegal characters in the domain name ({domain}).', @_;
    },
    RNAME_MAIL_DOMAIN_INVALID => sub {
        __x    # SYNTAX:RNAME_MAIL_DOMAIN_INVALID
          'The SOA RNAME mail domain ({domain}) cannot be resolved to a mail server with an IP address.', @_;
    },
    RNAME_MAIL_DOMAIN_LOCALHOST => sub {
        __x    # SYNTAX:RNAME_MAIL_DOMAIN_LOCALHOST
          'The SOA RNAME mail domain ({domain}) resolved to a mail server with localhost ({localhost}) IP address.', @_;
    },
    RNAME_MAIL_ILLEGAL_CNAME => sub {
        __x    # SYNTAX:RNAME_MAIL_ILLEGAL_CNAME
          'The SOA RNAME mail domain ({domain}) refers to an address which is an alias (CNAME).', @_;
    },
    RNAME_MISUSED_AT_SIGN => sub {
        __x    # SYNTAX:RNAME_MISUSED_AT_SIGN
          "Misused '\@' character found in SOA RNAME field ({rname}).", @_;
    },
    RNAME_NO_AT_SIGN => sub {
        __x    # SYNTAX:RNAME_NO_AT_SIGN
          'There is no misused \'@\' character in the SOA RNAME field ({rname}).', @_;
    },
    RNAME_RFC822_INVALID => sub {
        __x    # SYNTAX:RNAME_RFC822_INVALID
           "Illegal character(s) found in SOA RNAME field ({rname}).", @_;
    },
    RNAME_RFC822_VALID => sub {
        __x    # SYNTAX:RNAME_RFC822_VALID
          'The SOA RNAME field ({rname}) is compliant with RFC2822.', @_;
    },
    TERMINAL_HYPHEN => sub {
        __x    # SYNTAX:TERMINAL_HYPHEN
          "Domain name ({domain}) has a label ({label}) ending with a hyphen ('-').", @_;
    },
    TEST_CASE_END => sub {
        __x    # SYNTAX:TEST_CASE_END
          'TEST_CASE_END {testcase}.', @_;
    },
    TEST_CASE_START => sub {
        __x    # SYNTAX:TEST_CASE_START
          'TEST_CASE_START {testcase}.', @_;
    },
);

sub tag_descriptions {
    return \%TAG_DESCRIPTIONS;
}

sub version {
    return "$Zonemaster::Engine::Test::Syntax::VERSION";
}

sub _ip_disabled_message {
    my ( $results_array, $ns, @rrtypes ) = @_;

    if ( not Zonemaster::Engine::Profile->effective->get(q{net.ipv6}) and $ns->address->version == $IP_VERSION_6 ) {
        push @$results_array, map {
          info(
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
          info(
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

###
### Tests
###

sub syntax01 {
    my ( $class, $item ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my $name = get_name( $item );

    if ( _name_has_only_legal_characters( $name ) ) {
        push @results,
          info(
            ONLY_ALLOWED_CHARS => {
                domain => $name,
            }
          );
    }
    else {
        push @results,
          info(
            NON_ALLOWED_CHARS => {
                domain => $name,
            }
          );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub syntax01

sub syntax02 {
    my ( $class, $item ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my $name = get_name( $item );

    foreach my $local_label ( @{ $name->labels } ) {
        if ( _label_starts_with_hyphen( $local_label ) ) {
            push @results,
              info(
                INITIAL_HYPHEN => {
                    label  => $local_label,
                    domain => $name,
                }
              );
        }
        if ( _label_ends_with_hyphen( $local_label ) ) {
            push @results,
              info(
                TERMINAL_HYPHEN => {
                    label  => $local_label,
                    domain => $name,
                }
              );
        }
    } ## end foreach my $local_label ( @...)

    if ( scalar @{ $name->labels } and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results,
          info(
            NO_ENDING_HYPHENS => {
                domain => $name,
            }
          );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub syntax02

sub syntax03 {
    my ( $class, $item ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my $name = get_name( $item );

    foreach my $local_label ( @{ $name->labels } ) {
        if ( _label_not_ace_has_double_hyphen_in_position_3_and_4( $local_label ) ) {
            push @results,
              info(
                DISCOURAGED_DOUBLE_DASH => {
                    label  => $local_label,
                    domain => $name,
                }
              );
        }
    }

    if ( scalar @{ $name->labels } and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results,
          info(
            NO_DOUBLE_DASH => {
                domain => $name,
            }
          );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub syntax03

sub syntax04 {
    my ( $class, $item ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my $name = get_name( $item );

    push @results, check_name_syntax( q{NAMESERVER}, $name );

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
}

sub syntax05 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my $p = $zone->query_one( $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $rname = $soa->rname;
        $rname =~ s/\\./\./smgx;
        if ( index( $rname, q{@} ) != -1 ) {
            push @results,
              info(
                RNAME_MISUSED_AT_SIGN => {
                    rname => $soa->rname,
                }
              );
        }
        else {
            push @results,
              info(
                RNAME_NO_AT_SIGN => {
                    rname => $soa->rname,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, info( NO_RESPONSE_SOA_QUERY => {} );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub syntax05

sub syntax06 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my @nss;
    {
        my %nss = map { $_->string => $_ }
          @{ Zonemaster::Engine::TestMethods->method4( $zone ) },
          @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
        @nss = sort values %nss;
    }

    my %seen_rnames;
    for my $ns ( @nss ) {

        if ( _ip_disabled_message( \@results, $ns, q{SOA} ) ) {
            next;
        }

        my $p = $ns->query( $zone->name, q{SOA}, { recurse => 0, usevc => 0 } );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns     => $ns->string,
                    domain => $zone->name,
                }
              );
            next;
        }

        my ( $soa ) = $p->get_records( q{SOA}, q{answer} );

        if ( not $soa ) {
            push @results, info( NO_RESPONSE_SOA_QUERY => {} );
            next;
        }

        my $rname = $soa->rname;
        $rname =~ s/([^\\])[.]/$1@/smx;    # Replace first non-escaped dot with an at-sign
        $rname =~ s/[\\][.]/./smgx;        # Un-escape dots
        $rname =~ s/[.]\z//smgx;           # Validator does not like final dots
        if ( not Email::Valid->address( $rname ) ) {
            push @results,
              info(
                RNAME_RFC822_INVALID => {
                    rname => $rname,
                }
              );
            next;
        }

        my $domain = ( $rname =~ s/.*@//r );
        my $p_mx = Zonemaster::Engine::Recursor->recurse( $domain, q{MX} );
        if ( not $p_mx or $p_mx->rcode ne 'NOERROR' ) {
            push @results, info( RNAME_MAIL_DOMAIN_INVALID => { domain => $domain } );
            next;
        }

        # Follow CNAMEs in the MX response
        my %cnames =
          map { $_->owner => $_->cname } $p_mx->get_records( q{CNAME}, q{answer} );
        $domain .= q{.};    # Add back final dot
        $domain = $cnames{$domain} while $cnames{$domain};

        # Determine mail domain(s)
        my @mail_domains;
        if ( my @mxs = $p_mx->get_records_for_name( q{MX}, $domain ) ) {
            @mail_domains = map { $_->exchange } @mxs;
        }
        else {
            @mail_domains = ( $domain );
        }

        for my $mail_domain ( @mail_domains ) {

            # Assume mail domain is invalid until we see an actual IP address
            my $exchange_valid = 0;

            # Lookup IPv4 address for mail server
            my $p_a = Zonemaster::Engine::Recursor->recurse( $mail_domain, q{A} );
            if ( $p_a ) {
                if ( $p_a->get_records( q{CNAME}, q{answer} ) ) {
                    push @results, info( RNAME_MAIL_ILLEGAL_CNAME => { domain => $mail_domain } );
                }
                else {
                    my @rrs_a = grep { $_->owner eq $mail_domain } $p_a->get_records( q{A}, q{answer} );

                    if ( grep { $_->address eq q{127.0.0.1} } @rrs_a ) {
                        push @results, info( RNAME_MAIL_DOMAIN_LOCALHOST => { domain => $mail_domain, localhost => q{127.0.0.1} } );
                    }
                    elsif ( @rrs_a ) {
                        $exchange_valid = 1;
                    }
                }
            }

            # Lookup IPv6 address for mail domain
            my $p_aaaa = Zonemaster::Engine::Recursor->recurse( $mail_domain, q{AAAA} );
            if ( $p_aaaa ) {
                if ( $p_aaaa->get_records( q{CNAME}, q{answer} ) ) {
                    push @results, info( RNAME_MAIL_ILLEGAL_CNAME => { domain => $mail_domain } );
                }
                else {
                    my @rrs_aaaa = grep { $_->owner eq $mail_domain } $p_aaaa->get_records( q{AAAA}, q{answer} );

                    if ( grep { $_->address eq q{::1} } @rrs_aaaa) {
                        push @results, info( RNAME_MAIL_DOMAIN_LOCALHOST => { domain => $mail_domain, localhost => q{::1} } );
                    }
                    elsif ( @rrs_aaaa ) {
                        $exchange_valid = 1;
                    }
                }
            }

            # Emit verdict for mail domain
            if ( $exchange_valid ) {
                if ( !exists $seen_rnames{$rname} ) {
                    $seen_rnames{$rname} = 1;
                    push @results,
                      info(
                        RNAME_RFC822_VALID => {
                            rname => $rname,
                        }
                      );
                }
            }
            else {
                push @results, info( RNAME_MAIL_DOMAIN_INVALID => { domain => $mail_domain } );
            }
        } ## end for my $mail_domain ( @mail_domains)

    } ## end for my $ns ( @nss )

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub syntax06

sub syntax07 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my $p = $zone->query_one( $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $mname = $soa->mname;

        push @results, check_name_syntax( q{MNAME}, $mname );
    }
    else {
        push @results, info( NO_RESPONSE_SOA_QUERY => {} );
    }

    return ( @results, info( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
}

sub syntax08 {
    my ( $class, $zone ) = @_;
    push my @results, info( TEST_CASE_START => { testcase => (split /::/, (caller(0))[3])[-1] } );

    my $p = $zone->query_one( $zone->name, q{MX} );

    if ( $p ) {
        my %mx = map { $_->exchange => 1 } $p->get_records( q{MX}, q{answer} );
        foreach my $mx ( sort keys %mx ) {
            push @results, check_name_syntax( q{MX}, $mx );
        }
    }
    else {
        push @results, info( NO_RESPONSE_MX_QUERY => {} );
    }

    return @results;
}

###
### Internal Tests with Boolean (0|1) return value.
###

sub _name_has_only_legal_characters {
    my ( $name ) = @_;

    if ( List::MoreUtils::all { m/\A[-A-Za-z0-9]+\z/smx } @{ $name->labels } ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _label_starts_with_hyphen {
    my ( $label ) = @_;

    return 0 if not $label;

    if ( $label =~ /\A-/smgx ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _label_ends_with_hyphen {
    my ( $label ) = @_;

    return 0 if not $label;

    if ( $label =~ /-\z/smgx ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _label_not_ace_has_double_hyphen_in_position_3_and_4 {
    my ( $label ) = @_;

    return 0 if not $label;

    if ( $label =~ /\A..--/smx and $label !~ /\Axn/ismx ) {
        return 1;
    }
    else {
        return 0;
    }
}

###
### Common part for syntax04, syntax07 and syntax08
###

sub get_name {
    my ( $item ) = @_;
    my $name;

    if ( not ref $item ) {
        $name = name( $item );
    }
    elsif ( ref( $item ) eq q{Zonemaster::Engine::Zone} ) {
        $name = $item->name;
    }
    elsif ( ref( $item ) eq q{Zonemaster::Engine::DNSName} ) {
        $name = $item;
    }

    return $name;
}

sub check_name_syntax {
    my ( $info_label_prefix, $name ) = @_;
    my @results;

    $name = get_name( $name );

    if ( not _name_has_only_legal_characters( $name ) ) {
        push @results,
          info(
            $info_label_prefix
              . q{_NON_ALLOWED_CHARS} => {
                domain => $name,
              }
          );
    }

    if ( $name ne q{.} ) {

        foreach my $local_label ( @{ $name->labels } ) {
            if ( _label_not_ace_has_double_hyphen_in_position_3_and_4( $local_label ) ) {
                push @results,
                  info(
                    $info_label_prefix
                      . q{_DISCOURAGED_DOUBLE_DASH} => {
                        label  => $local_label,
                        domain => "$name",
                      }
                  );
            }
        }

        my $tld = @{ $name->labels }[-1];
        if ( $tld =~ /\A\d+\z/smgx ) {
            push @results,
              info(
                $info_label_prefix
                  . q{_NUMERIC_TLD} => {
                    domain => "$name",
                    tld    => $tld,
                  }
              );
        }

    } ## end if ( $name ne q{.} )

    if ( not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results,
          info(
            $info_label_prefix
              . q{_SYNTAX_OK} => {
                domain => "$name",
              }
          );
    }

    return @results;
} ## end sub check_name_syntax

1;

=head1 NAME

Zonemaster::Engine::Test::Syntax - test validating the syntax of host names and other data

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Syntax->all($zone);

=head1 METHODS

=over

=item all($zone)

Runs the default set of tests and returns a list of log entries made by the tests.

=item tag_descriptions()

Returns a refernce to a hash with translation functions. Used by the builtin translation system.

=item metadata()

Returns a reference to a hash, the keys of which are the names of all test methods in the module, and the corresponding values are references to
lists with all the tags that the method can use in log entries.

=item version()

Returns a version string for the module.

=back

=head1 TESTS

=over

=item syntax01($name)

Verifies that the name (Zonemaster::Engine::DNSName) given contains only allowed characters.

=item syntax02($name)

Verifies that the name (Zonemaster::Engine::DNSName) given does not start or end with a hyphen ('-').

=item syntax03($name)

Verifies that the name (Zonemaster::Engine::DNSName) given does not contain a hyphen in 3rd and 4th position (in the exception of 'xn--').

=item syntax04($name)

Verify that a nameserver (Zonemaster::Engine::DNSName) given is conform to previous syntax rules. It also verify name total length as well as labels.

=item syntax05($zone)

Verify that a SOA rname (Zonemaster::Engine::DNSName) given has a conform usage of at sign (@).

=item syntax06($zone)

Verify that a SOA rname (Zonemaster::Engine::DNSName) given is RFC822 compliant.

=item syntax07($zone)

Verify that SOA mname of zone given is conform to previous syntax rules (syntax01, syntax02, syntax03). It also verify name total length as well as labels.

=item syntax08(@mx_names)

Verify that MX name (Zonemaster::Engine::DNSName) given is conform to previous syntax rules (syntax01, syntax02, syntax03). It also verify name total length as well as labels.

=back

=head1 INTERNAL METHODS

=over

=item get_name($item)

Converts argument to a L<Zonemaster::Engine::DNSName> object.

=item check_name_syntax

Implementation of some tests that are used on several kinds of input.

=back

=cut
