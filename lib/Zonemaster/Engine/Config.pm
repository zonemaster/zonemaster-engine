package Zonemaster::Engine::Config;

use version; our $VERSION = version->declare("v1.0.6");

use 5.014002;
use warnings;

use Moose;
use JSON::PP;
use File::ShareDir qw[dist_dir dist_file];
use File::Slurp;
use Hash::Merge;
use File::Spec;

use Zonemaster::Engine;

has 'cfiles'    => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );
has 'pfiles'    => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );
has 'testcases' => ( is => 'ro', isa => 'HashRef',  default => sub { {} } );

my $merger = Hash::Merge->new;
$merger->specify_behavior(
    {
        'SCALAR' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ $_[0], @{ $_[1] } ] },
            'HASH'   => sub { $_[1] },
        },
        'ARRAY' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ @{ $_[1] } ] },
            'HASH'   => sub { $_[1] },
        },
        'HASH' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ values %{ $_[0] }, @{ $_[1] } ] },
            'HASH'   => sub { Hash::Merge::_merge_hashes( $_[0], $_[1] ) },
        },
    }
);

our $config;
_load_base_config();

our $policy = {};

sub BUILD {
    my ( $self ) = @_;

    foreach my $dir ( _config_directory_list() ) {
        my $cfile = File::Spec->catfile( $dir, 'config.json' );
        my $new = eval { decode_json scalar read_file $cfile };
        if ( $new ) {
            $config = $merger->merge( $config, $new );
            push @{ $self->cfiles }, $cfile;
        }

        my $pfile = File::Spec->catfile( $dir, 'policy.json' );
        $new = eval { decode_json scalar read_file $pfile };
        if ( $new ) {
            my $tc = $new->{__testcases__};
            delete $new->{__testcases__};
            foreach my $case ( keys %{$tc} ) {
                $self->testcases->{$case} = $tc->{$case};
            }
            $policy = $merger->merge( $policy, $new );
            push @{ $self->pfiles }, $pfile;
        }

    } ## end foreach my $dir ( _config_directory_list...)

    return $self;
} ## end sub BUILD

sub get {
    my ( $class ) = @_;

    return $config;
}

sub policy {
    my ( $class ) = @_;

    if ( not $policy ) {
        _load_base_policy();
    }

    return $policy;
}

sub _config_directory_list {
    my @dirlist;
    my $makefile_name = 'Zonemaster-Engine'; # This must be the same name as "name" in Makefile.PL
    push @dirlist, dist_dir( $makefile_name );
    push @dirlist, '/etc/zonemaster';
    push @dirlist, '/usr/local/etc/zonemaster';

    my $dir = ( getpwuid( $> ) )[7];
    if ( $dir ) {
        push @dirlist, $dir . '/.zonemaster';
    }

    return @dirlist;
}

sub _load_base_config {
    my $internal = decode_json( join( q{}, <DATA> ) );
    # my $filename = dist_file( 'Zonemaster', 'config.json' );
    # my $default = eval { decode_json scalar read_file $filename };
    #
    # $internal = $merger->merge( $internal, $default ) if $default;

    $config = $internal;

    return;
}

sub load_module_policy {
    my ( $class, $mod ) = @_;

    my $m = 'Zonemaster::Engine::Test::' . $mod;
    if ( $m->can( 'policy' ) and $m->policy ) {
        $policy = $merger->merge( $policy, { $mod => $m->policy } );
    }

    return;
}

sub load_config_file {
    my ( $self, $filename ) = @_;
    my $new = decode_json scalar read_file $filename;

    if ( $new ) {
        $config = $merger->merge( $config, $new );
        push @{ $self->cfiles }, $filename if ( ref( $self ) and $self->isa( __PACKAGE__ ) );
    }

    return !!$new;
}

sub load_policy_file {
    my ( $self, $filename ) = @_;

    if ( not -r $filename ) {
        foreach my $dir ( _config_directory_list() ) {
            my $name = File::Spec->catfile( $dir, $filename );
            if ( -r $name ) {
                $filename = $name;
                last;
            }
            else {
                if ( -r $name . '.json' ) {
                    $filename = $name . '.json';
                    last;
                }
            }
        }
    }

    my $new = decode_json scalar read_file $filename;
    if ( $new ) {
        my $tc = $new->{__testcases__};
        delete $new->{__testcases__};
        foreach my $case ( keys %{$tc} ) {
            $self->testcases->{$case} = $tc->{$case};
        }
        $policy = $merger->merge( $policy, $new );
        push @{ $self->pfiles }, $filename if ( ref( $self ) and $self->isa( __PACKAGE__ ) );
    }

    return !!$new;
} ## end sub load_policy_file

