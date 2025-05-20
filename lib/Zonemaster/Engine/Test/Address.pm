package Zonemaster::Engine::Test::Address;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v1.0.8");

use Carp;
use List::MoreUtils qw[none any];
use Locale::TextDomain qw[Zonemaster-Engine];
use Readonly;

use Zonemaster::Engine::Recursor;
use Zonemaster::Engine::Constants qw[:addresses :ip];
use Zonemaster::Engine::TestMethods;
use Zonemaster::Engine::Util qw[name should_run_test];

=head1 NAME

Zonemaster::Engine::Test::Address - Module implementing tests focused on IP addresses of name servers

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Address->all( $zone );

=head1 METHODS

=over

=item all()

    my @logentry_array = all( $zone );

Runs the default set of tests for that module, i.e. between L<two and three tests|/TESTS> depending on the tested zone.
If L<ADDRESS02|/address02()> passes, L<ADDRESS03|/address03()> is run.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub all {
    my ( $class, $zone ) = @_;

    my @results;

    push @results, $class->address01( $zone )
      if should_run_test( q{address01} );

    my $ns_with_reverse = 1;
    if ( should_run_test( q{address02} ) ) {
        push @results, $class->address02( $zone );
        $ns_with_reverse = any { $_->tag eq q{NAMESERVERS_IP_WITH_REVERSE} } @results;
    }

    # Perform ADDRESS03 if ADDRESS02 passed or was skipped
    if ( $ns_with_reverse ) {
        push @results, $class->address03( $zone )
          if should_run_test( q{address03} );
    }

    return @results;
}

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
        address01 => [
            qw(
              NAMESERVER_IP_PRIVATE_NETWORK
              NO_IP_PRIVATE_NETWORK
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        address02 => [
            qw(
              NAMESERVER_IP_WITHOUT_REVERSE
              NAMESERVERS_IP_WITH_REVERSE
              NO_RESPONSE_PTR_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
        address03 => [
            qw(
              NAMESERVER_IP_WITHOUT_REVERSE
              NAMESERVER_IP_PTR_MISMATCH
              NAMESERVER_IP_PTR_MATCH
              NO_RESPONSE_PTR_QUERY
              TEST_CASE_END
              TEST_CASE_START
              )
        ],
    };
} ## end sub metadata

Readonly my %TAG_DESCRIPTIONS => (
    ADDRESS01 => sub {
        __x    # ADDRESS:ADDRESS01
          'Name server address must be globally routable';
    },
    ADDRESS02 => sub {
        __x    # ADDRESS:ADDRESS02
          'Reverse DNS entry exists for name server IP address';
    },
    ADDRESS03 => sub {
        __x    # ADDRESS:ADDRESS03
          'Reverse DNS entry matches name server name';
    },
    NAMESERVER_IP_WITHOUT_REVERSE => sub {
        __x    # ADDRESS:NAMESERVER_IP_WITHOUT_REVERSE
          'Nameserver {nsname} has an IP address ({ns_ip}) without PTR configured.', @_;
    },
    NAMESERVER_IP_PTR_MISMATCH => sub {
        __x    # ADDRESS:NAMESERVER_IP_PTR_MISMATCH
          'Nameserver {nsname} has an IP address ({ns_ip}) with mismatched PTR result ({names}).', @_;
    },
    NAMESERVER_IP_PRIVATE_NETWORK => sub {
        __x    # ADDRESS:NAMESERVER_IP_PRIVATE_NETWORK
          'Nameserver {nsname} has an IP address ({ns_ip}) '
          . 'with prefix {prefix} referenced in {reference} as a \'{name}\'.',
          @_;
    },
    NO_IP_PRIVATE_NETWORK => sub {
        __x    # ADDRESS:NO_IP_PRIVATE_NETWORK
          'All Nameserver addresses are in the routable public addressing space.', @_;
    },
    NAMESERVERS_IP_WITH_REVERSE => sub {
        __x    # ADDRESS:NAMESERVERS_IP_WITH_REVERSE
          "Reverse DNS entry exists for each Nameserver IP address.", @_;
    },
    NAMESERVER_IP_PTR_MATCH => sub {
        __x    # ADDRESS:NAMESERVER_IP_PTR_MATCH
          "Every reverse DNS entry matches name server name.", @_;
    },
    NO_RESPONSE_PTR_QUERY => sub {
        __x    # ADDRESS:NO_RESPONSE_PTR_QUERY
          'No response from nameserver(s) on PTR query ({domain}).', @_;
    },
    TEST_CASE_END => sub {
        __x    # ADDRESS:TEST_CASE_END
          'TEST_CASE_END {testcase}.', @_;
    },
    TEST_CASE_START => sub {
        __x    # ADDRESS:TEST_CASE_START
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
    return "$Zonemaster::Engine::Test::Address::VERSION";
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

sub _emit_log { my ( $tag, $argref ) = @_; return Zonemaster::Engine->logger->add( $tag, $argref, 'Address' ); }

=over

=item _find_special_address()

    my $hash_ref = _find_special_address( $ip );

Verifies if an IP address is a special (private, reserved, ...) one.

Takes a L<Net::IP::XS> object.

Returns a reference to a hash if true (see L<Zonemaster::Engine::Constants/_extract_iana_ip_blocks()>), or C<undef> if false.

=back

=cut

sub _find_special_address {
    my ( $class, $ip ) = @_;
    my @special_addresses;

    if ( $ip->version == $IP_VERSION_4 ) {
        @special_addresses = @IPV4_SPECIAL_ADDRESSES;
    }
    elsif ( $ip->version == $IP_VERSION_6 ) {
        @special_addresses = @IPV6_SPECIAL_ADDRESSES;
    }

    foreach my $ip_details ( @special_addresses ) {
        if ( $ip->overlaps( ${$ip_details}{ip} ) ) {
            return $ip_details;
        }
    }

    return;
}

=head1 TESTS

=over

=item address01()

    my @logentry_array = address01( $zone );

Runs the L<Address01 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Address-TP/address01.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub address01 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Address01';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my %ips;

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $ips{ $local_ns->address->short };

        my $ip_details_ref = $class->_find_special_address( $local_ns->address );

        if ( $ip_details_ref ) {
            push @results,
              _emit_log(
                NAMESERVER_IP_PRIVATE_NETWORK => {
                    nsname    => $local_ns->name->string,
                    ns_ip     => $local_ns->address->short,
                    prefix    => ${$ip_details_ref}{ip}->short . '/' . ${$ip_details_ref}{ip}->prefixlen,
                    name      => ${$ip_details_ref}{name},
                    reference => ${$ip_details_ref}{reference},
                }
              );
        }

        $ips{ $local_ns->address->short }++;

    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar keys %ips and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results, _emit_log( NO_IP_PRIVATE_NETWORK => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub address01

=over

=item address02()

    my @logentry_array = address02( $zone );

Runs the L<Address02 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Address-TP/address02.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub address02 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Address02';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );

    my %ips;
    my $ptr_query;

    foreach
      my $local_ns ( @{ Zonemaster::Engine::TestMethods->method4( $zone ) }, @{ Zonemaster::Engine::TestMethods->method5( $zone ) } )
    {

        next if $ips{ $local_ns->address->short };

        my $reverse_ip_query = $local_ns->address->reverse_ip;
        $ptr_query = $reverse_ip_query;

        my $p = Zonemaster::Engine::Recursor->recurse( $ptr_query, q{PTR} );

        # In case of Classless IN-ADDR.ARPA delegation, query returns
        # CNAME records. A PTR query is done on the CNAME.
        if ( $p and $p->rcode eq q{NOERROR} and $p->get_records( q{CNAME}, q{answer} ) ) {
            my ( $cname ) = $p->get_records( q{CNAME}, q{answer} );
            $ptr_query = $cname->cname;
            $p = Zonemaster::Engine::Recursor->recurse( $ptr_query, q{PTR} );
        }

        if ( $p ) {
            if ( $p->rcode ne q{NOERROR} or not $p->get_records( q{PTR}, q{answer} ) ) {
                push @results,
                  _emit_log(
                    NAMESERVER_IP_WITHOUT_REVERSE => {
                        nsname => $local_ns->name->string,
                        ns_ip  => $local_ns->address->short,
                    }
                  );
            }
        }
        else {
            push @results,
              _emit_log(
                NO_RESPONSE_PTR_QUERY => {
                    domain => $ptr_query,
                }
              );
        }

        $ips{ $local_ns->address->short }++;

    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar keys %ips and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results, _emit_log( NAMESERVERS_IP_WITH_REVERSE => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub address02

=over

=item address03()

    my @logentry_array = address03( $zone );

Runs the L<Address03 Test Case|https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/tests/Address-TP/address03.md>.

Takes a L<Zonemaster::Engine::Zone> object.

Returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=back

=cut

sub address03 {
    my ( $class, $zone ) = @_;

    local $Zonemaster::Engine::Logger::TEST_CASE_NAME = 'Address03';
    push my @results, _emit_log( TEST_CASE_START => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } );
    my $ptr_query;

    my %ips;

    foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods->method5( $zone ) } ) {

        next if $ips{ $local_ns->address->short };

        my $reverse_ip_query = $local_ns->address->reverse_ip;
        $ptr_query = $reverse_ip_query;

        my $p = Zonemaster::Engine::Recursor->recurse( $ptr_query, q{PTR} );

        if ( $p ) {
            my @ptr = $p->get_records( q{PTR}, 'answer' );
            if ( $p->rcode eq q{NOERROR} and scalar @ptr ) {
                if ( none { name( $_->ptrdname ) eq $local_ns->name->string . q{.} } @ptr ) {
                    push @results,
                      _emit_log(
                        NAMESERVER_IP_PTR_MISMATCH => {
                            nsname => $local_ns->name->string,
                            ns_ip  => $local_ns->address->short,
                            names  => join( q{/}, map { $_->ptrdname } @ptr ),
                        }
                      );
                }
            }
            else {
                push @results,
                  _emit_log(
                    NAMESERVER_IP_WITHOUT_REVERSE => {
                        nsname => $local_ns->name->string,
                        ns_ip  => $local_ns->address->short,
                    }
                  );
            }
        } ## end if ( $p )
        else {
            push @results,
              _emit_log(
                NO_RESPONSE_PTR_QUERY => {
                    domain => $ptr_query,
                }
              );
        }

        $ips{ $local_ns->address->short }++;

    } ## end foreach my $local_ns ( @{ Zonemaster::Engine::TestMethods...})

    if ( scalar keys %ips and not grep { $_->tag ne q{TEST_CASE_START} } @results ) {
        push @results, _emit_log( NAMESERVER_IP_PTR_MATCH => {} );
    }

    return ( @results, _emit_log( TEST_CASE_END => { testcase => $Zonemaster::Engine::Logger::TEST_CASE_NAME } ) );
} ## end sub address03

1;
