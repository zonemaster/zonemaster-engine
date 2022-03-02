package Zonemaster::Engine::Sanitization;

use 5.014002;

use strict;
use warnings;

use Carp;
use Encode;
use Readonly;
use Try::Tiny;
use Zonemaster::LDNS;
use Data::Dumper;

use Zonemaster::Engine::Sanitization::Errors;

Readonly my $ASCII => qr/^[[:ascii:]]+$/;
Readonly my $VALID_ASCII => qr/^[A-Za-z0-9\/\-_]+$/;
Readonly my $FULL_STOP => qr/\x{002E}/;

sub sanitize_label {
    my ( $label ) = @_;

    my $alabel = "";

    if ( $label =~ $VALID_ASCII ) {
        $alabel = lc $label;
    } elsif ( $label =~ $ASCII ) {
        die Zonemaster::Engine::Exception::DomainSanitization::InvalidAscii->new({ dlabel => $label });
    } elsif (Zonemaster::LDNS::has_idn) {
        try {
            $alabel = Zonemaster::LDNS::to_idn($label);
        } catch {
            die Zonemaster::Engine::Exception::DomainSanitization::InvalidULabel->new({ dlabel => Encode::encode_utf8($label) });
        }
    } else {
        croak 'The domain name contains non-ascii characters and IDNA is not installed';
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
