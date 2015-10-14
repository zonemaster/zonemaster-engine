# Zonemaster Engine installation guide

This is the installation instructions for the Zonemaster Engine testing
module. For an overview of the Zonemaster components, please see the
[Zonemaster repository](https://github.com/dotse/zonemaster).

The documentation covers the following operating systems:

 * [Ubuntu 12.04 (LTS))][1]
 * (# Ubuntu 14.04 (LTS))
 * (# Debian Wheezy (version 7))
 * [2] (# FreeBSD 10.1)
 * [3] (# CentOS 7)

The Engine Perl module name is 'Zonemaster'.


### [1]: Instructions for Debian 7, Ubuntu 14.04 and Ubuntu 12.04

1) Make sure the package database is up to date.

`sudo apt-get update`

2) Install all necessary packages.

`sudo apt-get install build-essential libfile-slurp-perl libjson-perl liblist-moreutils-perl libio-socket-inet6-perl libmodule-find-perl libmoose-perl libfile-sharedir-perl libhash-merge-perl libreadonly-perl libmail-rfc822-address-perl libintl-xs-perl libssl-dev libdevel-checklib-perl libtest-fatal-perl libtie-simple-perl libio-capture-perl libgeography-countries-perl libidn11-dev`

3) Install non-packaged software.

`sudo cpan -i Zonemaster`

If necessary, answer any questions from the cpan script by accepting the default value (just press enter).


### 2 Instructions for FreeBSD 10.1

1) Become root.

`su`

2) Install all necessary packages

`pkg install libidn p5-Devel-CheckLib p5-MIME-Base64 p5-Test-Fatal p5-JSON-PP p5-IO-Socket-INET6 p5-Moose p5-Module-Find p5-JSON p5-File-ShareDir p5-File-Slurp p5-Mail-RFC822-Address p5-Hash-Merge p5-Time-HiRes p5-Locale-libintl p5-JSON-XS p5-Readonly-XS p5-Tie-Simple p5-Math-BigInt p5-IP-Country p5-IO-Capture`

3) Install non-packaged-software.

`cpan -i Zonemaster`

If necessary, answer any questions from the cpan script by accepting the default value (just press enter).


## 3 Instructions for CentOS 7

1) Make sure the development environment is installed.

`sudo yum groupinstall "Development Tools"`

2) Install packages.

`sudo yum install perl-core perl-ExtUtils-MakeMaker perl-File-ShareDir perl-File-Slurp perl-IO-Socket-INET6 perl-JSON perl-List-MoreUtils perl-Readonly perl-Time-HiRes perl-YAML libidn-devel perl-libintl perl-Devel-CheckLib openssl-devel perl-Test-Fatal`

3) Install CPAN modules.

If it's the first time you use the CPAN module, it will ask three questions.
For the first and third, the default responses are fine. For the second, answer
"sudo" (the default is "local::lib", which you do not want).

`sudo cpan -i Zonemaster`


-------

Copyright (c) 2013, 2014, 2015, IIS (The Internet Infrastructure Foundation)  
Copyright (c) 2013, 2014, 2015, AFNIC  
Creative Commons Attribution 4.0 International License

You should have received a copy of the license along with this
work.  If not, see <http://creativecommons.org/licenses/by/4.0/>.
