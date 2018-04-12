#!/usr/bin/env perl

use 5.14.2;
use warnings;
use strict;

use Carp;

use English qw( -no_match_vars );

use LWP::Simple;
use File::Find;
use File::chmod;
use File::Copy qw(copy);
use FindBin;

use Text::CSV;

my $iana_url = q{http://www.iana.org/assignments/};
my $dest_dir = qq{$FindBin::Bin/../share};
my @files_details = (
    { name => q{iana-ipv4-special-registry.csv}, url => $iana_url.q{/iana-ipv4-special-registry/iana-ipv4-special-registry-1.csv}, ip_version => 4 },
    { name => q{iana-ipv6-special-registry.csv}, url => $iana_url.q{/iana-ipv6-special-registry/iana-ipv6-special-registry-1.csv}, ip_version => 6 },
);
my $backup_extension = q{.back};
my $new_extension    = q{.new};

#-------------------------------------------------
# STEP 0: Check Directory existence and Directory/Files permissions
#-------------------------------------------------
if ( ! -d $dest_dir ) {
    print "Directory $dest_dir does not exist.\n";
    unless ( mkdir $dest_dir ) {
        croak "Unable to create $dest_dir.";
    }
}
my $dir_mode = sprintf "%04o", (stat($dest_dir))[2] & oct(7777);

if ( $dir_mode ne q{0755} ) {
    print "Directory $dest_dir mode must be changed.\n";
    unless ( chmod (oct(755), $dest_dir) ) {
        croak "Can not change directory mode.";
    }
}

foreach my $file_details ( @files_details ) {
    my $fn = $dest_dir.q{/}.${$file_details}{name};
    if ( ! -w $fn ) {
        print "File $fn mode must be changed.\n";
        unless ( chmod (oct(664), $fn) ) {
            croak "Can not change file mode.";
        }
    }
}

#-------------------------------------------------
# STEP 1: If they exist, save original files
#-------------------------------------------------
foreach my $file_details ( @files_details ) {
    my $fn = $dest_dir.q{/}.${$file_details}{name};
    if ( -e $fn ) {
        unless ( copy $fn, $fn.$backup_extension ) {
            croak "The Copy operation failed: $ERRNO";
        }
    }
}

#-------------------------------------------------
# STEP 2: Retrieve remote files in temporary files
#-------------------------------------------------
foreach my $file_details ( @files_details ) {
    my $rc = getstore(${$file_details}{url}, $dest_dir.q{/}.${$file_details}{name}.$new_extension);
    if ( is_error($rc) ) {
        clean_temporary_files();
        croak "getstore of ${$file_details}{url} failed with $rc";
    }
}

#-------------------------------------------------
# STEP 3: Check downloaded files integrity
#-------------------------------------------------
foreach my $file_details ( @files_details ) {
    my $fn = $dest_dir.q{/}.${$file_details}{name}.$new_extension;
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
    if ( -e $fn.$new_extension ) {
        unless ( copy $fn.$new_extension, $fn ) {
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
        my $fn = $dest_dir.q{/}.${$file_details}{name};
        unlink $fn.$backup_extension or carp "Could not unlink $fn$backup_extension: $ERRNO";
        unlink $fn.$new_extension or carp "Could not unlink $fn$new_extension: $ERRNO";
    }
    return;
}
