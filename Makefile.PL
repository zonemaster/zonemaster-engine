use inc::Module::Install;
use Module::Install::Share;

name 'Zonemaster';

license 'http://www.opensource.org/licenses/BSD-3-Clause';
repository 'https://github.com/dotse/zonemaster-engine';
bugtracker 'https://github.com/dotse/zonemaster-engine/issues';

all_from 'lib/Zonemaster.pm';

requires 'Net::LDNS'             => 0.75;
requires 'IO::Socket::INET6'     => 2.69;
requires 'Moose'                 => 2.0401;
requires 'Module::Find'          => 0.10;
requires 'JSON::PP'              => 0;
requires 'File::ShareDir'        => 1.00;
requires 'File::Slurp'           => 0;
requires 'Net::IP'               => 1.26;
requires 'List::MoreUtils'       => 0;
requires 'Mail::RFC822::Address' => 0;
requires 'Hash::Merge'           => 0;
requires 'Readonly'              => 0;
requires 'Time::HiRes'           => 0;
requires 'Locale::TextDomain'    => 0;

recommends 'Readonly::XS' => 0;

sub MY::postamble {
        return <<'MAKE_FRAG';
	$(MYEXTLIB): share/Makefile
	cd share && $(MAKE) all
MAKE_FRAG
};

install_share;

WriteAll;
