FROM zonemaster/ldns:local AS build

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
    perl-class-accessor \
    perl-clone \
    perl-file-sharedir \
    perl-file-slurp \
    perl-io-socket-inet6 \
    perl-list-moreutils \
    perl-locale-msgfmt \
    perl-log-any \
    perl-lwp-protocol-https \
    perl-mail-spf \
    perl-module-install \
    perl-pod-coverage \
    perl-readonly \
    perl-sub-override \
    perl-test-differences \
    perl-test-exception \
    perl-test-fatal \
    perl-test-nowarnings \
    perl-test-pod \
    perl-text-csv \
    perl-yaml \
    perl-yaml-libyaml \
 && cpanm --no-wget --from=https://cpan.metacpan.org/ \
    Email::Valid \
    List::Compare \
    Locale::PO \
    Locale::TextDomain \
    Module::Find \
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
    perl-class-accessor \
    perl-clone \
    perl-file-sharedir \
    perl-file-slurp \
    perl-io-socket-inet6 \
    perl-list-moreutils \
    perl-locale-msgfmt \
    perl-log-any \
    perl-mail-spf \
    perl-mailtools \
    perl-module-install \
    perl-net-ip \
    perl-readonly \
    perl-text-csv \
    perl-try-tiny \
    perl-yaml-libyaml
