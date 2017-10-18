# Installation

This document describes prerequisites, installation, post-install sanity
checking for Zonemaster::Engine, and rounds up with a few pointer to interfaces
for Zonemaster::Engine. For an overview of the Zonemaster product, please see
the [main Zonemaster Repository].


## Prerequisites

For details on supported operating system versions and Perl verisons for
Zonemaster::Engine, see the [declaration of prerequisites].


## Installation

This instruction covers the following operating systems:

 * [Installation on CentOS]
 * [Installation on Debian]
 * [Installation on FreeBSD]
 * [Installation on Ubuntu]


### Installation on CentOS

1) Make sure the development environment is installed.

   ```sh
   sudo yum groupinstall "Development Tools"
   ```

2) Install packages.

   ```sh
   sudo yum install perl-core perl-ExtUtils-MakeMaker perl-File-ShareDir perl-File-Slurp perl-IO-Socket-INET6 perl-JSON-PP perl-List-MoreUtils perl-Readonly perl-Time-HiRes perl-YAML libidn-devel perl-libintl perl-Devel-CheckLib openssl-devel perl-Test-Fatal
   ```

3) Install CPAN modules.

   If it's the first time you use the CPAN module, it will ask three questions.
   For the first and third, the default responses are fine. For the second, answer
   "sudo" (the default is "local::lib", which you do not want).

   ```sh
   sudo cpan -i Hash::Merge Net::IP::XS Zonemaster::LDNS Moose
   ```

4) Install Zonemaster::Engine

   ```sh
   sudo cpan -i Zonemaster::Engine
   ```

   If necessary, answer any questions from the cpan script by accepting the default value (just press enter).


### Installation on Debian

1) Make sure the package database is up to date.

   ```sh
   sudo apt-get update
   ```

2) Install all necessary packages.

   ```sh
   sudo apt-get install build-essential libfile-slurp-perl libjson-pp-perl liblist-moreutils-perl libio-socket-inet6-perl libmodule-find-perl libmoose-perl libfile-sharedir-perl libhash-merge-perl libreadonly-perl libmail-rfc822-address-perl libintl-xs-perl libssl-dev libdevel-checklib-perl libtest-fatal-perl libtie-simple-perl libio-capture-perl libgeography-countries-perl libidn11-dev gettext
   ```

3) Install Zonemaster::Engine

   ```sh
   sudo cpan -i Zonemaster::Engine
   ```

   If necessary, answer any questions from the cpan script by accepting the default
   value (just press enter).


### Installation on FreeBSD

1) Become root:

   ```sh
   su
   ```

2) Install dependencies from binary packages:

   ```sh
   pkg install libidn p5-File-ShareDir p5-File-Slurp p5-Hash-Merge p5-IO-Socket-INET6 p5-List-MoreUtils p5-Locale-libintl p5-Mail-RFC822-Address p5-Module-Find p5-Moose p5-Net-IP p5-Readonly-XS p5-Text-CSV
   ```

3) Install dependencies from CPAN:

   ```sh
   cpan -i Zonemaster::LDNS
   ```

   > **Note:** If necessary, answer any questions from the cpan script by
   > accepting the default value (just press enter).

   > **Note:** libidn must be installed prior to Zonemaster::LDNS, or otherwise
   > Zonemaster::LDNS will be installed without IDN support.

4) Install Zonemaster::Engine:

   ```sh
   cpan -i Zonemaster::Engine
   ```


### Installation on Ubuntu

Use the procedure for [installation on Debian].


## Post-installation sanity check

Make sure Zonemaster::Engine is properly installed.

```sh
time perl -MZonemaster::Engine -e 'print map {"$_\n"} Zonemaster::Engine->test_module("BASIC", "zonemaster.net")'
```

The command is expected to take a few seconds and print some results about the delegation of zonemaster.net.


## What to do next

* For a command line interface, follow the [Zonemaster::CLI installation] instruction.
* For a web interface, follow the [Zonemaster::Backend installation] and [Zonemaster::GUI installation] instructions.
* For a [JSON-RPC API], follow the [Zonemaster::Backend installation] instruction.
* For a Perl API, see the [Zonemaster::Engine API] documentation.

-------

[Declaration of prerequisites]: https://github.com/dotse/zonemaster#prerequisites
[Installation on CentOS]: #installation-on-centos
[Installation on Debian]: #installation-on-debian
[Installation on FreeBSD]: #installation-on-freebsd
[Installation on Ubuntu]: #installation-on-ubuntu
[JSON-RPC API]: https://github.com/dotse/zonemaster-backend/blob/master/docs/API.md
[Main Zonemaster Repository]: https://github.com/dotse/zonemaster
[Zonemaster::Backend installation]: https://github.com/dotse/zonemaster-backend/blob/master/docs/installation.md
[Zonemaster::CLI installation]: https://github.com/dotse/zonemaster-cli/blob/master/docs/installation.md
[Zonemaster::Engine API]: http://search.cpan.org/~znmstr/Zonemaster-Engine/lib/Zonemaster/Engine/Overview.pod
[Zonemaster::GUI installation]: https://github.com/dotse/zonemaster-gui/blob/master/docs/installation.md

Copyright (c) 2013 - 2017, IIS (The Internet Foundation in Sweden)\
Copyright (c) 2013 - 2017, AFNIC\
Creative Commons Attribution 4.0 International License

You should have received a copy of the license along with this
work.  If not, see <http://creativecommons.org/licenses/by/4.0/>.
