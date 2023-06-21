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

=head1 NAME

json2yaml - Convert a JSON profile into YAML

=head1 SYNOPSIS

    ./json2yaml.pl
    ./json2yaml.pl profile.json

=head1 DESCRIPTION

json2yaml converts a JSON profile into YAML. The JSON profile can be passed as
an argument. If no argument is provided, the script will look for the default
profile. The YAML profile is written to the standard output.

=cut
