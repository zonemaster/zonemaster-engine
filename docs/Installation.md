# Installation

## Table of contents

* [Overview](#Overview)
* [Docker](#Docker)
* [Prerequisites](#Prerequisites)
* [Local installation](#Local-installation)
  * [Installation on Rocky Linux]
  * [Installation on Debian and Ubuntu]
  * [Installation on FreeBSD]
  * [Installation on CentOS 7]
* [Post-installation sanity check](#Post-installation-sanity-check)
* [What to do next](#What-to-do-next)


## Overview

This document describes prerequisites, installation, post-install sanity
checking for Zonemaster::Engine, and rounds up with a few pointer to interfaces
for Zonemaster::Engine. For an overview of the Zonemaster product, please see
the [main Zonemaster Repository].


## Docker

Zonemaster-CLI is available on [Docker Hub], and can be conveniently downloaded
and run without any installation. See [USING] Zonemaster-CLI for how to run
Zonemaster-CLI on Docker.

To build your own Docker image, see the [Docker Image Creation] documentation.

The rest of this document is about doing a local installation of
Zonemaster-Engine, not relevant for running Zonemaster-CLI on Docker.


## Prerequisites

For details on supported operating system versions and Perl verisons for
Zonemaster::Engine, see the [declaration of prerequisites].


## Local installation

### Installation on Rocky Linux

1) Enable PowerTools:

   ```sh
   sudo dnf config-manager --set-enabled powertools
   ```

2) Install the [EPEL] repository:

   ```sh
   sudo dnf --assumeyes --enablerepo=extras install epel-release
   ```

3) Install binary packages:

   ```sh
   sudo dnf --assumeyes install cpanminus gcc libidn2-devel openssl-devel perl-Class-Accessor perl-Clone perl-core perl-Devel-CheckLib perl-Email-Valid perl-File-ShareDir perl-File-Slurp perl-libintl perl-IO-Socket-INET6 perl-List-MoreUtils perl-Module-Find perl-Module-Install perl-Moose perl-Pod-Coverage perl-Readonly perl-Test-Differences perl-Test-Exception perl-Test-Fatal perl-Test-NoWarnings perl-Test-Pod perl-Text-CSV perl-Test-Simple perl-YAML
   ```

4) Install packages from CPAN:

   ```sh
   sudo cpanm Module::Install::XSUtil MooseX::Singleton Net::IP::XS
   ```

5) Install Zonemaster::LDNS and Zonemaster::Engine:

     ```sh
     sudo cpanm Zonemaster::LDNS Zonemaster::Engine
     ```

### Installation on Debian and Ubuntu

Using pre-built packages is the preferred method for Debian and Ubuntu.

#### Installation from pre-built packages

1) Upgrade to latest patch level

   ```sh
   sudo apt update && sudo apt upgrade
   ```

2) Add Zonemaster packages repository to repository list
   ```sh
   curl -LOs https://package.zonemaster.net/setup.sh
   sudo sh setup.sh
   ```

3) Install Zonemaster Engine
   ```sh
   sudo apt install libzonemaster-engine-perl
   ```

#### Installation from CPAN

1) Upgrade to latest patch level

   ```sh
   sudo apt update && sudo apt upgrade
   ```

2) Install dependencies from binary packages:

   ```sh
   sudo apt install autoconf automake build-essential cpanminus libclass-accessor-perl libclone-perl libdevel-checklib-perl libemail-valid-perl libfile-sharedir-perl libfile-slurp-perl libidn2-dev libintl-perl libio-socket-inet6-perl liblist-moreutils-perl libmodule-find-perl libmodule-install-perl libmodule-install-xsutil-perl libmoose-perl libmoosex-singleton-perl libnet-ip-perl libpod-coverage-perl libreadonly-perl libssl-dev libldns3 libldns-dev libtest-differences-perl libtest-exception-perl libtest-fatal-perl libtest-nowarnings-perl libtest-pod-perl libtext-csv-perl libtool m4
   ```

3) Install Zonemaster::LDNS and Zonemaster::Engine.

   ```sh
   sudo cpanm --configure-args="--no-internal-ldns" Zonemaster::LDNS Zonemaster::Engine
   ```

### Installation on FreeBSD

1) Become root:

   ```sh
   su -l
   ```

2) Update list of package repositories:

   Create the file `/usr/local/etc/pkg/repos/FreeBSD.conf` with the
   following content, unless it is already updated:

   ```
   FreeBSD: {
   url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest",
   }
   ```

3) Check or activate the package system:

   Run the following command, and accept the installation of the `pkg` package
   if suggested.

   ```
   pkg info -E pkg
   ```

