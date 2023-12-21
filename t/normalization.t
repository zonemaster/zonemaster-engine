#!perl
use strict;
use utf8;
use warnings;
use Test::More;

use Test::Differences;
use Test::Exception;
use Zonemaster::Engine::Normalization qw( normalize_name trim_space );

sub char_to_hex_esc {
    my ($char) = @_;
    my $ord = ord($char);
    if ($ord >= 32 && $ord <= 127) {
        return $char;
    } elsif ($ord <= 255) {
        return sprintf('\x%02X', $ord);
    } else {
        return sprintf('\x{%04X}', $ord);
    }
}

sub to_hex_esc {
    my ($str) = @_;
    return join('', map({ char_to_hex_esc($_) } (split //, $str)));
}

subtest 'Valid domains' => sub {
    my %input_domains = (
        # Roots
        '.' => '.',  # Full stop
        '．' => '.', # Fullwidth full stop
        '。' => '.', # Ideographic full stop
        '｡' => '.',  # Halfwidth ideographic full stop

        # Mixed dots with trailing dot
        'example。com.' => 'example.com',
        'example｡com．' => 'example.com',
        'sub.example．com｡' => 'sub.example.com',
        'sub．example.com。' => 'sub.example.com',

        # Mixed dots without trailing dot
        'example。com' => 'example.com',
        'example｡com' => 'example.com',
        'sub.example．com' => 'sub.example.com',
        'sub．example.com' => 'sub.example.com',

        # Domains with U-Labels
        'café.example.com' => 'xn--caf-dma.example.com',
        'エグザンプル｡example｡com' => 'xn--ickqs6k2dyb.example.com',
        'αβγδε.example.com' => 'xn--mxacdef.example.com',

        # Domains with uppercase unicode
        'CafÉ.example.com' => 'xn--caf-dma.example.com',
        'ΑβΓΔε.example.com' => 'xn--mxacdef.example.com',

        # All ascii domains (lowercase)
        'example.com' => 'example.com',
        '0/28.2.0.192.example.com' => '0/28.2.0.192.example.com',
        '_http._tcp.example.com.' => '_http._tcp.example.com',
        'sub-domain.example.com' => 'sub-domain.example.com',

        # All ascii domains with uppercase characters
        'suB-doMaIN.ExamPlE.cOm' => 'sub-domain.example.com',

        # Single label domains
        'test' => 'test',
        'テスト' => 'xn--zckzah',

        # Length limits
        "a" x 63 . ".example.com" => "a" x 63 . ".example.com",
        # this is 253 characters
        ("a" x 15 . ".") x 15 . "b" . ".example.com" => ("a" x 15 . ".") x 15 . "b" . ".example.com",

        # NFC conversion (for each group first is non-NFC, second is equivalent NFC)
        "d\x{006F}\x{0308}d" => 'xn--dd-fka',
        'död' => 'xn--dd-fka',

        "aq\x{0307}\x{0323}a" => 'xn--aqa-9dc3l',
        "aq\x{0323}\x{0307}a" => 'xn--aqa-9dc3l',

        "aḋ\x{0323}a" => 'xn--aa-rub587y',
        "aḍ\x{0307}a" => 'xn--aa-rub587y',
    );

    for my $domain ( sort keys %input_domains ) {
        my $expected_output = $input_domains{$domain};
        my $safe_domain = to_hex_esc($domain);
        subtest "Domain: '$safe_domain'" => sub {
            my ( $errors, $final_domain );
            lives_ok(sub {
                ($errors, $final_domain) = normalize_name($domain);
            }, 'correct domain should live');

            my $actual   = { domain => $final_domain,    errors => $errors };
            my $expected = { domain => $expected_output, errors => [] };

            eq_or_diff $actual, $expected;
        }
    }
};

subtest 'Bad domains' => sub {
    my %input_domains = (
        # Empty labels
        '.。．'           => ['INITIAL_DOT'],
        'example。.com.' => ['REPEATED_DOTS'],
        'example。com.｡' => ['REPEATED_DOTS'],
        '．.example｡com' => ['INITIAL_DOT'],

        # Bad ascii
        'bad:%;!$.example.com.'            => ['INVALID_ASCII'],
        " \x{205F} example.com.  \x{0009}" => ['INVALID_ASCII'],
        '    '                             => ['INVALID_ASCII'],

        # Label to long
        "a" x 64 . ".example.com" => ['LABEL_TOO_LONG'],
        # Length too long after idn conversion (libidn fails)
        'チョコレート' x 8 . 'a' . '.example.com' => ['INVALID_U_LABEL'],
        # Emoji in names are invalid as per IDNA2008
        '❤️．example．com' => ['INVALID_U_LABEL'],

        # Domain to long
        # this is 254 characters
        ( "a" x 15 . "." ) x 15 . "bc" . ".example.com" => ['DOMAIN_NAME_TOO_LONG'],

        # Empty domain
        '' => ['EMPTY_DOMAIN_NAME'],

        # Ambiguous downcasing
        'İ.example.com' => ['AMBIGUOUS_DOWNCASING'],
    );

    for my $domain ( sort keys %input_domains ) {
        my $expected_errors = $input_domains{$domain};
        my $safe_domain = to_hex_esc( $domain );
        subtest "Domain: '$safe_domain'" => sub {
            my ( $errors, $final_domain );
            lives_ok(sub {
                ($errors, $final_domain) = normalize_name($domain);
            }, 'incorrect domain should live');

            my $actual = {
                domain => $final_domain,
                errors => [ map { $_->tag } @$errors ]
            };
            my $expected = {
                domain => undef,
                errors => $expected_errors
            };

            eq_or_diff $actual, $expected;
        }
    }
};

subtest 'Trimming space' => sub {
    my %cases = (
        "example."                     => 'example.',
        "exam   ."                     => 'exam   .',
        " \x{205F} example.  \x{0009}" => 'example.',
    );

    for my $str ( sort keys %cases ) {
        my $expected = $cases{$str};

        my $safe_str = to_hex_esc($str);
        subtest "Domain: '$safe_str'" => sub {
            my $actual = trim_space( $str );

            is $actual, $expected, 'Match expected string';
        }
    }
};

done_testing;
