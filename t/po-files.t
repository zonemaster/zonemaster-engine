#!perl
use v5.14.2;
use strict;
use warnings;
use utf8;
use Test::More tests => 1;

use File::Basename qw( dirname );

chdir dirname( dirname( __FILE__ ) ) or BAIL_OUT( "chdir: $!" );
chdir 'share' or BAIL_OUT( "chdir: $!" );

my $makebin = 'make';

sub make {
    my @make_args = @_;

    undef $ENV{MAKEFLAGS};

    my $command = join( ' ', $makebin, '--silent', '--no-print-directory', @make_args );
    my $output = `$command`;

    if ( $? == -1 ) {
        BAIL_OUT( "failed to execute: $!" );
    }
    elsif ( $? & 127 ) {
        BAIL_OUT( "child died with signal %d, %s coredump\n", ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without' );
    }

    return $output, $? >> 8;
}

subtest "no fuzzy marks" => sub {
    my ( $output, $status ) = make "show-fuzzy";
    is $status, 0,  $makebin . ' show-fuzzy exits with value 0';
    is $output, "", $makebin . ' show-fuzzy gives empty output';
};
