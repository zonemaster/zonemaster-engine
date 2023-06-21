FROM zonemaster/ldns:local as build

RUN apk add --no-cache \
    # Only needed for CPAN deps
    gcc \
    make \
    musl-dev \
    perl-dev \
    # Transitive deps included to improve build speed
    perl-mailtools \
    perl-module-build-tiny \
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
    perl-pod-coverage \
    perl-test-differences \
    perl-test-exception \
    perl-test-fatal \
    perl-test-pod \
    perl-text-csv \
 && cpanm --no-wget --from=https://cpan.metacpan.org/ \
    Email::Valid \
    Locale::PO \
    Locale::TextDomain \
    Module::Find \
    MooseX::Singleton \
    Net::IP::XS

ARG version

COPY ./Zonemaster-Engine-${version}.tar.gz ./Zonemaster-Engine-${version}.tar.gz

RUN cpanm --notest --no-wget \
    ./Zonemaster-Engine-${version}.tar.gz

FROM zonemaster/ldns:local

# Include all the Perl modules we built
COPY --from=build /usr/local/lib/perl5/site_perl /usr/local/lib/perl5/site_perl
COPY --from=build /usr/local/share/perl5/site_perl /usr/local/share/perl5/site_perl

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
    perl-mailtools \
    perl-module-install \
    perl-moose \
    perl-net-ip \
    perl-text-csv
