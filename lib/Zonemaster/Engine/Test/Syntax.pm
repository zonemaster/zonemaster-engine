package Zonemaster::Engine::Test::Syntax;

use version; our $VERSION = version->declare("v1.0.4");

use strict;
use warnings;

use 5.014002;

use Zonemaster::Engine;
use Zonemaster::Engine::Util;
use Zonemaster::Engine::Recursor;
use Zonemaster::Engine::DNSName;
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Constants qw[:name];
use Zonemaster::LDNS;
use Zonemaster::Engine::Packet;

use Carp;

use List::MoreUtils qw[uniq none any];
use Mail::RFC822::Address qw[valid];
use Time::Local;

###
### Entry points
###

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    push @results, $class->syntax01( $zone->name ) if Zonemaster::Engine->profile->should_run( 'syntax01' );
    push @results, $class->syntax02( $zone->name ) if Zonemaster::Engine->profile->should_run( 'syntax02' );
    push @results, $class->syntax03( $zone->name ) if Zonemaster::Engine->profile->should_run( 'syntax03' );

    if ( any { $_->tag eq q{ONLY_ALLOWED_CHARS} } @results ) {

        foreach my $local_nsname ( uniq map { $_->string } @{ Zonemaster::Engine::TestMethods->method2( $zone ) },
            @{ Zonemaster::Engine::TestMethods->method3( $zone ) } )
        {
            push @results, $class->syntax04( $local_nsname ) if Zonemaster::Engine->profile->should_run( 'syntax04' );
        }

        push @results, $class->syntax05( $zone ) if Zonemaster::Engine->profile->should_run( 'syntax05' );

        if ( none { $_->tag eq q{NO_RESPONSE_SOA_QUERY} } @results ) {
            push @results, $class->syntax06( $zone ) if Zonemaster::Engine->profile->should_run( 'syntax06' );
            push @results, $class->syntax07( $zone ) if Zonemaster::Engine->profile->should_run( 'syntax07' );
        }

        push @results, $class->syntax08( $zone ) if Zonemaster::Engine->profile->should_run( 'syntax08' );

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
              )
        ],
        syntax02 => [
            qw(
              INITIAL_HYPHEN
              TERMINAL_HYPHEN
              NO_ENDING_HYPHENS
              )
        ],
        syntax03 => [
            qw(
              DISCOURAGED_DOUBLE_DASH
              NO_DOUBLE_DASH
              )
        ],
        syntax04 => [
            qw(
              NAMESERVER_DISCOURAGED_DOUBLE_DASH
              NAMESERVER_NON_ALLOWED_CHARS
              NAMESERVER_NUMERIC_TLD
              NAMESERVER_SYNTAX_OK
              )
        ],
        syntax05 => [
            qw(
              RNAME_MISUSED_AT_SIGN
              RNAME_NO_AT_SIGN
              NO_RESPONSE_SOA_QUERY
              )
        ],
        syntax06 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_SOA_QUERY
              RNAME_MAIL_DOMAIN_INVALID
              RNAME_RFC822_INVALID
              RNAME_RFC822_VALID
              )
        ],
        syntax07 => [
            qw(
              MNAME_DISCOURAGED_DOUBLE_DASH
              MNAME_NON_ALLOWED_CHARS
              MNAME_NUMERIC_TLD
              MNAME_SYNTAX_OK
              NO_RESPONSE_SOA_QUERY
              )
        ],
        syntax08 => [
            qw(
              MX_DISCOURAGED_DOUBLE_DASH
              MX_NON_ALLOWED_CHARS
              MX_NUMERIC_TLD
              MX_SYNTAX_OK
              NO_RESPONSE_MX_QUERY
              )
        ],
    };
} ## end sub metadata

