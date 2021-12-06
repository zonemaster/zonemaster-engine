#!perl
use v5.14.2;
use strict;
use warnings;
use utf8;
use Test::More tests => 2;
use Test::NoWarnings;

use File::Basename qw( dirname );

chdir dirname( dirname( __FILE__ ) ) or BAIL_OUT( "chdir: $!" );

my $makebin = 'make';

sub make {
    my @make_args = @_;

    undef $ENV{MAKEFLAGS};

    my $command = join( ' ', $makebin, '-s', @make_args );
    my $output = `$command 2>&1`;

    if ( $? == -1 ) {
        BAIL_OUT( "failed to execute: $!" );
    }
    elsif ( $? & 127 ) {
        BAIL_OUT( "child died with signal %d, %s coredump\n", ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without' );
    }

    return $output, $? >> 8;
}

subtest "distcheck" => sub {
    my ( $output, $status ) = make "distcheck";
    is $status, 0,  $makebin . ' distcheck exits with value 0';
    is $output, "", $makebin . ' distcheck gives empty output';
};
