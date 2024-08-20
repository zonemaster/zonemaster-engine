#!/usr/bin/env perl

use 5.14.2;
use warnings;
use strict;

use version; our $VERSION = version->declare("v1.0.1");

use Carp;

use English qw( -no_match_vars );

use Zonemaster::Engine::Profile;
use JSON::XS;
use Scalar::Util qw( reftype );
use File::Slurp;
use Getopt::Long;
use File::Basename;
use Clone qw(clone);

my $DEBUG = 0;
my $DEST_DIR = q{};
my $CONFIG_FILE = q{};
my $POLICY_FILE = q{};

my $scriptName = basename($PROGRAM_NAME);
my $dest_dir = q{./};
my $config_file = q{};
my $policy_file = q{};

process_options();

if ( $DEST_DIR ) {
    $dest_dir = $DEST_DIR;
}

if ( $CONFIG_FILE ) {
    $config_file = $CONFIG_FILE;
}

if ( $POLICY_FILE ) {
    $policy_file = $POLICY_FILE;
}

if ($DEBUG) {
    print "Debug Mode set ON\n";
    print "Destination directory : $dest_dir\n\n";
}

#-------------------------------------------------
# STEP 0: Check Directory existence and Directory/Files permissions
#-------------------------------------------------
if ( ! -d $dest_dir ) {
    printf "(\"%s --help\" for help)\n", $scriptName;
    print "Directory $dest_dir does not exist.\n";
    unless ( mkdir $dest_dir ) {
        croak "Unable to create $dest_dir.";
    }
}

if ( ! -w $dest_dir ) {
    printf "(\"%s --help\" for help)\n", $scriptName;
    print "Directory $dest_dir mode must be changed.\n";
    unless ( chmod (oct(755), $dest_dir) ) {
        croak "Cannot change directory mode.";
    }
}

if ( ! $config_file ) {
    printf "(\"%s --help\" for help)\n", $scriptName;
    croak "A Config file must be provided.";
}

if ( ! -e $config_file ) {
    printf "(\"%s --help\" for help)\n", $scriptName;
    croak "Config file $config_file does not exists.";
}

if ( ! -r $config_file ) {
    printf "(\"%s --help\" for help)\n", $scriptName;
    croak "Config file $config_file is not readable.";
}

if ( ! $policy_file ) {
    printf "(\"%s --help\" for help)\n", $scriptName;
    croak "A Policy file must be provided.";
}

if ( ! -e $policy_file ) {
    printf "(\"%s --help\" for help)\n", $scriptName;
    croak "Policy file $policy_file does not exists.";
}

if ( ! -r $policy_file ) {
    printf "(\"%s --help\" for help)\n", $scriptName;
    croak "Policy file $policy_file is not readable.";
}

my $policy_json         = read_file( $policy_file ) ;
my $policy              = decode_json( $policy_json );
my $config_json         = read_file( $config_file );
my $config              = decode_json( $config_json );

my $default = Zonemaster::Engine::Profile->default;
my $profile = Zonemaster::Engine::Profile->new;

my %paths;
my %default_paths;
Zonemaster::Engine::Profile::_get_profile_paths(\%paths, $config);
Zonemaster::Engine::Profile::_get_profile_paths(\%default_paths, $default->{q{profile}});
delete $default_paths{ q{test_cases} };
delete $default_paths{ q{test_levels} };

#
# General options part
#

foreach my $property_name ( keys %default_paths ) {
    my $value = Zonemaster::Engine::Profile::_get_value_from_nested_hash( $config, split /\./, $property_name );
    if ( defined $value ) {
        $profile->set( $property_name, $value );
    }
}

#
# Test cases part
#

my @tc;
foreach my $tc ( @{ $default->get( q{test_cases} ) } ) {
    if ( not defined $policy->{__testcases__}->{$tc} or $policy->{__testcases__}->{$tc} ) {
        push @tc, $tc;
    }
}
$profile->set( q{test_cases}, \@tc );

#
# Test levels part
#

my %tl;
foreach my $tl ( keys %{ $default->get( q{test_levels} ) } ) {
    if ( exists $policy->{$tl} ) {
        $tl{$tl} = clone $policy->{$tl};
    }
}
$profile->set( q{test_levels}, \%tl );

my $filename = $dest_dir.q{/profile.json};
open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
my $json = JSON::XS->new->canonical->pretty;
print $fh $json->encode( $profile->{q{profile}} );
close $fh;

sub process_options {
    my ( $opt_dest, $opt_config, $opt_policy, $opt_help, $opt_debug, $opt_version );

    GetOptions(
        q{dest-dir=s} => \$opt_dest,    # Dest directory for generated profile file
	q{config=s}   => \$opt_config,  # Config File
	q{policy=s}   => \$opt_policy,  # Policy file
        q{help}       => \$opt_help,    # Print Usage
        q{debug}      => \$opt_debug,   # Set Debug MODE
        q{version}    => \$opt_version, # Print Version
    );

    if ( $opt_debug ) {
        $DEBUG = 1;
    }

    if ( $opt_dest ) {
        $DEST_DIR = $opt_dest;
    }

    if ( $opt_config ) {
        $CONFIG_FILE = $opt_config;
    }

    if ( $opt_policy ) {
        $POLICY_FILE = $opt_policy;
    }

    if ( $opt_help ) {
        Usage();
    }

    if ( $opt_version ) {
        Version();
    }

    return;
}

sub Usage {
    my $_bold           = "\e[1m";
    my $_normal         = "\e[0m";
    my $_ul             = "\e[4m";
    my $scriptNameBlank = $scriptName;
    $scriptNameBlank =~ s/./ /smxg;

    print << "EOM";

${_bold}NAME${_normal}
        ${scriptName} - Convert Config/Policy files into Profile file.

${_bold}SYNOPSIS${_normal}
        ${scriptName}  [ --help ] [ --dest-dir=${_ul}alternate_destination_directory${_normal} ] [ --config=${_ul}config_file${_normal} ] [ --policy=${_ul}policy_file${_normal} ] [ --debug ]


${_bold}OPTIONS${_normal}
        --help
            Print this message and exit.

        --config
            Name of the Config file to convert.

        --policy
            Name of the Policy file to convert.

        --dest-dir
            Name of an alternate directory to save generated profile file.
            ${_bold}DEFAULT${_normal} is $dest_dir.

        --debug
             Set Debug mode ON.

        --version
             Print version of this program.

EOM

    exit 0;

}

sub Version {
    printf "%s %s\n", $scriptName, $VERSION;
    exit 0;
}

