#!perl
use 5.012;
use warnings;
use Test::More;

require Test::NoWarnings;
use MIME::Base64 qw( decode_base64 );
use Zonemaster::Engine::Packet;
use Zonemaster::LDNS::Packet;

my $data =
  decode_base64( "O6+EAAABAAIABAAKA2lpcwJzZQAABgABwAwABgABAAAOEAAqAm5zA25pY8AQCmhvc3RtYXN0ZXLADFxa4oUAADhAAA"
      . "AOEAAbr4AAADhAwAwALgABAAAOEACaAAYFAgAADhBcaAN1XFrUdROJA2lpcwJzZQCcmkLyHWp2GzxC8X6jsZ/BvfwS"
      . "seIFRL6uP/Ou8f8hECYFl7jr0++Ndz+IZsIBvBGm/hhwPkNVp63ZbJ5s4+362T2yF3czWgiPFOYeyw2j/OvJmr7UjU"
      . "BNk1qCGQdm1BJ3g1OmIGUaGOHrZ4CWaHSLkdXFxfkKDPX85DC/7izDVMAMAAIAAQAADhAABwFpAm5zwBDADAACAAEA"
      . "AA4QAALAJMAMAAIAAQAADhAABgNuczPAJ8AMAC4AAQAADhAAmgACBQIAAA4QXGgDdVxa1HUTiQNpaXMCc2UAPyX6eL"
      . "1B3MzfulflW7nFJUTA/CZRrfNCnn9ZGDuhw8UuahIDujydknJQ/M2iwx8RRiLjSLNmM1Cd1jBDeyKMl+VtO4ph7Jlv"
      . "PVraxxsLbEWhoQAVT83aWzURLZuf0fWo/ySlYbgIjGQmD+lJvmDwuONTipBaIWW8IqEjUDNmk1DAJAABAAEAAA4QAA"
      . "Rb4iQtwCQAHAABAAAOEAAQIAEGfBJMEAoAAAAAAAAARcEhAAEAAQAADhAABFviJS3BIQAcAAEAAA4QABAgAQZ8Ekwg"
      . "BwAAAAAAAABFwCQALgABAAAOEACaAAEFAwAADhBcZ+wFXFq9BfiaA25pYwJzZQCWZl5yovo39I0gnKNvFE2W0IEjrM"
      . "PHPflaLi+NIbF8Wwy+BB+BDHLgeBbYcJczPmClR+T/1O5UCsBooR2ZOtIqOwVo9OWlPlfT16N5hEl/wSjfrfbjhFOe"
      . "sJJbP1o3rtIS372Cogk4yo9qV63FAaU2zoLopRCwMnD0w9fSUoakFcAkAC4AAQAADhAAmgAcBQMAAA4QXGfsBVxavQ"
      . "X4mgNuaWMCc2UAYjWjF8tlJtPMKG3fTwBarN7ciDTWbXICrqvO0GPY6nGwOMsz/1sCOb6CqMGXTLr0sTbWv/g9uadA"
      . "K6GmRZYk3GFjb3tUsueSMOaSbgR0wztlQA/QMfDW9mjDuOjpIP6XjEwbOdboqOzD3yDQRppBPxMCZnDhlvvADxgcHJ"
      . "6SSx/BIQAuAAEAAA4QAJoAAQUDAAAOEFxn7AVcWr0F+JoDbmljAnNlAHA0bnk6ldDN25n3g5FyI67KonWxUQ9TThor"
      . "MMFHEkBf+Bi1qcrlyJFtXDsECVvUOEM/mFVPcmTu3kobtgbMz+v8rTVUAp+ZWp9oRbt7Uf9lH2wG5/6raKdR0kyva/"
      . "U+n401vogviERiohHMtVNPuWCeywNabK7v0ptfWZwKyiugwSEALgABAAAOEACaABwFAwAADhBcZ+wFXFq9BfiaA25p"
      . "YwJzZQCcI0wW/sgx9HP1pCwAiIRnjEC9RXW44a48n25487IzvEea79AmSq6QbkRQpB76xJBfrQlVaXUzWTujolHG5X"
      . "96zvU3oyiPe5UwIyMV5eci/C3mbn5O73bWZAAsDpcqj9kllfmmNb1AZRPuxTmDU7STg8UdsTQ4fnUlarO7joPR0QN3"
      . "d3fADAABAAEAAAAaAARb4iQuAAApEAAAAIAAAAA=" );
my $inner = Zonemaster::LDNS::Packet->new_from_wireformat( $data );
$inner->timestamp( 1234567890.12345 );
$inner->answerfrom( "192.0.2.1" );
$inner->querytime( 42 );
$inner->id( 15279 );
$inner->opcode( 'QUERY' );

my $packet = Zonemaster::Engine::Packet->new( { packet => $inner } );

is( $packet->data(), $inner->data(), 'data() returns value from inner' );

is( $packet->edns_data(), $inner->edns_data(), 'edns_data() returns value from inner' );

is( $packet->edns_z(), $inner->edns_z(), 'edns_z() returns value from inner' );

is( $packet->id(), $inner->id(), 'id() returns value from inner' );

$packet->id( 43210 );
is( $inner->id(), 43210, 'id() updates value in inner' );

is( $packet->opcode(), $inner->opcode(), 'opcode() returns value from inner' );

$packet->opcode( 'STATUS' );
is( $inner->opcode(), 'STATUS', 'opcode() updates value in inner' );

is( $packet->querytime(), 42, 'querytime() returns value from inner' );

$packet->querytime( 24 );
is( $inner->querytime(), 24, 'querytime() updates value in inner' );

Test::NoWarnings::had_no_warnings();
done_testing;
