use inc::Module::Install;
use Module::Install::Share;

name 'Zonemaster-Engine';
# "name" must be the same as the equivalent string in the following files:
# lib/Zonemaster/Engine/Constants.pm
# lib/Zonemaster/Engine/Config.pm
# lib/Zonemaster/Engine/Translator.pm
# share/Makefile


repository 'https://github.com/zonemaster/zonemaster-engine';
bugtracker 'https://github.com/zonemaster/zonemaster-engine/issues';

all_from 'lib/Zonemaster/Engine.pm';

# "2.1.0" could be declared as "2.001" but not as "2.1"
# (see Zonemaster::LDNS below)

requires 'Class::Accessor'    => 0;
requires 'Clone'              => 0;
requires 'Email::Valid'       => 0;
requires 'File::ShareDir'     => 1.00;
requires 'File::Slurp'        => 0;
requires 'IO::Socket::INET6'  => 2.69;
requires 'List::Compare'      => 0;
requires 'List::MoreUtils'    => 0;
requires 'Locale::TextDomain' => 1.20;
requires 'Log::Any'           => 0;
requires 'Mail::SPF'          => 0;
requires 'Module::Find'       => 0.10;
requires 'Net::DNS'           => 0;
requires 'Net::IP::XS'        => 0.21;
requires 'Readonly'           => 0;
requires 'Text::CSV'          => 0;
requires 'YAML::XS'           => 0;
requires 'Zonemaster::LDNS'   => 5.000000; # For v5.0.0

test_requires 'Locale::PO'        => 0;
test_requires 'Pod::Coverage'     => 0;
test_requires 'Sub::Override'     => 0;
test_requires 'Test::Differences' => 0;
test_requires 'Test::Exception'   => 0;
test_requires 'Test::Fatal'       => 0;
test_requires 'Test::NoWarnings'  => 0;
test_requires 'Test::Pod'         => 1.22;

# Make all platforms include inc/Module/Install/External.pm
requires_external_bin 'find';
if ($^O eq "freebsd") {
    requires_external_bin 'gmake';
};

sub MY::postamble {
    my $pure_all;
    if ($^O eq "freebsd") {
        # Make FreeBSD use gmake for share/Makefile
        $pure_all = 'GMAKE ?= "gmake"' . "\n"
            . 'pure_all :: share/Makefile' . "\n"
            . "\t" . 'cd share && $(GMAKE) all' . "\n";
    } else {
        $pure_all = 'pure_all :: share/Makefile' . "\n"
            . "\t" . 'cd share && $(MAKE) all' . "\n";
    }

    my $docker = <<'END_DOCKER';

docker-build:
	docker build --tag zonemaster/engine:local --build-arg version=$(VERSION) .

docker-tag-version:
	docker tag zonemaster/engine:local zonemaster/engine:$(VERSION)

docker-tag-latest:
	docker tag zonemaster/engine:local zonemaster/engine:latest

END_DOCKER

    return $pure_all . $docker;
};

install_share;

WriteAll;
