#!/usr/bin/env perl

use 5.14.2;
use warnings;

use JSON::PP;

my $json = JSON::PP->new->canonical->pretty->utf8;

say $json->encode($json->decode(join('',<>)));
