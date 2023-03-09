#!/usr/bin/env perl

use 5.014002;
use strict;
use warnings;

use File::ShareDir qw[dist_file];
use File::Slurp;

use Zonemaster::Engine::Profile;

my $json_file = @ARGV ? $ARGV[0] : dist_file( 'Zonemaster-Engine', 'profile.json');
my $json = read_file( $json_file );
my $profile = Zonemaster::Engine::Profile->from_json( $json );
my $yaml = $profile->to_yaml();
say $yaml;
