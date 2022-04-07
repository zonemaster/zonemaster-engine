use Test::More;
use Test::Exception;

use utf8;

BEGIN { use_ok( 'Zonemaster::Engine::Sanitization' ); }

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
        '🦈．example．com' => 'xn--7s9h.example.com',
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
        subtest 'Domain: ' . $domain => sub {
            my $output;
            lives_ok(sub {
                $output = Zonemaster::Engine::Sanitization::sanitize_name($domain);
            }, 'correct domain should live');
            is($output, $expected_output, 'Match expected domain') or diag($output);
        }
    }
};

subtest 'Bad domains' => sub {
    my %input_domains = (
        # Empty labels
        '.。．' => 'Zonemaster::Engine::Exception::DomainSanitization::InitialDot',
        'example。.com.' => 'Zonemaster::Engine::Exception::DomainSanitization::RepeatedDots',
        'example。com.｡' => 'Zonemaster::Engine::Exception::DomainSanitization::RepeatedDots',
        '．.example｡com' => 'Zonemaster::Engine::Exception::DomainSanitization::InitialDot',

        # Bad ascii
        'bad:%;!$.example.com.' => 'Zonemaster::Engine::Exception::DomainSanitization::InvalidAscii',

        # Label to long
        "a" x 64 . ".example.com" => 'Zonemaster::Engine::Exception::DomainSanitization::LabelTooLong',
        # Length too long after idn conversion (libidn fails)
        'チョコレート' x 8 . 'a' . '.example.com' => 'Zonemaster::Engine::Exception::DomainSanitization::InvalidULabel',

        # Domain to long
        # this is 254 characters
        ("a" x 15 . ".") x 15 . "bc" . ".example.com" => 'Zonemaster::Engine::Exception::DomainSanitization::DomainNameTooLong',

        # Empty domain
        '' => 'Zonemaster::Engine::Exception::DomainSanitization::EmptyDomainName',
    );

    while (($domain, $error) = each (%input_domains)) {
        subtest "Domain: $domain ($error)" => sub {
            throws_ok (sub {
                Zonemaster::Engine::Sanitization::sanitize_name($domain);
            }, $error, 'invalid domain should throw' );
            note "$@";
        }
    }
};

done_testing;