4) Update local package repository:

   ```
   pkg update -f
   ```

5) Install dependencies from binary packages:

   ```sh
   pkg install devel/gmake libidn2 p5-App-cpanminus p5-Class-Accessor p5-Clone p5-Devel-CheckLib p5-Email-Valid p5-File-ShareDir p5-File-Slurp p5-IO-Socket-INET6 p5-List-MoreUtils p5-Locale-libintl p5-Module-Find p5-Module-Install p5-Module-Install-XSUtil p5-Moose p5-MooseX-Singleton p5-Net-IP-XS p5-Pod-Coverage p5-Readonly p5-Test-Differences p5-Test-Exception p5-Test-Fatal p5-Test-NoWarnings p5-Test-Pod p5-Text-CSV net-mgmt/p5-Net-IP dns/ldns
   ```

6) Install Zonemaster::LDNS:

   ```sh
   cpanm --configure-args="--no-internal-ldns" Zonemaster::LDNS
   ```

7) Install Zonemaster::Engine:

   ```sh
   cpanm Zonemaster::Engine
   ```

### Installation on CentOS 7

> **Please note!** CentOS 7 will only be supported until the release of
> v2023.1, which is expected to happen during the spring of 2023. Consider
> [Rocky Linux][Installation on Rocky Linux] for an alternative Red Hat Linux
> derivative.
> If you like you could [reach out to let us know to which OS you
> migrated][Mailing list zonemaster-users].

1) Install the [EPEL] repository:

   ```sh
   sudo yum --assumeyes --enablerepo=extras install epel-release
   ```

2) Install binary packages:

   ```sh
   sudo yum --assumeyes install cpanminus gcc libidn2-devel openssl-devel openssl11-devel perl-Class-Accessor perl-Clone perl-core perl-Devel-CheckLib perl-Email-Valid perl-File-ShareDir perl-File-Slurp perl-libintl perl-IO-Socket-INET6 perl-List-MoreUtils perl-Module-Find perl-Module-Install perl-Moose perl-Pod-Coverage perl-Readonly perl-Test-Differences perl-Test-Exception perl-Test-Fatal perl-Test-NoWarnings perl-Test-Pod perl-Text-CSV perl-Test-Simple perl-YAML
   ```

3) Install packages from CPAN:

   ```sh
   sudo cpanm Module::Install::XSUtil MooseX::Singleton Net::IP::XS
   ```

4) Install Zonemaster::LDNS with support for DNSSEC algorithms 15 and 16:

     ```sh
     sudo cpanm --configure-args="--openssl-lib=/usr/lib64/openssl11 --openssl-inc=/usr/include/openssl11" Zonemaster::LDNS
     ```

5) Finally install Zonemaster::Engine

     ```sh
     sudo cpanm Zonemaster::Engine
     ```


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


[Declaration of prerequisites]:                      https://github.com/zonemaster/zonemaster#prerequisites
[Docker Hub]:                                        https://hub.docker.com/u/zonemaster
[Docker Image Creation]:                             https://github.com/zonemaster/zonemaster/blob/master/docs/internal-documentation/maintenance/ReleaseProcess-create-docker-image.md
[EPEL]:                                              https://fedoraproject.org/wiki/EPEL
[Installation on Debian and Ubuntu]:                 #installation-on-debian-and-ubuntu
[Installation on FreeBSD]:                           #installation-on-freebsd
[Installation on Rocky Linux]:                       #installation-on-rocky-linux
[Installation on CentOS 7]:                          #installation-on-centos-7
[JSON-RPC API]:                                      https://github.com/zonemaster/zonemaster-backend/blob/master/docs/API.md
[Mailing list zonemaster-users]:                     https://github.com/zonemaster/zonemaster/blob/master/docs/contact-and-mailing-lists.md#zonemaster-users
[Main Zonemaster Repository]:                        https://github.com/zonemaster/zonemaster
[USING]:                                             https://github.com/zonemaster/zonemaster-cli/blob/master/USING.md
[Zonemaster::Backend installation]:                  https://github.com/zonemaster/zonemaster-backend/blob/master/docs/Installation.md
[Zonemaster::CLI installation]:                      https://github.com/zonemaster/zonemaster-cli/blob/master/docs/Installation.md
[Zonemaster::Engine API]:                            http://search.cpan.org/~znmstr/Zonemaster-Engine/lib/Zonemaster/Engine/Overview.pod
[Zonemaster::GUI installation]:                      https://github.com/zonemaster/zonemaster-gui/blob/master/docs/Installation.md