sub translation {
    return {
        DISCOURAGED_DOUBLE_DASH => 'Domain name ({name}) has a label ({label}) with a double hyphen (\'--\') '
          . 'in position 3 and 4 (with a prefix which is not \'xn--\').',
        INITIAL_HYPHEN                => 'Domain name ({name}) has a label ({label}) starting with an hyphen (\'-\').',
        MNAME_DISCOURAGED_DOUBLE_DASH => 'SOA MNAME ({name}) has a label ({label}) with a double hyphen (\'--\') '
          . 'in position 3 and 4 (with a prefix which is not \'xn--\').',
        MNAME_NON_ALLOWED_CHARS    => 'Found illegal characters in SOA MNAME ({name}).',
        MNAME_NUMERIC_TLD          => 'SOA MNAME ({name}) within a \'numeric only\' TLD ({tld}).',
        MNAME_SYNTAX_OK            => 'SOA MNAME ({name}) syntax is valid.',
        MX_DISCOURAGED_DOUBLE_DASH => 'Domain name MX ({name}) has a label ({label}) with a double hyphen (\'--\') '
          . 'in position 3 and 4 (with a prefix which is not \'xn--\').',
        MX_NON_ALLOWED_CHARS               => 'Found illegal characters in MX ({name}).',
        MX_NUMERIC_TLD                     => 'Domain name MX ({name}) within a \'numeric only\' TLD ({tld}).',
        MX_SYNTAX_OK                       => 'Domain name MX ({name}) syntax is valid.',
        NAMESERVER_DISCOURAGED_DOUBLE_DASH => 'Nameserver ({name}) has a label ({label}) '
          . 'with a double hyphen (\'--\') in position 3 and 4 (with a prefix which is not \'xn--\').',
        NAMESERVER_NON_ALLOWED_CHARS => 'Found illegal characters in the nameserver ({name}).',
        NAMESERVER_NUMERIC_TLD       => 'Nameserver ({name}) within a \'numeric only\' TLD ({tld}).',
        NAMESERVER_SYNTAX_OK         => 'Nameserver ({name}) syntax is valid.',
        NON_ALLOWED_CHARS            => 'Found illegal characters in the domain name ({name}).',
        NO_DOUBLE_DASH               => 'Domain name ({name}) has no label with a double hyphen (\'--\') '
          . 'in position 3 and 4 (with a prefix which is not \'xn--\').',
        NO_ENDING_HYPHENS         => 'Both ends of all labels of the domain name ({name}) have no hyphens.',
        NO_RESPONSE               => 'No response from {ns}/{address} asking for {dname}.',
        NO_RESPONSE_MX_QUERY      => 'No response from nameserver(s) on MX queries.',
        NO_RESPONSE_SOA_QUERY     => 'No response from nameserver(s) on SOA queries.',
        ONLY_ALLOWED_CHARS        => 'No illegal characters in the domain name ({name}).',
        RNAME_MAIL_DOMAIN_INVALID => 'The SOA RNAME mail domain ({domain}) cannot be resolved to a mail server '
          . 'with an IP address.',
        RNAME_MISUSED_AT_SIGN => 'There must be no misused \'@\' character in the SOA RNAME field ({rname}).',
        RNAME_NO_AT_SIGN      => 'There is no misused \'@\' character in the SOA RNAME field ({rname}).',
        RNAME_RFC822_INVALID  => 'There must be no illegal characters in the SOA RNAME field ({rname}).',
        RNAME_RFC822_VALID    => 'The SOA RNAME field ({rname}) is compliant with RFC2822.',
        TERMINAL_HYPHEN       => 'Domain name ({name}) has a label ({label}) ending with an hyphen (\'-\').',
    };
} ## end sub translation

sub version {
    return "$Zonemaster::Engine::Test::Syntax::VERSION";
}

###
### Tests
###

sub syntax01 {
    my ( $class, $item ) = @_;
    my @results;

    my $name = get_name( $item );

    if ( _name_has_only_legal_characters( $name ) ) {
        push @results,
          info(
            ONLY_ALLOWED_CHARS => {
                name => $name,
            }
          );
    }
    else {
        push @results,
          info(
            NON_ALLOWED_CHARS => {
                name => $name,
            }
          );
    }

    return @results;
} ## end sub syntax01

