package Zonemaster::Engine;

use v5.16.0;
use warnings;

use version; our $VERSION = version->declare("v7.0.0");

BEGIN {
    # Locale::TextDomain (<= 1.20) doesn't know about File::ShareDir so give a helping hand.
    # This is a hugely simplified version of the reference implementation located here:
    # https://metacpan.org/source/GUIDO/libintl-perl-1.21/lib/Locale/TextDomain.pm
    require File::ShareDir;
    require Locale::TextDomain;
    my $share = File::ShareDir::dist_dir( 'Zonemaster-Engine' );
    Locale::TextDomain->import( 'Zonemaster-Engine', "$share/locale" );
}

use Class::Accessor "antlers";
use Carp;

use Zonemaster::Engine::Nameserver;
use Zonemaster::Engine::Logger;
use Zonemaster::Engine::Profile;
use Zonemaster::Engine::Zone;
use Zonemaster::Engine::Test;
use Zonemaster::Engine::Recursor;
use Zonemaster::Engine::ASNLookup;

INIT {
    init_engine();
}

our $logger;
our $recursor = Zonemaster::Engine::Recursor->new;

my $init_done = 0;

sub init_engine {
    return if $init_done++;
    Zonemaster::Engine::Recursor::init_recursor();
}

sub logger {
    return $logger //= Zonemaster::Engine::Logger->new;
}

sub profile {
    return Zonemaster::Engine::Profile->effective;
}

sub ns {
    my ( $class, $name, $address ) = @_;

    return Zonemaster::Engine::Nameserver->new( { name => $name, address => $address } );
}

sub zone {
    my ( $class, $name ) = @_;

    return Zonemaster::Engine::Zone->new( { name => Zonemaster::Engine::DNSName->new( $name ) } );
}

sub test_zone {
    my ( $class, $zname ) = @_;

    return Zonemaster::Engine::Test->run_all_for( $class->zone( $zname ) );
}

sub test_module {
    my ( $class, $module, $zname ) = @_;

    return Zonemaster::Engine::Test->run_module( $module, $class->zone( $zname ) );
}

sub test_method {
    my ( $class, $module, $method, $zname ) = @_;

    return Zonemaster::Engine::Test->run_one( $module, $method, $class->zone( $zname ) );
}

sub all_tags {
    my ( $class ) = @_;
    my @res;

    foreach my $module ( sort { $a cmp $b } Zonemaster::Engine::Test->modules ) {
        my $full = "Zonemaster::Engine::Test::$module";
        my $ref  = $full->metadata;
        foreach my $list ( values %{$ref} ) {
            push @res, map { uc( $module ) . q{:} . $_ } sort { $a cmp $b } @{$list};
        }
    }

    return @res;
}

sub all_methods {
    my ( $class ) = @_;
    my %res;

    foreach my $module ( Zonemaster::Engine::Test->modules ) {
        my $full = "Zonemaster::Engine::Test::$module";
        my $ref  = $full->metadata;
        foreach my $method ( sort { $a cmp $b } keys %{$ref} ) {
            push @{ $res{$module} }, $method;
        }
    }

    return %res;
}

sub recurse {
    my ( $class, $qname, $qtype, $qclass ) = @_;
    $qtype  //= 'A';
    $qclass //= 'IN';

    return $recursor->recurse( $qname, $qtype, $qclass );
}

