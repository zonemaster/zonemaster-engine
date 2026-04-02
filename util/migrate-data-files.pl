#!/usr/bin/env perl

# This is a temporary script to aid in migrating the legacy cache file format to the new one.
#
# First, generate key map files for all the data files by running the following:
#
#   % for tf in t/*.t; do ZONEMASTER_KEY_MAP_FILE="${tf%.t}.keymap" prove -l $tf; done
#
# You will end up with a lot of *.keymap files in the .t directory.
#
# Then, run this script like so:
#
#  % for df in t/*.data; do perl -Ilib ./util/migrate-data-files.pl $df "${df%.data}.keymap"; done
#
# And you should be all set!

use warnings;
use strict;

use v5.10;

use Zonemaster::Engine::Nameserver;

use CBOR::XS;
use MIME::Base64;

if ( scalar @ARGV != 2 ) {
    say STDERR "Usage: $0 t/to-migrate.data t/to-migrate.keymap";
    exit 1;
}

my ( $datafile, $keymapfile ) = @ARGV;

my %keymap;

open my $KEYMAP, '<', $keymapfile or die "open: $keymapfile: $!";

while ( <$KEYMAP> ) {
    my ( $name, $address, $old_key, $new_b64_key ) = split("\x1E", $_, 4);
    my $new_key = decode_base64( $new_b64_key );
    $keymap{$name}{$address}{$old_key} = $new_key;
}

close $KEYMAP;

say STDERR "Converting $datafile";
Zonemaster::Engine::Nameserver->restore( $datafile );

my %new_cache;

foreach my $name ( keys %Zonemaster::Engine::Nameserver::object_cache ) {
    foreach my $addr ( keys %{$Zonemaster::Engine::Nameserver::object_cache{$name}} ) {
        my $old_cached_data = $Zonemaster::Engine::Nameserver::object_cache{$name}{$addr}->cache->data;
        my @old_keys = keys %$old_cached_data;
        foreach my $source ( @old_keys ) {
            if ( not exists $keymap{$name}{$addr}{$source} ) {
                # warn "Key $name/$addr/$source not found in map file";
                next;
            };
            my $destination = $keymap{$name}{$addr}{$source};
            $new_cache{$name}{$addr}{$destination} = $old_cached_data->{$source};
        }
    }
}

Zonemaster::Engine::Nameserver->empty_cache();

foreach my $name ( keys %new_cache ) {
    foreach my $addr ( keys %{$new_cache{$name}} ) {
        foreach my $key ( keys %{$new_cache{$name}{$addr}} ) {
            my $ns = Zonemaster::Engine::Nameserver->new( { name => $name, address => $addr } );
            $ns->cache->set_key( $key, $new_cache{$name}{$addr}{$key} );
        }
    }
}

Zonemaster::Engine::Nameserver->save_new( $datafile );

exit 0;
