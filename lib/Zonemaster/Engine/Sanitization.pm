package Zonemaster::Engine::Sanitization;

use 5.014002;

use strict;
use warnings;

use Encode;
use Readonly;
use Zonemaster::LDNS;

use Zonemaster::Engine::Sanitization::Errors;

Readonly my $VALID_ASCII => q/^[A-Za-z0-9\/\-_]+$/;
Readonly my $FULL_STOP => q/\x{002E}/;

sub sanitize_label {
    my ( $label ) = @_;

    my $alabel = eval {
        Encode::encode('ascii', $label, Encode::FB_CROAK);
    };

    # Not ascii string, assume u-label
    if ($@) {
        $alabel = eval {
            Zonemaster::LDNS::to_idn($label)
        };
        # TODO: handle when libidn not installed?
        if ($@) {
            die Zonemaster::Engine::Exception::DomainSanitization::InvalidULabel->new({ dlabel => Encode::encode_utf8($label) });
        }
    } else {
        if ( $alabel !~ $VALID_ASCII) {
            die Zonemaster::Engine::Exception::DomainSanitization::InvalidAscii->new({ dlabel => $alabel });
        }
        $alabel = lc $alabel;
    }

    if ( length($alabel) > 63) {
        die Zonemaster::Engine::Exception::DomainSanitization::LabelTooLong->new({ dlabel => $alabel });
    }
    return $alabel;
}

sub sanitize_name {
    my ( $uname ) = @_;

    if (length($uname) == 0) {
        die Zonemaster::Engine::Exception::DomainSanitization::EmptyDomainName->new();
    }

    # Replace fullwidth full stop, ideographic full stop and halfwidth ideographic full stop with full stop
    $uname =~ s/[\x{FF0E}\x{3002}\x{FF61}]/\x{002E}/g;

    if ( $uname eq '.' ) {
        return $uname;
    }

    if ($uname =~ /^${FULL_STOP}/) {
        die Zonemaster::Engine::Exception::DomainSanitization::InitialDot->new();
    }

    if ($uname =~ /${FULL_STOP}{2,}/ ) {
        die Zonemaster::Engine::Exception::DomainSanitization::RepeatedDots->new();
    }

    $uname =~ s/${FULL_STOP}$//g;

    my @labels = split $FULL_STOP, $uname;
    @labels = map { sanitize_label($_) } @labels;

    my $final_name = join '.', @labels;

    if (length($final_name) > 253) {
        die Zonemaster::Engine::Exception::DomainSanitization::DomainNameTooLong->new();
    }

    return $final_name;
}

1;
