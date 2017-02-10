#!/usr/bin/env perl

use 5.14.2;
use warnings;
use strict;

use LWP::Simple;
use FindBin;

my $iana_url = q{http://www.iana.org/assignments/};
my $dest_dir = qq{$FindBin::Bin/../share/};
my @files_details = (
    { name => q{iana-ipv4-special-registry.csv}, url => $iana_url.q{/iana-ipv4-special-registry/iana-ipv4-special-registry-1.csv}, ip_version => 4 },
    { name => q{iana-ipv6-special-registry.csv}, url => $iana_url.q{/iana-ipv6-special-registry/iana-ipv6-special-registry-1.csv}, ip_version => 6 },
);

foreach my $file_details ( @files_details ) {
    getstore(${$file_details}{url}, $dest_dir.${$file_details}{name});
}