sub no_network {
    my ( $class, $value ) = @_;

    if ( defined( $value ) ) {
        $class->get->{no_network} = $value;
    }

    return $class->get->{no_network};
}

sub ipv4_ok {
    my ( $class, $value ) = @_;

    if ( defined( $value ) ) {
        $class->get->{net}{ipv4} = $value;
    }

    return $class->get->{net}{ipv4};
}

sub ipv6_ok {
    my ( $class, $value ) = @_;

    if ( defined( $value ) ) {
        $class->get->{net}{ipv6} = $value;
    }

    return $class->get->{net}{ipv6};
}

sub resolver_defaults {
    my ( $class ) = @_;

    return $class->get->{resolver}{defaults};
}

sub resolver_source {
    my ( $class, $sourceaddr ) = @_;

    if ( defined( $sourceaddr ) ) {
        $class->get->{resolver}{source} = $sourceaddr;
    }

    return $class->get->{resolver}{source};
}

sub logfilter {
    my ( $class ) = @_;

    return $class->get->{logfilter};
}

sub asnroots {
    my ( $class ) = @_;

    return $class->get->{asnroots};
}

sub should_run {
    my ( $self, $name ) = @_;

    if ( not defined $self->testcases->{$name} ) {
        return 1;    # Default to runnings test
    }
    elsif ( $self->testcases->{$name} ) {
        return 1;
    }
    else {
        return;
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Zonemaster::Engine::Config - configuration access module for Zonemaster::Engine

=head1 SYNOPSIS

    Zonemaster::Engine->config->no_network(1); # Forbid network traffic

    my $value = Zonemaster::Engine::Config->get->{key}{subkey}; # Not really recommended way to access profile data

=head1 LOADING PROFILES

Initial profile data for the effective profile is loaded from the default profile.
The effective profile can be updated with custom profile data.
The default profile is parsed from a JSON file called F<default.profile> in the Zonemaster-Engine L<dist_dir|File::ShareDir/dist_dir>.

The possible contents of the JSON data is described further down in this manual
page.

=head1 PROFILE DATA ACCESS METHODS

=over

=item no_network([$value])

Returns the value of the C<no_network> flag. If given a defined value, sets the value to that value.

=item ipv4_ok([$value])

Returns the value of the C<ipv4> flag. If given a defined value, sets the value to that value.

=item ipv6_ok([$value])

Returns the value of the C<ipv6> flag. If given a defined value, sets the value to that value.

=item resolver_defaults()

Returns a reference to the resolver_defaults hash.

=item resolver_source([$addr])

Returns the source address all resolver objects should use when sending
queries, if one is set. If given an argument, sets the source address to the
argument.

=item logfilter()

Returns a reference to the logfilter hash.

=item asnroots()

Returns a reference to the list of ASN lookup domains.

=back

=head1 MANAGEMENT METHODS

=over

=item get()

Returns the effective profile in the data structure described in the L<PROFILE DATA> section.

=item load_profile_file($path)

Loads profile data from the given file and merges it into the effective profile.

The given path must be a JSON file matching the L<PROFILE DATA> format.
Data from the file overrides the effective profile when the same keys exist in both places.

=item BUILD

Internal method only mentioned here to please L<Pod::Coverage>.

=item should_run($name)

Given a test case name, it returns true if that test case should be included in
a test run according to the effective profile or false if not.

=back

=head1 PROFILE DATA

Profile data is represented as a nested hash (possibly with arrays as values in places).

The allowed keys are as follows.
Top-level keys are denoted by the keys themselves (e.g. I<asn_roots> is just a top-level key).
Hierarchy is denoted by dots (e.g. I<net.ipv4> means a top-level key I<net> mapping to a second-level hashref which in turn has an I<ipv4> key).

=head2 resolver.defaults

These are the default flag and timing values used for the resolver objects used to actually send DNS queries.

=head2 resolver.defaults.usevc

If set, only use TCP. Default not set.

=head2 resolver.defaults.retrans

The number of seconds between retries. Default 3.

=head2 resolver.defaults.dnssec

If set, sets the DO flag in queries. Default not set.

=head2 resolver.defaults.recurse

If set, sets the RD flag in queries. Default not set (and almost certainly should remain that way).

=head2 resolver.defaults.retry

The number of times a query is sent before we give up. Can be set to zero, although that's not very useful (since no queries will be sent at all). Defaults to 2.

=head2 resolver.defaults.igntc

If set, queries that get truncated UDP responses will be automatically retried over TCP. Default not set.

=head2 resolver.source

The source address all resolver objects should use when sending queries, if one is set.

=head2 net.ipv4

If set, resolver objects are allowed to send queries over IPv4. Default set.

=head2 net.ipv6

If set, resolver objects are allowed to send queries over IPv6. Default set.

=head2 no_network

If set to a true value, network traffic is forbidden. Use when you want to be sure that any data is only taken from a preloaded cache.

=head2 asnroots

This key must be a list of domain names. The domains will be assumed to be
Cymru-style AS lookup zones. Normally only the first name in the list will be
used, the rest are backups in case the earlier ones don't work.

=head2 logfilter

By using this key, the severity level of messages can be set in a much more fine-grained way than by the C<test_levels> item. The intended use is to remove known erroneous results. If you, for example, know that a certain name server is recursive and for some reason should be, you can use this functionality to lower the severity of the complaint about it to a lower level than normal.

The data under the C<logfilter> key should be structured like this:

   Module
      Tag
         Array of exceptions
             "when"
                Hash with conditions
             "set"
                Severity level to set if all conditions match

The hash with conditions should have keys matching the attributes of the log entry that's being filtered (check the translation files to see what they are). The values for the keys should be either a single value that the attribute should be, or an array of values any one of which the attribute should be.

A complete entry might could look like this:

       "SYSTEM": {
           "FILTER_THIS": [
               {
                   "when": {
                       "count": 1,
                       "type": ["this", "or"]
                   },
                   "set": "INFO"
               },
               {
                   "when": {
                       "count": 128,
                       "type": ["that"]
                   },
                   "set": "INFO"
               },
               {
                   "when": {
                       "count": 0
                   },
                   "set": "WARNING"
               }
           ]
       }

This would set the severity level to C<INFO> for any C<SYSTEM:FILTER_THIS> messages that had a C<count> attribute set to 1 and a C<type> attribute set to either C<this> or C<or>.
This also would set the level to C<INFO> for any C<SYSTEM:FILTER_THIS> messages that had a C<count> attribute set to 128 and a C<type> attribute set to C<that>.
And this would set the level to C<WARNING> for any C<SYSTEM:FILTER_THIS> messages that had a C<count> attribute set to 0.

=head2 test_levels

The value is a hash where the keys are names of test implementation modules (without the C<Zonemaster::Engine::Test::> prefix). Each of those keys hold another hash, where the keys are the tags that the module in question can emit and the values are the the severity levels that should apply to the tags. Any tags that are not found in the C<test_levels> data will default to level C<DEBUG>.

=head2 test_cases

The value is a hash where keys are names of test cases from the test specifications and values are booleans.
Only test cases that are set to C<false> are considered.
Test cases that are set to C<true> are ignored.

Specifies a blacklist of test cases to skip when a test module is asked to run of all of its test cases.
Test cases blacklisted here can still be run individually.
The test cases C<basic00>, C<basic01> and C<basic02> cannot be blacklisted this way.
The reason these particular test cases cannot be blacklisted is that part of their function is to verify that the given name can be tested at all.

=cut

__DATA__
{
   "asnroots" : [ "asnlookup.zonemaster.net", "asnlookup.iis.se"],
   "net" : {
      "ipv4" : 1,
      "ipv6" : 1
   },
   "no_network" : 0,
   "resolver" : {
      "defaults" : {
         "debug" : 0,
         "dnssec" : 0,
         "edns_size" : 0,
         "igntc" : 0,
         "recurse" : 0,
         "retrans" : 3,
         "retry" : 2,
         "usevc" : 0
      }
   }
}
