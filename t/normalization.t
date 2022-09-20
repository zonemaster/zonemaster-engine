use Test::More;
use Test::Exception;

use utf8;

BEGIN { use_ok( 'Zonemaster::Engine::Normalization' ); }

subtest 'Valid domains' => sub {
    my %input_domains = (
        # Roots
        '.' => '.',  # Full stop
        '．' => '.', # Fullwidth full stop
        '。' => '.', # Ideographic full stop
        '｡' => '.',  # Halfwidth ideographic full stop

        # Trailing and leading white spaces
        " \x{205F} example.com.  \x{0009}" => 'example.com',

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
    );

    while (($domain, $expected_output) = each (%input_domains)) {
        subtest "Domain: '$domain'" => sub {
            my $errors, $final_domain;
            lives_ok(sub {
                ($errors, $final_domain) = normalize_name($domain);
            }, 'correct domain should live');
            is(scalar @{$errors}, 0, 'No error returned') or diag(@{$errors});
            is($final_domain, $expected_output, 'Match expected domain') or diag($final_domain);
        }
    }
};

subtest 'Bad domains' => sub {
    my %input_domains = (
        # Empty labels
        '.。．' => 'INITIAL_DOT',
        'example。.com.' => 'REPEATED_DOTS',
        'example。com.｡' => 'REPEATED_DOTS',
        '．.example｡com' => 'INITIAL_DOT',

        # Bad ascii
        'bad:%;!$.example.com.' => 'INVALID_ASCII',

        # Label to long
        "a" x 64 . ".example.com" => 'LABEL_TOO_LONG',
        # Length too long after idn conversion (libidn fails)
        'チョコレート' x 8 . 'a' . '.example.com' => 'INVALID_U_LABEL',
        # Emoji in names are invalid as per IDNA2008
        '❤️．example．com' => 'INVALID_U_LABEL',

        # Domain to long
        # this is 254 characters
        ("a" x 15 . ".") x 15 . "bc" . ".example.com" => 'DOMAIN_NAME_TOO_LONG',

        # Empty domain
        '' => 'EMPTY_DOMAIN_NAME',
        '    ' => 'EMPTY_DOMAIN_NAME',

        # Ambiguous downcasing
        'İ.example.com' => 'AMBIGUOUS_DOWNCASING',
    );

    while (($domain, $error) = each (%input_domains)) {
        subtest "Domain: '$domain' ($error)" => sub {
            my $output, $messages, $domain;
            lives_ok(sub {
                ($errors, $final_domain) = normalize_name($domain);
            }, 'incorrect domain should live');

            is($final_domain, undef, 'No domain returned') or diag($final_domain);
            is($errors->[0]->tag, $error, 'Correct error is returned') or diag($errors[0]);
            note($errors->[0])
        }
    }
};

done_testing;