sub add_fake_delegation {
    my ( $class, $domain, $href, %flags ) = @_;
    my $fill_in_empty_oob_glue = exists $flags{fill_in_empty_oob_glue} ? delete $flags{fill_in_empty_oob_glue} : 1;
    croak 'Unrecognized flags: ' . join( ', ', keys %flags )
      if %flags;
    undef %flags;

    # Validate arguments
    $domain =~ /[^.]$|^\.$/
      or croak 'Argument $domain must omit the trailing dot, or it must be a single dot';
    foreach my $name ( keys %{$href} ) {
        $name =~ /[^.]$|^\.$/
          or croak 'Each key of argument $href must omit the trailing dot, or it must be a single dot';
        ( !defined $href->{$name} or ref $href->{$name} eq 'ARRAY' )
          or croak 'Each value of argument $href must be an arrayref or undef';
        $href->{$name} //= []; # normalize undef to empty arrayref
    }

    # Check fake delegation
    my $incomplete_delegation;
    if ( $fill_in_empty_oob_glue ) {
        foreach my $name ( keys %{$href} ) {
            if (   !@{ $href->{$name} }
                && !$class->zone( $domain )->is_in_zone( $name ) )
            {
                my @ips = map { $_->ip } Zonemaster::Engine::Recursor->get_addresses_for( $name );
                push @{ $href->{$name} }, @ips;
                if ( !@ips ) {
                    $incomplete_delegation = 1;
                }
            }
        }
    }
    foreach my $name ( keys %{$href} ) {
        if ( not @{ $href->{$name} } ) {
            if ( $class->zone( $domain )->is_in_zone( $name ) ) {
                Zonemaster::Engine->logger->add(    #
                    FAKE_DELEGATION_IN_ZONE_NO_IP => { domain => $domain, nsname => $name }
                );
            }
            else {
                Zonemaster::Engine->logger->add(    #
                    FAKE_DELEGATION_NO_IP => { domain => $domain, nsname => $name }
                );
            }
        }
    }

    $recursor->add_fake_addresses( $domain, $href );
    my $parent = $class->zone( $recursor->parent( $domain ) );
    foreach my $ns ( @{ $parent->ns } ) {
        $ns->add_fake_delegation( $domain => $href );
    }

    if ( $incomplete_delegation ) {
        return;
    }
    return 1;
}

sub add_fake_ds {
    my ( $class, $domain, $aref ) = @_;

    my $parent = $class->zone( scalar( $recursor->parent( $domain ) ) );
    if ( not $parent ) {
        die "Failed to find parent for $domain";
    }

    foreach my $ns ( @{ $parent->ns } ) {
        $ns->add_fake_ds( $domain => $aref );
    }

    return;
}

sub can_continue {
    my ( $class ) = @_;

    return 1;

}

sub save_cache {
    my ( $class, $filename ) = @_;

    return Zonemaster::Engine::Nameserver->save( $filename );
}

sub preload_cache {
    my ( $class, $filename ) = @_;

    return Zonemaster::Engine::Nameserver->restore( $filename );
}

sub asn_lookup {
    my ( undef, $ip ) = @_;

    return Zonemaster::Engine::ASNLookup->get( $ip );
}

sub modules {
    return Zonemaster::Engine::Test->modules;
}

sub start_time_now {
    Zonemaster::Engine::Logger->start_time_now();
    return;
}

sub reset {
    Zonemaster::Engine::Logger->start_time_now();
    Zonemaster::Engine::Logger->reset_config();
    Zonemaster::Engine::Nameserver->empty_cache();
    $logger->clear_history() if $logger;
    Zonemaster::Engine::Recursor->clear_cache();
    Zonemaster::Engine::TestMethodsV2->clear_cache();
    return;
}

=head1 NAME

Zonemaster::Engine - A tool to check the quality of a DNS zone

=head1 SYNOPSIS

    my @results = Zonemaster::Engine->test_zone('iis.se')

=head1 INTRODUCTION

This manual describes the main L<Zonemaster::Engine> module. If what you're after is documentation on the Zonemaster test engine as a whole, see L<Zonemaster::Engine::Overview>.

=head1 METHODS

=over

=item init_engine()

Run the initialization tasks if they have not been run already. This method is called automatically in INIT block.

=item test_zone($name)

Runs all available tests and returns a list of L<Zonemaster::Engine::Logger::Entry> objects.

=item test_module($module, $name)

Runs all available tests for the zone with the given name in the specified module.

=item test_method($module, $method, $name)

Run one particular test method in one particular module for one particular zone.
The requested module must be in the list of currently enabled modules (that is,
not a module disabled by the current profile), and the method must be listed in
the metadata of the module exports.
If those requirements are fulfilled, the method will be called with the provided
arguments.

=item zone($name)

Returns a L<Zonemaster::Engine::Zone> object for the given name.

=item ns($name, $address)

Returns a L<Zonemaster::Engine::Nameserver> object for the given name and address.

=item profile()

Returns the effective profile (L<Zonemaster::Engine::Profile> object).

=item logger()

Returns the global L<Zonemaster::Engine::Logger> object.

=item all_tags()

Returns a list of all the tags that can be logged for all available test modules.

=item all_methods()

Returns a hash, where the keys are test module names and the values are lists with the names of the test methods in that module.

=item recurse($name, $type, $class)

Does a recursive lookup for the given name, type and class, and returns the resulting packet (if any). Simply calls
L<Zonemaster::Engine::Recursor/recurse> on a globally stored object.

=item can_continue()

In case of critical condition that prevents tool to process tests, add test here and return False.

