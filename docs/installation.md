# Zonemaster Engine installation guide

This is the installation instructions for the Zonemaster Engine perl
module. For an overview of the Zonemaster components, please see the
[Zonemaster repository](https://github.com/dotse/zonemaster).

>
> The Engine Perl module name is 'Zonemaster::Engine'.
>


This section covers the following operating systems:

 * [2] <a href="#Debian">Ubuntu 14.04 (LTS))</a>
 * [3] <a href="#Debian">Debian Jessie (version 8) - 64 bits</a>
 * [4] <a href="#FreeBSD">FreeBSD 10.1</a>
 * [5] <a href="#CentOS">CentOS 7 - 64 bits</a>

>
> Note: We assume the installation instructions will work for earlier OS
> versions too. If you have any issue in installing the Zonemaster engine with
> earlier versions, please send a mail with details to contact@zonemaster.net
>

To install the engine, one installs the dependecies for the chosen OS and then
finally install the engine itself. 

## <a name="Debian"></a> Debian & Ubuntu

1) Make sure the package database is up to date.

```sh
sudo apt-get update
```

2) Install all necessary packages.

```sh
sudo apt-get install build-essential libfile-slurp-perl libjson-pp-perl liblist-moreutils-perl libio-socket-inet6-perl libmodule-find-perl libmoose-perl libfile-sharedir-perl libhash-merge-perl libreadonly-perl libmail-rfc822-address-perl libintl-xs-perl libssl-dev libdevel-checklib-perl libtest-fatal-perl libtie-simple-perl libio-capture-perl libgeography-countries-perl libidn11-dev gettext
```

3) Install the Zonemaster engine

```sh
sudo cpan -i Zonemaster::Engine
```

If necessary, answer any questions from the cpan script by accepting the default
value (just press enter).

## <a name="FreeBSD"></a> FreeBSD 

1) Become root.

```sh
su
```

2) Install all necessary packages

```sh
pkg install libidn p5-Devel-CheckLib p5-MIME-Base64 p5-Test-Fatal p5-JSON-PP p5-IO-Socket-INET6 p5-Moose p5-Module-Find p5-File-ShareDir p5-File-Slurp p5-Mail-RFC822-Address p5-Hash-Merge p5-Time-HiRes p5-Locale-libintl p5-Readonly-XS p5-Tie-Simple p5-Math-BigInt p5-IP-Country p5-IO-Capture p5-List-MoreUtils
```

3) Install the CPAN modules

```sh
cpan -i Net::IP Net::LDNS
```

4) Install the Zonemaster engine

```sh
cpan -i Zonemaster::Engine
```

If necessary, answer any questions from the cpan script by accepting the default
value (just press enter).

### <a name="CentOS"></a> CentOS 

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
sudo cpan -i Hash::Merge Net::IP::XS Net::LDNS Moose
```

4) Install the Zonemaster Engine

```sh
sudo cpan -i Zonemaster::Engine
```

If necessary, answer any questions from the cpan script by accepting the default value (just press enter).


## Post-installation sanity check

Make sure Zonemaster Engine was properly installed.

```sh
time perl -MZonemaster::Engine -e 'print scalar Zonemaster::Engine->test_zone("zonemaster.net"), "\n"'
```

The command is expected to take very roughly 15 seconds and print a number
greater than one.

## What to do next

To use the engine from the command line, you will have to install the
*[CLI](https://github.com/dotse/zonemaster-cli/blob/master/docs/installation.md)*. 
To use the engine from a web interface, you will have to install the
*[Backend](https://github.com/dotse/zonemaster-backend/blob/master/docs/installation.md)* and
the
*[GUI](https://github.com/dotse/zonemaster-gui/blob/master/docs/installation.md)*. 
To use the engine from the
*[API](https://github.com/dotse/zonemaster-backend/blob/master/docs/API.md)*, you will have to install the *Backend*.

-------

Copyright (c) 2013 - 2016, IIS ((The Internet Foundation in Sweden))  
Copyright (c) 2013 - 2016, AFNIC  
Creative Commons Attribution 4.0 International License

You should have received a copy of the license along with this
work.  If not, see <http://creativecommons.org/licenses/by/4.0/>.
