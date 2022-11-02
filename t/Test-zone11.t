use strict;
use warnings;
use utf8;

use Test::More;
use File::Slurp;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Zone} );
}

Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.', {'ibdns.root-servers.net' => ['10.1.72.23']} );

my $datafile = q{t/Test-zone11.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

# By convention, scenario names are in uppercase.
my %subtests = (
    NO_SPF =>               [qw(NO-TXT NO-SPF-TXT)],
    DNS_ERROR =>            [qw(NON-AUTH-TXT NONEXISTENT)],
    INCONSISTENT_SPF =>     [qw(INCONSISTENT-SPF SPF-MISSING-ON-ONE)],
    ALL_DIFFERENT_SPF =>    [qw(ALL-DIFFERENT-SPF)],
    MULTIPLE_SPF_RECORDS => [qw(MULTIPLE-SPF-RECORDS)],
    BAD_SYNTAX =>           [qw(INVALID-SYNTAX RANDOM-BYTES
                                TWO-REDIRECTS TWO-EXPS)],
    GOOD_SPF =>             [qw(TRIVIAL-SPF VALID-SPF
                                REDIRECT-NON-FINAL REDIRECT-AND-ALL
                                CONTAINS-PTR CONTAINS-P-MACRO CONTAINS-PR-MACRO
                                TOO-COMPLEX CONTAINS-INCLUDE CONTAINS-REDIRECT)],
);

my %expectation = (
    NO_SPF => {
        mandatory => [qw(Z11_NO_SPF_FOUND)],
        forbidden => [qw(
                         Z11_INCONSISTENT_SPF_POLICIES
                         Z11_SPF1_MULTIPLE_RECORDS
                         Z11_SPF1_SYNTAX_ERROR
                         Z11_SPF1_SYNTAX_OK
                         Z11_UNABLE_TO_CHECK_FOR_SPF
                    )]
    },
    DNS_ERROR => {
        mandatory => [qw(Z11_UNABLE_TO_CHECK_FOR_SPF)],
        forbidden => [qw(
                         Z11_NO_SPF_FOUND
                         Z11_INCONSISTENT_SPF_POLICIES
                         Z11_SPF1_SYNTAX_ERROR
                         Z11_SPF1_SYNTAX_OK
                         Z11_SPF1_TOO_COMPLEX
                    )]
    },
    INCONSISTENT_SPF => {
        mandatory => [qw(
                         Z11_INCONSISTENT_SPF_POLICIES
                         Z11_DIFFERENT_SPF_POLICIES_FOUND
                    )],
        forbidden => [qw(
                         Z11_NO_SPF_FOUND
                         Z11_SPF1_MULTIPLE_RECORDS
                         Z11_SPF1_SYNTAX_ERROR
                         Z11_SPF1_SYNTAX_OK
                         Z11_UNABLE_TO_CHECK_FOR_SPF
                    )],
        extra => sub {
            my ($messages) = @_;
            has_messages_count("Z11_DIFFERENT_SPF_POLICIES_FOUND", 2, $messages);
        }
    },
    ALL_DIFFERENT_SPF => {
        mandatory => [qw(
                         Z11_INCONSISTENT_SPF_POLICIES
                         Z11_DIFFERENT_SPF_POLICIES_FOUND
                    )],
        forbidden => [qw(
                         Z11_NO_SPF_FOUND
                         Z11_SPF1_MULTIPLE_RECORDS
                         Z11_SPF1_SYNTAX_ERROR
                         Z11_SPF1_SYNTAX_OK
                         Z11_UNABLE_TO_CHECK_FOR_SPF
                    )],
        extra => sub {
            my ($messages) = @_;
            has_messages_count("Z11_DIFFERENT_SPF_POLICIES_FOUND", 3, $messages);
        }
    },
    MULTIPLE_SPF_RECORDS => {
        mandatory => [qw(Z11_SPF1_MULTIPLE_RECORDS)],
        forbidden => [qw(
                         Z11_NO_SPF_FOUND
                         Z11_INCONSISTENT_SPF_POLICIES
                         Z11_SPF1_SYNTAX_ERROR
                         Z11_SPF1_SYNTAX_OK
                         Z11_UNABLE_TO_CHECK_FOR_SPF
                    )]
    },
    BAD_SYNTAX => {
        mandatory => [qw(Z11_SPF1_SYNTAX_ERROR)],
        forbidden => [qw(
                         Z11_NO_SPF_FOUND
                         Z11_INCONSISTENT_SPF_POLICIES
                         Z11_SPF1_MULTIPLE_RECORDS
                         Z11_SPF1_SYNTAX_OK
                         Z11_UNABLE_TO_CHECK_FOR_SPF
                    )]
    },
    GOOD_SPF => {
        mandatory => [qw(Z11_SPF1_SYNTAX_OK)],
        forbidden => [qw(
                         Z11_NO_SPF_FOUND
                         Z11_INCONSISTENT_SPF_POLICIES
                         Z11_SPF1_MULTIPLE_RECORDS
                         Z11_SPF1_SYNTAX_ERROR
                         Z11_UNABLE_TO_CHECK_FOR_SPF
                    )]
    },
);

sub has_messages_count {
    my ($tag, $expected_count, $messages) = @_;

    my $got_count = scalar grep { $_->tag eq $tag } @$messages;
    is($got_count, $expected_count, "Found $expected_count copies of $tag");
}


for my $scenario (sort (keys %subtests)) {
    for my $label (@{$subtests{$scenario}}) {
        my $zone = Zonemaster::Engine->zone( qq{${label}.zone11.xa} );
        my $test_name = lc $zone->name;

        subtest $test_name => sub {
            my @messages = Zonemaster::Engine->test_method( q{Zone}, q{zone11}, $zone );
            my %res = map { $_->tag => 1 } @messages;

            if (my ($error) = grep { $_->tag eq 'MODULE_ERROR' } @messages) {
                diag("Module died with error: " . $error->args->{"msg"});
                fail("Test case executes properly");
            }
            else {
                for my $tag (@{$expectation{$scenario}{mandatory}}) {
                    ok(exists $res{$tag}, "Tag $tag is outputted")
                        or diag "Tag $tag should have been outputted, but wasn't.";
                }
                for my $tag (@{$expectation{$scenario}{forbidden}}) {
                    ok(!exists $res{$tag}, "Tag $tag is not outputted")
                        or diag "Tag $tag was not supposed to be outputted, but it was.";
                }

                # Call function callback for extra tests if such a function is defined
                if (exists $expectation{$scenario}{extra}) {
                    $expectation{$scenario}{extra}->(\@messages);
                }
            }
        };
    }
}

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
