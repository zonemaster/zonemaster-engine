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
use Zonemaster::Engine::Util qw[should_run_test];
use Zonemaster::LDNS;

=head1 NAME

Zonemaster::Engine::Test::Syntax - Module implementing tests focused on validating the syntax of host names and other data

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Syntax->all( $zone );

=head1 METHODS

=over

=item all()

    my @logentry_array = all( $zone );

Runs the default set of tests for that module, i.e. between L<three and eight tests|/TESTS> depending on the tested zone.
If L<Syntax01|/syntax01()> passes, the remaining tests are run.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub all {
    my ( $class, $zone ) = @_;

    my @results;

    my $only_allowed_chars = 0;
    if ( should_run_test( q{syntax01} ) ) {
        push @results, $class->syntax01( $zone );
        $only_allowed_chars = any { $_->tag eq q{ONLY_ALLOWED_CHARS} } @results;
    }

    push @results, $class->syntax02( $zone )
      if should_run_test( q{syntax02} );

    push @results, $class->syntax03( $zone )
      if should_run_test( q{syntax03} );

    return @results
      if !$only_allowed_chars;

    push @results, $class->syntax04( Zonemaster::Engine->zone( $zone ) )
      if Zonemaster::Engine::Util::should_run_test( q{syntax04} );

    my $all_soa_responses = 1;
    if ( should_run_test( q{syntax05} ) ) {
        push @results, $class->syntax05( $zone );
        $all_soa_responses = none { $_->tag eq q{NO_RESPONSE_SOA_QUERY} } @results;
    }

    if ( $all_soa_responses ) {
        push @results, $class->syntax06( $zone )
          if should_run_test( q{syntax06} );

        push @results, $class->syntax07( $zone )
          if should_run_test( q{syntax07} );
    }

    push @results, $class->syntax08( $zone )
      if should_run_test( q{syntax08} );

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
          'No illegal characters in the domain name';
    },
    SYNTAX02 => sub {
        __x    # SYNTAX:SYNTAX02
          'No hyphen (\'-\') at the start or end of the domain name';
    },
    SYNTAX03 => sub {
        __x    # SYNTAX:SYNTAX03
          'There must be no double hyphen (\'--\') in position 3 and 4 of the domain name';
    },
    SYNTAX04 => sub {
        __x    # SYNTAX:SYNTAX04
          'The NS name must have a valid domain/hostname';
    },
    SYNTAX05 => sub {
        __x    # SYNTAX:SYNTAX05
          'Misuse of \'@\' character in the SOA RNAME field';
    },
    SYNTAX06 => sub {
        __x    # SYNTAX:SYNTAX06
          'No illegal characters in the SOA RNAME field';
    },
    SYNTAX07 => sub {
        __x    # SYNTAX:SYNTAX07
          'No illegal characters in the SOA MNAME field';
    },
    SYNTAX08 => sub {
        __x    # SYNTAX:SYNTAX08
          'MX name must have a valid hostname';
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
    return "$Zonemaster::Engine::Test::Syntax::VERSION";
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

sub _emit_log { my ( $tag, $argref ) = @_; return Zonemaster::Engine->logger->add( $tag, $argref, 'Syntax' ); }

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

=over

=item _name_has_only_legal_characters()

    my $bool = _name_has_only_legal_characters( $name );

Checks if a given name contains only allowed characters.

Takes a L<Zonemaster::Engine::DNSName> object.

Returns a boolean.

=back

=cut

sub _name_has_only_legal_characters {
    my ( $name ) = @_;

    if ( List::MoreUtils::all { m/\A[-A-Za-z0-9]+\z/smx } @{ $name->labels } ) {
        return 1;
    }
    else {
        return 0;
    }
}

=over

=item _label_starts_with_hyphen()

    my $bool = _label_starts_with_hyphen( $name );

Checks if a given name starts with an hyphen ('-').

Takes a L<Zonemaster::Engine::DNSName> object.

Returns a boolean.

=back

=cut

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

=over

=item _label_ends_with_hyphen()

    my $bool = _label_ends_with_hyphen( $name );

Checks if a given name ends with an hyphen ('-').

Takes a L<Zonemaster::Engine::DNSName> object.

Returns a boolean.

=back

=cut

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

=over

=item _label_not_ace_has_double_hyphen_in_position_3_and_4()

    my $bool = _label_not_ace_has_double_hyphen_in_position_3_and_4( $name );

Checks if a given name does not contain a double hyphen ('--'), with the exception of 'xn--'.

Takes a L<Zonemaster::Engine::DNSName> object.

Returns a boolean.

=back

=cut

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

=over

=item _check_name_syntax()

    my @logentry_array = _check_name_syntax( $label_prefix_string, $name );

Checks the syntax of a given name. Makes use of L</_name_has_only_legal_characters()> and L</_label_not_ace_has_double_hyphen_in_position_3_and_4()>.
Used as an helper function for Test Cases L<Syntax04|/syntax04()>, L<Syntax07|/syntax07()> and L<Syntax08|/syntax08()>.

Takes a string (label prefix) and either a string (name) or a L<Zonemaster::Engine::DNSName> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub _check_name_syntax {
    my ( $info_label_prefix, $name ) = @_;
    my @results;

    $name = Zonemaster::Engine::Util::name( $name );

    if ( not _name_has_only_legal_characters( $name ) ) {
        push @results,
          _emit_log(
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
                  _emit_log(
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
              _emit_log(
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
          _emit_log(
            $info_label_prefix
              . q{_SYNTAX_OK} => {
                domain => "$name",
              }
          );
    }

    return @results;
} ## end sub _check_name_syntax

=head1 TESTS

=over

=item syntax01()

    my @logentry_array = syntax01( $zone );

Runs the L<Syntax01 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Syntax-TP/syntax01.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub syntax01 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Syntax01';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $name = $zone->name;

    if ( _name_has_only_legal_characters( $name ) ) {
        push @results,
          _emit_log(
            ONLY_ALLOWED_CHARS => {
                domain => $name,
            }
          );
    }
    else {
        push @results,
          _emit_log(
            NON_ALLOWED_CHARS => {
                domain => $name,
            }
          );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub syntax01

=over

=item syntax02()

    my @logentry_array = syntax02( $zone );

Runs the L<Syntax02 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Syntax-TP/syntax02.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub syntax02 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Syntax02';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $name = $zone->name;

    foreach my $local_label ( @{ $name->labels } ) {
        if ( _label_starts_with_hyphen( $local_label ) ) {
            push @results,
              _emit_log(
                INITIAL_HYPHEN => {
                    label  => $local_label,
                    domain => $name,
                }
              );
        }
        if ( _label_ends_with_hyphen( $local_label ) ) {
            push @results,
              _emit_log(
                TERMINAL_HYPHEN => {
                    label  => $local_label,
                    domain => $name,
                }
              );
        }
    } ## end foreach my $local_label ( @...)

    if ( scalar @{ $name->labels } and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results,
          _emit_log(
            NO_ENDING_HYPHENS => {
                domain => $name,
            }
          );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub syntax02

=over

=item syntax03()

    my @logentry_array = syntax03( $zone );

Runs the L<Syntax03 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Syntax-TP/syntax03.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub syntax03 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Syntax03';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $name = $zone->name;

    foreach my $local_label ( @{ $name->labels } ) {
        if ( _label_not_ace_has_double_hyphen_in_position_3_and_4( $local_label ) ) {
            push @results,
              _emit_log(
                DISCOURAGED_DOUBLE_DASH => {
                    label  => $local_label,
                    domain => $name,
                }
              );
        }
    }

    if ( scalar @{ $name->labels } and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results,
          _emit_log(
            NO_DOUBLE_DASH => {
                domain => $name,
            }
          );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub syntax03

=over

=item syntax04()

    my @logentry_array = syntax04( $zone );

Runs the L<Syntax04 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Syntax-TP/syntax04.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub syntax04 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Syntax04';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    foreach my $local_nsname (
        uniq(
            @{ Zonemaster::Engine::TestMethods->method2( $zone ) },
            @{ Zonemaster::Engine::TestMethods->method3( $zone ) }
        )
      )
    {
        push @results, _check_name_syntax( q{NAMESERVER}, $zone->name );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
}

=over

=item syntax05()

    my @logentry_array = syntax05( $zone );

Runs the L<Syntax05 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Syntax-TP/syntax05.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub syntax05 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Syntax05';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $p = $zone->query_one( $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $rname = $soa->rname;
        $rname =~ s/\\./\./smgx;
        if ( index( $rname, q{@} ) != -1 ) {
            push @results,
              _emit_log(
                RNAME_MISUSED_AT_SIGN => {
                    rname => $soa->rname,
                }
              );
        }
        else {
            push @results,
              _emit_log(
                RNAME_NO_AT_SIGN => {
                    rname => $soa->rname,
                }
              );
        }
    } ## end if ( $p and my ( $soa ...))
    else {
        push @results, _emit_log( NO_RESPONSE_SOA_QUERY => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub syntax05

=over

=item syntax06()

    my @logentry_array = syntax06( $zone );

Runs the L<Syntax06 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Syntax-TP/syntax06.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub syntax06 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Syntax06';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my @nss;
    {
        my %nss = map { $_->string => $_ }
          @{ Zonemaster::Engine::TestMethods->method4( $zone ) },
          @{ Zonemaster::Engine::TestMethods->method5( $zone ) };
        @nss = sort values %nss;
    }

    my %rname_candidates;
    my %seen_mail_servers;
    my $invalid_exchanges = undef;
    for my $ns ( @nss ) {
        if ( _ip_disabled_message( \@results, $ns, q{SOA} ) ) {
            next;
        }

        my $p = $ns->query( $zone->name, q{SOA}, { recurse => 0, usevc => 0 } );

        if ( not $p ) {
            push @results,
              _emit_log(
                NO_RESPONSE => {
                    ns     => $ns->string,
                    domain => $zone->name,
                }
              );
            next;
        }

        my ( $soa ) = $p->get_records( q{SOA}, q{answer} );

        if ( not $soa ) {
            push @results, _emit_log( NO_RESPONSE_SOA_QUERY => {} );
            next;
        }

        my $rname = $soa->rname;
        $rname =~ s/([^\\])[.]/$1@/smx;    # Replace first non-escaped dot with an at-sign
        $rname =~ s/[\\][.]/./smgx;        # Un-escape dots
        $rname =~ s/[.]\z//smgx;           # Validator does not like final dots
        if ( not Email::Valid->address( $rname ) ) {
            push @results,
              _emit_log(
                RNAME_RFC822_INVALID => {
                    rname => $rname,
                }
              );
            next;
        }

        my $domain = ( $rname =~ s/.*@//r );
        my $p_mx = Zonemaster::Engine::Recursor->recurse( $domain, q{MX} );
        if ( not $p_mx or $p_mx->rcode ne 'NOERROR' ) {
            push @results, _emit_log( RNAME_MAIL_DOMAIN_INVALID => { domain => $domain } );
            next;
        }

        # Follow CNAMEs in the MX response
        my %cnames =
          map { $_->owner => $_->cname } $p_mx->get_records( q{CNAME}, q{answer} );
        $domain .= q{.};    # Add back final dot
        $domain = $cnames{$domain} while $cnames{$domain};

        # Determine mail server(s)
        my @mail_servers;
        if ( my @mxs = $p_mx->get_records_for_name( q{MX}, $domain ) ) {
            @mail_servers = uniq( map { $_->exchange } @mxs );
        }
        else {
            @mail_servers = ( $domain );
        }

        for my $mail_server ( @mail_servers ) {
            next if $seen_mail_servers{$mail_server};
            $seen_mail_servers{$mail_server} = 1;

            # Assume mail server is invalid until we see an actual IP address
            my $exchange_valid = 0;
            $invalid_exchanges = 0 unless defined $invalid_exchanges;

            # Lookup IPv4 address for mail server
            my $p_a = Zonemaster::Engine::Recursor->recurse( $mail_server, q{A} );
            if ( $p_a ) {
                if ( $p_a->get_records( q{CNAME}, q{answer} ) ) {
                    push @results, _emit_log( RNAME_MAIL_ILLEGAL_CNAME => { domain => $mail_server } );
                }
                else {
                    my @rrs_a = grep { $_->owner eq $mail_server } $p_a->get_records( q{A}, q{answer} );

                    if ( grep { $_->address eq q{127.0.0.1} } @rrs_a ) {
                        push @results, _emit_log( RNAME_MAIL_DOMAIN_LOCALHOST => { domain => $mail_server, localhost => q{127.0.0.1} } );
                    }
                    elsif ( @rrs_a ) {
                        $exchange_valid = 1;
                    }
                }
            }

            # Lookup IPv6 address for mail server
            my $p_aaaa = Zonemaster::Engine::Recursor->recurse( $mail_server, q{AAAA} );
            if ( $p_aaaa ) {
                if ( $p_aaaa->get_records( q{CNAME}, q{answer} ) ) {
                    push @results, _emit_log( RNAME_MAIL_ILLEGAL_CNAME => { domain => $mail_server } );
                }
                else {
                    my @rrs_aaaa = grep { $_->owner eq $mail_server } $p_aaaa->get_records( q{AAAA}, q{answer} );

                    if ( grep { $_->address eq q{::1} } @rrs_aaaa) {
                        push @results, _emit_log( RNAME_MAIL_DOMAIN_LOCALHOST => { domain => $mail_server, localhost => q{::1} } );
                    }
                    elsif ( @rrs_aaaa ) {
                        $exchange_valid = 1;
                    }
                }
            }

            # Emit verdict for mail server
            if ( $exchange_valid ) {
                $rname_candidates{$rname} = 1;
            }
            else {
                push @results, _emit_log( RNAME_MAIL_DOMAIN_INVALID => { domain => $mail_server } );
                delete $rname_candidates{$rname};
                $invalid_exchanges++;
            }
        } ## end for my $mail_server ( @mail_servers)

    } ## end for my $ns ( @nss )

    if ( defined $invalid_exchanges and $invalid_exchanges == 0 ) {
        push @results,
          _emit_log(
            RNAME_RFC822_VALID => {
                rname => $_,
            }
          ) for keys %rname_candidates;
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => (split /::/, (caller(0))[3])[-1] } ) );
} ## end sub syntax06

=over

=item syntax07()

    my @logentry_array = syntax07( $zone );

Runs the L<Syntax07 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Syntax-TP/syntax07.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub syntax07 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Syntax07';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $p = $zone->query_one( $zone->name, q{SOA} );

    if ( $p and my ( $soa ) = $p->get_records( q{SOA}, q{answer} ) ) {
        my $mname = $soa->mname;

        push @results, _check_name_syntax( q{MNAME}, $mname );
    }
    else {
        push @results, _emit_log( NO_RESPONSE_SOA_QUERY => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
}

=over

=item syntax08()

    my @logentry_array = syntax08( $zone );

Runs the L<Syntax08 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Syntax-TP/syntax08.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub syntax08 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Syntax08';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my $p = $zone->query_one( $zone->name, q{MX} );

    if ( $p ) {
        my %mx = map { $_->exchange => 1 } $p->get_records( q{MX}, q{answer} );
        foreach my $mx ( sort keys %mx ) {
            push @results, _check_name_syntax( q{MX}, $mx );
        }
    }
    else {
        push @results, _emit_log( NO_RESPONSE_MX_QUERY => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
}

1;
