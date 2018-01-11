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

Zonemaster::Engine::Config - profile access module for Zonemaster::Engine

=head1 SYNOPSIS

    Zonemaster::Engine->config->no_network(1); # Forbid network traffic

    my $value = Zonemaster::Engine::Config->get->{key}{subkey}; # Not really recommended way to access profile data

=head1 DESCRIPTION

Zonemaster::Engine::Config provides methods for reading and updating
the effective profile.

A profile is a set of configuration options (a.k.a. profile data)
regarding:

 * sets of tests to run
 * test result severity levels
 * DNS querying behavior

The I<effective profile> is a set of profile values that is consulted
by various parts of Zonemaster::Engine.
The I<default profile> is a set of profile values that is used to
initialize the effective profile.

Zonemaster::Engine::Config reads profile data from disk in a JSON
sub-format.
The JSON sub-format is described below in the L<PROFILE DATA> section.
The default profile is read from the file F<default.profile> located by
L<dist_dir|File::ShareDir/dist_dir> for Zonemaster-Engine.

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

Returns the effective profile in the data structure described in the
L<PROFILE DATA> section.

=item policy()

B<NOTE:> I believe this method won't make sense after the update.

Returns a reference to the current policy data. The format of that data is described further down in this document.

=item load_policy_file($filename)

B<NOTE:> I believe this method won't make sense after the update.

Load policy information from the given file and merge it into the pre-loaded
policy. Information from the loaded file overrides the pre-loaded information
when the same keys exist in both places.

If the given name does not lead directly to a readable file, each of the usual
directories will be checked if the name is there. If the plain name isn't, the
suffix C<.json> will be appended and another try will be done. For example, a
file F<$HOME/.zonemaster/Example.json> may be loaded by calling this method
with the string C<"Example">.

=item load_config_file($filename)

B<NOTE:> I believe this method won't make sense after the update.

Load configuration information from the given file and merge it into the pre-loaded config. Information from the loaded file overrides the pre-loaded information when the same keys exist in both places.

=item load_module_policy($module)

B<NOTE:> I believe this method won't make sense after the update.

Loads policy data included in a test module. The argument must be the short
form (without the initial C<Zonemaster::Engine::Test::>) and correctly capitalized.

=item load_profile_file($path)

Loads profile data from the given file and merges it into the effective
profile.

The given path must be a JSON file matching the L<PROFILE DATA> format.
Data from the file overrides the effective profile when the same keys
exist in both places.

=item BUILD

Internal method only mentioned here to please L<Pod::Coverage>.

=item should_run($name)

Given a test case name, it returns true if that test case should be included in
a test run according to the effective profile or false if not.

=back


=head1 PROFILE DATA

Profile data consists of a set of paths mapping to values.

The paths are expressed as nested hashrefs with the hash keys being
elements of the path.
Top-level keys are denoted by the keys themselves (e.g. I<asn_roots>
is just a top-level key).
Hierarchy is denoted by dots.
E.g. I<net.ipv4> means a top-level key I<net> mapping to a second-level
hashref which in turn has an I<ipv4> key.

The allowed paths and their respective allowed values are as follows.

=head2 resolver.defaults.usevc

A boolean. If C<true>, only use TCP. Default C<false>.

=head2 resolver.defaults.retrans

A number. The number of seconds between retries. Default 3.

=head2 resolver.defaults.dnssec

A boolean. If C<true>, sets the DO flag in queries. Default C<false>.

=head2 resolver.defaults.recurse

A boolean. If C<true>, sets the RD flag in queries. Default C<false>.

This should almost certainly be kept C<true>.

=head2 resolver.defaults.retry

A non-negative integer. The number of times a query is sent before we
give up. Default 2.

If set to zero, no queries will be sent at all, which isn't very useful.

=head2 resolver.defaults.igntc

A boolean. If C<true>, queries that get truncated UDP responses will be
automatically retried over TCP. Default C<false>.

=head2 resolver.source

The source address all resolver objects should use when sending queries,
if one is set.

=head2 net.ipv4

A boolean. If C<true>, resolver objects are allowed to send queries over
IPv4. Default C<true>.

=head2 net.ipv6

A boolean. If C<true>, resolver objects are allowed to send queries over
IPv6. Default C<true>.

=head2 no_network

A boolean. If true, network traffic is forbidden. Default C<false>.

Use when you want to be sure that any data is only taken from a preloaded
cache.

=head2 asnroots

An arrayref of domain names.

The domains will be assumed to be Cymru-style AS lookup zones.
Normally only the first name in the list will be used, the rest are
backups in case the earlier ones don't work.

=head2 logfilter

A complex data structure.

Specifies the severity level of each tag emitted by a specific module.
The intended use is to remove known erroneous results.
E.g. if you know that a certain name server is recursive and for some
reason should be, you can use this functionality to lower the severity
of the complaint about it to a lower level than normal.
The C<test_levels> item also specifies tag severity level, but with
coarser granularity and lower precedence.

The data under the C<logfilter> key should be structured like this:

   Module
      Tag
         Array of exceptions
             "when"
                Hash with conditions
             "set"
                Severity level to set if all conditions match

The hash with conditions should have keys matching the attributes of the log entry that's being filtered (check the translation files to see what they are). The values for the keys should be either a single value that the attribute should be, or an array of values any one of which the attribute should be.

A complete logfilter structure might could look like this:

    {
      "A_MODULE": {
        "SOME_TAG": [
          {
            "when": {
              "count": 1,
              "type": [
                "this",
                "or"
              ]
            },
            "set": "INFO"
          },
          {
            "when": {
              "count": 128,
              "type": [
                "that"
              ]
            },
            "set": "INFO"
          }
        ]
      },
      "ANOTHER_MODULE": {
        "OTHER_TAG": [
          {
            "when": {
              "bananas": 0
            },
            "set": "WARNING"
          }
        ]
      }
    }

This would set the severity level to C<INFO> for any C<A_MODULE:SOME_TAG>
messages that had a C<count> attribute set to 1 and a C<type> attribute
set to either C<this> or C<or>.
This also would set the level to C<INFO> for any C<A_MODULE:SOME_TAG>
messages that had a C<count> attribute set to 128 and a C<type> attribute
set to C<that>.
And this would set the level to C<WARNING> for any C<ANOTHER_MODULE:OTHER_TAG>
messages that had a C<bananas> attribute set to 0.

=head2 test_levels

A complex data structure.

Specifies the severity level of each tag emitted by a specific module.
The C<logfilter> item also specifies tag severity level, but with finer
granularity and higher precedence.

At the top level of this data structure are two levels of nested hashrefs.
The keys of the top level hash are names of test implementation modules
(without the C<Zonemaster::Engine::Test::> prefix).
The keys of the second level hashes are tags that the respective
modules emit.
The values of the second level hashes are mapped to severity levels.
The default severity level is C<DEBUG> for tags not found in the
C<test_levels> item.

=head2 test_cases

A hashref mapping test case names to booleans.

Specifies a blacklist of test cases to skip when a test module is asked
to run of all of its test cases.
Test cases blacklisted here can still be run individually.
The test cases C<basic00>, C<basic01> and C<basic02> cannot be blacklisted
this way.
The reason these particular test cases cannot be blacklisted is that part
of their function is to verify that the given name can be tested at all.

The keys of this hash are names of test cases from the test
specifications.
Only test cases mapped to C<false> are considered.
Test cases mapped to C<true> are ignored.

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
