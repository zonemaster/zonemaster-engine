#!/usr/bin/env perl

use 5.14.2;
use warnings;
use strict;

use version; our $VERSION = version->declare("v1.0.1");

use Carp;

use English qw( -no_match_vars );

use LWP::Simple;
use File::Find;
use File::chmod;
use File::Copy qw(copy);
use File::Temp qw(tempfile);
use Getopt::Long;
use File::Basename;
use FindBin;

use Text::CSV;

my $DEBUG = 0;
my $DEST_DIR = q{};

my $iana_url = q{http://www.iana.org/assignments/};
my $dest_dir = qq{$FindBin::Bin/../share};
my @files_details = (
    { name => q{iana-ipv4-special-registry.csv}, url => $iana_url.q{/iana-ipv4-special-registry/iana-ipv4-special-registry-1.csv}, ip_version => 4 },
    { name => q{iana-ipv6-special-registry.csv}, url => $iana_url.q{/iana-ipv6-special-registry/iana-ipv6-special-registry-1.csv}, ip_version => 6 },
);

process_options();

if ( $DEST_DIR ) {
    $dest_dir = $DEST_DIR;
}

if ($DEBUG) {
    print "Debug Mode set ON\n";
    print "Destination directory : $dest_dir\n\n";
}

#-------------------------------------------------
# STEP 0: Check Directory existence and Directory/Files permissions
#-------------------------------------------------
if ( ! -d $dest_dir ) {
    print "Directory $dest_dir does not exist.\n";
    unless ( mkdir $dest_dir ) {
        croak "Unable to create $dest_dir.";
    }
}

if ( ! -w $dest_dir ) {
    print "Directory $dest_dir mode must be changed.\n";
    unless ( chmod (oct(755), $dest_dir) ) {
        croak "Cannot change directory mode.";
    }
}

foreach my $file_details ( @files_details ) {
    my $fn = $dest_dir.q{/}.${$file_details}{name};
    if ( -e $fn and ! -w $fn ) {
        print "File $fn mode must be changed.\n";
        unless ( chmod (oct(664), $fn) ) {
            croak "Cannot change file mode.";
        }
    }
}

#-------------------------------------------------
# STEP 1: If they exist, save original files
#-------------------------------------------------
foreach my $file_details ( @files_details ) {
    my $fn = $dest_dir.q{/}.${$file_details}{name};
    if ( -e $fn ) {
        my ($fh, $filename) = tempfile();
        ${$file_details}{backup_filename} = $filename;
        unless ( copy $fn, $filename ) {
            croak "The Copy operation failed: $ERRNO";
        }
    }
}

#-------------------------------------------------
# STEP 2: Retrieve remote files in temporary files
#-------------------------------------------------
foreach my $file_details ( @files_details ) {
    my ($fh, $filename) = tempfile();
    ${$file_details}{new_filename} = $filename;
    my $rc = getstore(${$file_details}{url}, $filename);
}

#-------------------------------------------------
# STEP 3: Check downloaded files integrity
#-------------------------------------------------
foreach my $file_details ( @files_details ) {
    my $fn = ${$file_details}{new_filename};
    my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, sep_char => q{,} }) or croak "Cannot use CSV: ".Text::CSV->error_diag ();
    open my $fh, "<:encoding(utf8)", $fn or croak "$fn: $ERRNO";
    while ( my $row = $csv->getline( $fh ) ) {
    }
    $csv->eof or croak $csv->error_diag();

    close $fh or croak "$fn: $ERRNO";
}

#-------------------------------------------------
# STEP 4: Copy Files on their final destination
#-------------------------------------------------
foreach my $file_details ( @files_details ) {
    my $fn = $dest_dir.q{/}.${$file_details}{name};
    if ( -e ${$file_details}{new_filename} ) {
        unless ( copy ${$file_details}{new_filename}, $fn ) {
            croak "The Copy operation failed: $ERRNO";
        }
    }
}

#-------------------------------------------------
# STEP 5: Delete backup, temporary files
#-------------------------------------------------
clean_temporary_files();

sub clean_temporary_files {
    foreach my $file_details ( @files_details ) {
        if ($DEBUG) {
            print "${$file_details}{name} Details : \n";
            print "Backup file : ${$file_details}{backup_filename}\n";
            print "Downloaded file : ${$file_details}{new_filename}\n\n";
        } else {
            unlink ${$file_details}{backup_filename} or carp "Could not unlink ${$file_details}{backup_filename}: $ERRNO";
            unlink ${$file_details}{new_filename} or carp "Could not unlink ${$file_details}{new_filename}: $ERRNO";
        }
    }
    return;
}

sub process_options {
    my ( $opt_dest, $opt_help, $opt_debug );

    GetOptions(
        q{dest-dir=s} => \$opt_dest,  # Dest directory for downloaded files
        q{help}       => \$opt_help,  # Print Usage
        q{debug}      => \$opt_debug, # Set Debug MODE
    );

    if ( $opt_debug ) {
        $DEBUG = 1;
    }

    if ( $opt_dest ) {
        $DEST_DIR = $opt_dest;
    }

    if ( $opt_help ) {
        Usage();
    }

    return;
}

sub Usage {
    my $_bold           = "\e[1m";
    my $_normal         = "\e[0m";
    my $_ul             = "\e[4m";
    my $scriptName      = basename($PROGRAM_NAME);
    my $scriptNameBlank = $scriptName;
    $scriptNameBlank =~ s/./ /smxg;

    print << "EOM";

${_bold}NAME${_normal}
        ${scriptName} - Download IANA Address Space Registries

${_bold}SYNOPSIS${_normal}
        ${scriptName} [ --help ] [ --dest-dir=${_ul}alternate_destination_directory${_normal} ] [ --debug ]

${_bold}DESCRIPTION${_normal}
        ${scriptName} is a tool to download official IANA Address Space registries.

        Although these files are part of Zonemaster distribution, they are subject to changes and it is important that Zonemaster use last versions in order to give more accurate tests results.

        That script should be called on a regular frequency basis to keep synchronization with IANA registries.

${_bold}OPTIONS${_normal}
        --help
            Print this message and exit.

        --dest-dir
            Name of an alternate directory to save downloaded files.
            ${_bold}DEFAULT${_normal} is $dest_dir.

        --debug
             Set Debug mode ON. Temporary files will not be deleted.

EOM

    exit 0;

}

