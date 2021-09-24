# Zonemaster Engine
[![Build Status](https://travis-ci.org/zonemaster/zonemaster-engine.svg?branch=master)](https://travis-ci.org/zonemaster/zonemaster-engine)
[![CPAN version](https://badge.fury.io/pl/Zonemaster-Engine.svg)](https://badge.fury.io/pl/Zonemaster-Engine)

## Purpose

This repository holds one of the components of the Zonemaster product. For an
overview of the Zonemaster software, please see the
[Zonemaster main repository](https://github.com/zonemaster/zonemaster).

This Git repository contains the *Zonemaster Engine testing framework*,
and contains all code needed to perform the full suite of Zonemaster
tests.

## Prerequisites

For supported processor architectures, operating systems and Perl versions see 
[Zonemaster/README.md](https://github.com/zonemaster/zonemaster/blob/master/README.md).

## Installation

Installation instructions for the Engine is provided in the
[installation](docs/Installation.md) document.

## Configuration 

This repository does not need any specific configuration.

## Docker

To build a local base image for Zonemaster Engine you need a [local Zonemaster
LDNS base image].

Build a new local base image:

```sh
make docker-build
```

Tag the local base image with the current version number:

```sh
make docker-tag-version
```

Tag the local base image as the latest version:

```sh
make docker-tag-version
```

## Documentation

There is full POD coverage of the Perl code. The documentation can be
read on the [CPAN site](https://metacpan.org/pod/Zonemaster::Engine).

For a curious user, there are documentations regarding translating the output to
a new language, implementing a new test and the log entries under the directory
[docs](docs/). 

## Participation, Contact and Bug reporting

For participation, contact and bug reporting, please see
[Zonemaster/README.md](https://github.com/zonemaster/zonemaster/blob/master/README.md).


## License

The software is released under the 2-clause BSD license. See separate LICENSE file.



[Local Zonemaster LDNS base image]: https://github.com/zonemaster/zonemaster-ldns/blob/master/README.md#docker