=item save_cache($filename)

After running the tests, save the accumulated cache to a file with the given name.

=item preload_cache($filename)

Before running the tests, load the cache with information from a file with the given name. This file must have the same format as is produced by
L</save_cache()>.

=item asn_lookup($ip)

Takes a single IP address (string or L<Net::IP::XS> object) and returns a list of AS numbers, if any.

=item modules()

Returns a list of the loaded test modules. Exactly the same as L<Zonemaster::Engine::Test/modules>.

=item add_fake_delegation($domain, $data, %flags)

This method adds some fake delegation information to the system.

The arguments are a domain name, and a hashref with delegation information.
The keys in the hash are nameserver names, and the values are arrayrefs of IP
addresses for their corresponding nameserver.
Alternatively the IP addresses may be specified as an `undef` which is handled
the same as an empty arrayref.

For each provided nameserver with an empty list of addresses, either a
C<FAKE_DELEGATION_NO_IP> or a C<FAKE_DELEGATION_IN_ZONE_NO_IP> message is
emitted.

The only recognized flag is C<fill_in_empty_oob_glue>.
This flag is boolean and defaults to true.
If this flag is true, this method updates the given C<$data> by looking up and
filling in some glue addresses.
Specifically the glue addresses for any nameserver name that are
out-of-bailiwick of the given C<$domain> and that comes with an empty list of
addresses.

Returns `1` if all name servers in C<$data> have non-empty lists of
glue (after they've been filled in) or if `fill_in_empty_oob_glue` is false.
Otherwise it returns `undef`.

Examples:

    Zonemaster::Engine->add_fake_delegation(
        'lysator.liu.se' => {
            'ns1.nic.fr' => [ ],
            'ns.nic.se'  => [ '212.247.7.228',  '2a00:801:f0:53::53' ],
            'i.ns.se'    => [ '194.146.106.22', '2001:67c:1010:5::53' ],
            'ns3.nic.se' => [ '212.247.8.152',  '2a00:801:f0:211::152' ]
        },
    );

returns 1.

    Zonemaster::Engine->add_fake_delegation(
        'lysator.liu.se' => {
            'ns1.lysator.liu.se' => [ ],
            'ns.nic.se'  => [ '212.247.7.228',  '2a00:801:f0:53::53' ],
            'i.ns.se'    => [ '194.146.106.22', '2001:67c:1010:5::53' ],
            'ns3.nic.se' => [ '212.247.8.152',  '2a00:801:f0:211::152' ]
        }
    );

returns C<undef> (signalling that fake delegation with empty glue was added to
the system).

    Zonemaster::Engine->add_fake_delegation(
        'lysator.liu.se' => {
            'ns1.nic.fr' => [ ],
            'ns.nic.se'  => [ '212.247.7.228',  '2a00:801:f0:53::53' ],
            'i.ns.se'    => [ '194.146.106.22', '2001:67c:1010:5::53' ],
            'ns3.nic.se' => [ '212.247.8.152',  '2a00:801:f0:211::152' ]
        },
        fill_in_empty_oob_glue => 0,
    );

returns 1. It does not even attempt to fill in glue for ns1.nic.fr.

=item add_fake_ds($domain, $data)

This method adds fake DS records to the system. The arguments are a domain
name, and a reference to a list of references to hashes. The hashes in turn
must have the keys C<keytag>, C<algorithm>, C<type> and C<digest>, with the
values holding the corresponding data. The digest data should be a single
unbroken string of hexadecimal digits.

Example:

   Zonemaster::Engine->add_fake_ds(
      'nic.se' => [
         { keytag => 16696, algorithm => 5, type => 2, digest => '40079DDF8D09E7F10BB248A69B6630478A28EF969DDE399F95BC3B39F8CBACD7' },
         { keytag => 16696, algorithm => 5, type => 1, digest => 'EF5D421412A5EAF1230071AFFD4F585E3B2B1A60' },
      ]
   );

=item start_time_now()

Set the logger's start time to the current time.

=item reset()

Reset logger start time to current time, empty the list of log messages, clear
nameserver object cache, clear recursor cache and clear all cached results of
MethodsV2.

=back

=head1 AUTHORS

Vincent Levigneron <vincent.levigneron at nic.fr>
- Current maintainer

Calle Dybedahl <calle at init.se>
- Original author

=head1 LICENSE

This is free software under a 2-clause BSD license. The full text of the license can
be found in the F<LICENSE> file included with this distribution.

=cut

1;
