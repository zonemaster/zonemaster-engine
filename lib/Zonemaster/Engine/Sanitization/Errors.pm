package Zonemaster::Engine::Exception::DomainSanitizationError;

use 5.014002;

use strict;
use warnings;

use Class::Accessor "antlers";

use Zonemaster::Engine::Exception;
extends(qw/Zonemaster::Engine::Exception/);


has 'type' => ( is => 'ro', isa => 'Str' );

sub new {
    my $proto = shift;
    my $obj = __PACKAGE__->SUPER::new(@_);
    my $class = ref $proto || $proto;
    return bless $obj, $class;
}

package Zonemaster::Engine::Exception::DomainSanitization::InitialDot;
use 5.014002;

use strict;
use warnings;

use Class::Accessor "antlers";

extends(qw/Zonemaster::Engine::Exception::DomainSanitizationError/);


sub new {
    my $proto = shift;
    my $params = shift;

    $params->{tag} = 'INITIAL_DOT';
    $params->{message} = 'Domain name starts with dot.';

    my $class = ref $proto || $proto;
    my $obj = __PACKAGE__->SUPER::new($params);
    return bless $obj, $class;
}

package Zonemaster::Engine::Exception::DomainSanitization::RepeatedDots;
use 5.014002;

use strict;
use warnings;

use Class::Accessor "antlers";

extends(qw/Zonemaster::Engine::Exception::DomainSanitizationError/);


sub new {
    my $proto = shift;
    my $params = shift;

    $params->{tag} = 'REPEATED_DOTS';
    $params->{message} = 'Domain name has repeated dots.';

    my $class = ref $proto || $proto;
    my $obj = __PACKAGE__->SUPER::new($params);
    return bless $obj, $class;
}

package Zonemaster::Engine::Exception::DomainSanitization::InvalidAscii;
use 5.014002;

use strict;
use warnings;

use Class::Accessor "antlers";

extends(qw/Zonemaster::Engine::Exception::DomainSanitizationError/);

has 'dlabel' => ( is => 'ro', isa => 'Str' );

sub new {
    my $proto = shift;
    my $params = shift;

    $params->{tag} = 'INVALID_ASCII';
    $params->{message} = 'Domain name has an ASCII label with a character not permitted.';

    my $class = ref $proto || $proto;
    my $obj = __PACKAGE__->SUPER::new($params);
    return bless $obj, $class;
}

package Zonemaster::Engine::Exception::DomainSanitization::InvalidULabel;
use 5.014002;

use strict;
use warnings;

use Class::Accessor "antlers";

extends(qw/Zonemaster::Engine::Exception::DomainSanitizationError/);

has 'dlabel' => ( is => 'ro', isa => 'Str' );

sub new {
    my $proto = shift;
    my $params = shift;

    $params->{tag} = 'INVALID_U_LABEL';
    $params->{message} = 'Domain name has a non-ASCII label which is not a valid U-label.';

    my $class = ref $proto || $proto;
    my $obj = __PACKAGE__->SUPER::new($params);
    return bless $obj, $class;
}

package Zonemaster::Engine::Exception::DomainSanitization::LabelTooLong;
use 5.014002;

use strict;
use warnings;

use Class::Accessor "antlers";

extends(qw/Zonemaster::Engine::Exception::DomainSanitizationError/);

has 'dlabel' => ( is => 'ro', isa => 'Str' );

sub new {
    my $proto = shift;
    my $params = shift;

    $params->{tag} = 'LABEL_TOO_LONG';
    $params->{message} = 'Domain name has a label that is too long (more than 63 characters).';

    my $class = ref $proto || $proto;
    my $obj = __PACKAGE__->SUPER::new($params);
    return bless $obj, $class;
}

package Zonemaster::Engine::Exception::DomainSanitization::DomainNameTooLong;
use 5.014002;

use strict;
use warnings;

use Class::Accessor "antlers";

extends(qw/Zonemaster::Engine::Exception::DomainSanitizationError/);


sub new {
    my $proto = shift;
    my $params = shift;

    $params->{tag} = 'DOMAIN_NAME_TOO_LONG';
    $params->{message} = 'Domain name is too long (more than 253 characters with no final dot).';

    my $class = ref $proto || $proto;
    my $obj = __PACKAGE__->SUPER::new($params);
    return bless $obj, $class;
}

package Zonemaster::Engine::Exception::DomainSanitization::EmptyDomainName;
use 5.014002;

use strict;
use warnings;

use Class::Accessor "antlers";

extends(qw/Zonemaster::Engine::Exception::DomainSanitizationError/);


sub new {
    my $proto = shift;
    my $params = shift;

    $params->{tag} = 'EMPTY_DOMAIN_NAME';
    $params->{message} = 'Domain name is empty.';

    my $class = ref $proto || $proto;
    my $obj = __PACKAGE__->SUPER::new($params);
    return bless $obj, $class;
}

1;
