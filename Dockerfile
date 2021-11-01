FROM zonemaster/ldns:local as build

RUN apk add --no-cache \
    # Only needed for Readonly::XS
    build-base \
    make \
    perl-dev \
    # Compile-time dependencies
    perl-app-cpanminus \
    perl-clone \
    perl-file-sharedir \
    perl-file-slurp \
    perl-io-socket-inet6 \
    perl-list-moreutils \
    perl-locale-msgfmt \
    perl-lwp-protocol-https \
    perl-module-install \
    perl-moose \
    perl-net-ip \
    perl-pod-coverage \
    perl-test-differences \
    perl-test-exception \
    perl-test-fatal \
    perl-test-pod \
    perl-text-csv \
 && cpanm --no-wget --from=https://cpan.metacpan.org/ \
    Email::Valid \
    Locale::TextDomain \
    JSON::PP \
    Module::Find \
    MooseX::Singleton \
    Readonly::XS

ARG version

COPY ./Zonemaster-Engine-${version}.tar.gz ./Zonemaster-Engine-${version}.tar.gz

RUN cpanm --notest --no-wget \
    ./Zonemaster-Engine-${version}.tar.gz

FROM zonemaster/ldns:local

# Include all the Perl modules we built
COPY --from=build /usr/local/lib/perl5/site_perl /usr/local/lib/perl5/site_perl

RUN apk add --no-cache \
    # All the locales we need and more
    musl-locales \
    # Run-time dependencies
    perl-clone \
    perl-file-sharedir \
    perl-file-slurp \
    perl-io-socket-inet6 \
    perl-list-moreutils \
    perl-locale-msgfmt \
    perl-module-install \
    perl-moose \
    perl-net-ip \
    perl-text-csv
