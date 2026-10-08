#!perl
use strict;
use warnings;

use ExtUtils::Manifest qw(maniread);
use Test::More;
use Test::Perl::Critic ( -profile => 't/imports.perlcriticrc' );

my %skip = map { $_ => 1 } qw(
  lib/Zonemaster/Engine/Nameserver.pm
  lib/Zonemaster/Engine/Nameserver/Cache/LocalCache.pm
  lib/Zonemaster/Engine/Nameserver/Cache/RedisCache.pm
  lib/Zonemaster/Engine/Recursor.pm
  lib/Zonemaster/Engine/Test/Address.pm
  lib/Zonemaster/Engine/Test/Basic.pm
  lib/Zonemaster/Engine/Test/Consistency.pm
  lib/Zonemaster/Engine/Test/Connectivity.pm
  lib/Zonemaster/Engine/Test/Delegation.pm
  lib/Zonemaster/Engine/Test/DNSSEC.pm
  lib/Zonemaster/Engine/Test/Nameserver.pm
  lib/Zonemaster/Engine/Test/Syntax.pm
  lib/Zonemaster/Engine/Test/Zone.pm
  lib/Zonemaster/Engine/TestMethodsV2.pm
  lib/Zonemaster/Engine/Util.pm
  lib/Zonemaster/Engine/Zone.pm
  t/TestUtil/DSL.pm
  t/TestUtil/DSL/Compiler.pm
);

my $manifest = maniread();

my @files = grep { m{^(?:lib|t)/.*\.pm$} } sort keys %{$manifest};

plan tests => scalar @files;

for my $file ( @files ) {
  SKIP: {
        skip "$file is temporarily exempt from import checks", 1
          if $skip{$file};

        critic_ok( $file );
    }
}

done_testing;
