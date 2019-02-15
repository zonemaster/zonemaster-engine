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

1) Install the [EPEL 7][EPEL] repository:

   ```sh
   sudo yum --enablerepo=extras install epel-release
   ```

2) Make sure the development environment is installed:

   ```sh
   sudo yum groupinstall "Development Tools"
   ```

3) Install binary packages:

   ```sh
   sudo yum install cpanminus libidn-devel openssl-devel perl-Clone perl-core perl-Devel-CheckLib perl-File-ShareDir perl-File-Slurp perl-IO-Socket-INET6 perl-JSON-PP perl-List-MoreUtils perl-Module-Find perl-Moose perl-Net-IP perl-Pod-Coverage perl-Readonly-XS perl-Test-Differences perl-Test-Exception perl-Test-Fatal perl-Test-Pod perl-YAML
   ```

4) Install packages from CPAN:

   ```sh
   sudo cpanm Locale::Msgfmt Locale::TextDomain Mail::RFC822::Address Module::Install Module::Install::XSUtil Test::More Text::CSV
   ```

5) Install Zonemaster::LDNS and Zonemaster::Engine:

   ```sh
   sudo cpanm Zonemaster::LDNS Zonemaster::Engine
   ```

### Installation on Debian

1) Refresh the package information

   ```sh
   sudo apt-get update
   ```

2) Install dependencies from binary packages:

   ```sh
   sudo apt-get install build-essential libidn11-dev libfile-sharedir-perl libfile-slurp-perl libhash-merge-perl libio-socket-inet6-perl liblist-moreutils-perl libmail-rfc822-address-perl libmodule-find-perl libmoose-perl libnet-ip-perl libreadonly-xs-perl libtext-csv-perl libssl-dev libdevel-checklib-perl libtool m4 autoconf automake cpanminus
   ```

3) Install Zonemaster::LDNS and Zonemaster::Engine:

   ```sh
   sudo cpanm Zonemaster::LDNS Zonemaster::Engine
   ```


### Installation on FreeBSD

1) Become root:

   ```sh
   su -l
   ```

2) Install dependencies from binary packages:

   ```sh
   pkg install libidn p5-File-ShareDir p5-File-Slurp p5-Hash-Merge p5-IO-Socket-INET6 p5-List-MoreUtils p5-Locale-libintl p5-Mail-RFC822-Address p5-Module-Find p5-Moose p5-Net-IP p5-Readonly-XS p5-Text-CSV p5-App-cpanminus
   ```

3) Install dependencies from CPAN:

   ```sh
   cpanm Test::More inc::Module::Install
   ```

4) Install Zonemaster::LDNS and Zonemaster::Engine:

   ```sh
   cpanm Zonemaster::LDNS Zonemaster::Engine
   ```


### Installation on Ubuntu

Use the procedure for [installation on Debian].


## Post-installation sanity check

Make sure Zonemaster::Engine is properly installed.

```sh
time perl -MZonemaster::Engine -E 'say join "\n", Zonemaster::Engine->test_module("BASIC", "zonemaster.net")'
```

The command is expected to take a few seconds and print some results about the delegation of zonemaster.net.


## What to do next

* For a command line interface, follow the [Zonemaster::CLI installation] instruction.
* For a web interface, follow the [Zonemaster::Backend installation] and [Zonemaster::GUI installation] instructions.
* For a [JSON-RPC API], follow the [Zonemaster::Backend installation] instruction.
* For a Perl API, see the [Zonemaster::Engine API] documentation.


[Declaration of prerequisites]: https://github.com/zonemaster/zonemaster#prerequisites
[EPEL]: https://fedoraproject.org/wiki/EPEL
[Installation on CentOS]: #installation-on-centos
[Installation on Debian]: #installation-on-debian
[Installation on FreeBSD]: #installation-on-freebsd
[Installation on Ubuntu]: #installation-on-ubuntu
[JSON-RPC API]: https://github.com/zonemaster/zonemaster-backend/blob/master/docs/API.md
[Main Zonemaster Repository]: https://github.com/zonemaster/zonemaster
[Zonemaster::Backend installation]: https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Installation.md
[Zonemaster::CLI installation]: https://github.com/zonemaster/zonemaster-cli/blob/master/docs/Installation.md
[Zonemaster::Engine API]: http://search.cpan.org/~znmstr/Zonemaster-Engine/lib/Zonemaster/Engine/Overview.pod
[Zonemaster::GUI installation]: https://github.com/zonemaster/zonemaster-gui/blob/master/docs/Installation.md