sub syntax02 {
    my ( $class, $item ) = @_;
    my @results;

    my $name = get_name( $item );

    foreach my $local_label ( @{ $name->labels } ) {
        if ( _label_starts_with_hyphen( $local_label ) ) {
            push @results,
              info(
                INITIAL_HYPHEN => {
                    label => $local_label,
                    name  => $name,
                }
              );
        }
        if ( _label_ends_with_hyphen( $local_label ) ) {
            push @results,
              info(
                TERMINAL_HYPHEN => {
                    label => $local_label,
                    name  => $name,
                }
              );
        }
    } ## end foreach my $local_label ( @...)

    if ( scalar @{ $name->labels } and not scalar @results ) {
        push @results,
          info(
            NO_ENDING_HYPHENS => {
                name => $name,
            }
          );
    }

    return @results;
} ## end sub syntax02

sub syntax03 {
    my ( $class, $item ) = @_;
    my @results;

    my $name = get_name( $item );

    foreach my $local_label ( @{ $name->labels } ) {
        if ( _label_not_ace_has_double_hyphen_in_position_3_and_4( $local_label ) ) {
            push @results,
              info(
                DISCOURAGED_DOUBLE_DASH => {
                    label => $local_label,
                    name  => $name,
                }
              );
        }
    }

    if ( scalar @{ $name->labels } and not scalar @results ) {
        push @results,
          info(
            NO_DOUBLE_DASH => {
                name => $name,
            }
          );
    }

    return @results;
} ## end sub syntax03

sub syntax04 {
    my ( $class, $item ) = @_;
    my @results;

    my $name = get_name( $item );

    push @results, check_name_syntax( q{NAMESERVER}, $name );

    return @results;
}

sub syntax05 {
    my ( $class, $zone ) = @_;
    my @results;

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

    return @results;
} ## end sub syntax05

sub syntax06 {
    my ( $class, $zone ) = @_;
    my @results;

    my @nss;
    {
        my %nss = map { $_->string => $_ }
          @{ Zonemaster::Engine::TestMethods->method4( $zone ) },
          @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
        @nss = sort values %nss;
    }

    my $resolver = Zonemaster::Engine->ns( 'google-public-dns-a.google.com', '8.8.8.8' );

    my %seen_rnames;
    for my $ns ( @nss ) {

        my $p = $ns->query( $zone->name, q{SOA} );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns      => $ns->name->string,
                    address => $ns->address->short,
                    dname   => $zone->name,
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
        if ( not valid( $rname ) ) {
            push @results,
              info(
                RNAME_RFC822_INVALID => {
                    rname => $rname,
                }
              );
            next;
        }

        my $domain = ( $rname =~ s/.*@//r );

        my $p_mx = $resolver->query( $domain, q{MX}, { recurse => 1 } );

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
            my $p_a = $resolver->query( $mail_domain, q{A}, { recurse => 1 } );
            if ( $p_a ) {
                my @rrs_a =
                  grep { $_->address ne '127.0.0.1' }
                  grep { $_->owner eq $mail_domain } $p_a->get_records( q{A}, q{answer} );

                if ( @rrs_a ) {
                    $exchange_valid = 1;
                }
            }

            # Lookup IPv6 address for mail domain
            my $p_aaaa;
            if ( !$exchange_valid ) {    # Skip a query if we can
                $p_aaaa = $resolver->query( $mail_domain, q{AAAA}, { recurse => 1 } );
            }
            if ( $p_aaaa ) {
                my @rrs_aaaa =
                  grep { $_->address ne '::1' }
                  grep { $_->owner eq $mail_domain } $p_aaaa->get_records( q{AAAA}, q{answer} );

                if ( @rrs_aaaa ) {
                    $exchange_valid = 1;
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

    return @results;
} ## end sub syntax06

sub syntax07 {
    my ( $class, $zone ) = @_;
    my @results;

    my $p = $zone->query_one( $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $mname = $soa->mname;

        push @results, check_name_syntax( q{MNAME}, $mname );
    }
    else {
        push @results, info( NO_RESPONSE_SOA_QUERY => {} );
    }

    return @results;
}

sub syntax08 {
    my ( $class, $zone ) = @_;
    my @results;

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
                name => $name,
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
                        label => $local_label,
                        name  => "$name",
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
                    name => "$name",
                    tld  => $tld,
                  }
              );
        }

    }

    if ( not scalar @results ) {
        push @results,
          info(
            $info_label_prefix
              . q{_SYNTAX_OK} => {
                name => "$name",
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

=item translation()

Returns a refernce to a hash with translation data. Used by the builtin translation system.

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
