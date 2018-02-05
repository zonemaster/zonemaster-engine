package Zonemaster::Engine::Profile;

use 5.006;
use strict;
use warnings;

=head1 NAME

Zonemaster::Engine::Profile - A simple system for configuring Zonemaster Engine

=head1 SYNOPSIS

This module has two parts:

=over

=item * a I<profile> representation class

=item * a global profile object (the I<effective profile>) that configures Zonemaster Engine

=back

A I<profile> consists of a collection of named properties.

The properties determine the configurable behaviors of Zonemaster
Engine with regard to what tests are to be performed, how they are to
be performed, and how the results are to be analyzed.
For details on available properties see the L</PROFILE PROPERTIES>
section.

Here is an example that resets the effective profile to the default
profile values.

    use Zonemaster::Engine::Profile;

    my $default = Zonemaster::Engine::Profile->default;
    Zonemaster::Engine::Profile->effective_profile->merge( $default );

Here is an example that overrides the effective profile with values from
a given profile file.
For details on the file format see the L</JSON REPRESENTATION> section.

    my $foo = Zonemaster::Engine::Profile->load( "/path/to/foo.profile" );
    Zonemaster::Engine::Profile->effective_profile->merge( $foo );

For any given profile:

=over

=item * At any moment, each property is either set or unset.

=item * At any moment, every set property has a valid value.

=item * It is possible to set the value of each unset property.

=item * It is possible to update the value of each set property.

=item * It is NOT possible to unset the value of any set property.

=back

=head1 CLASS ATTRIBUTES

=head2 effective_profile

A L<Zonemaster::Engine::Profile>.
This is the effective profile.
It serves as the global runtime configuration for Zonemaster Engine.
Update it to change the configuration.

The effective profile is initialized with the default values declared
in the L</PROFILE PROPERTIES> section.

For the effective profile, all properties are always set (to valid
values).
This is based on the assumption that F<default.profile> specifies a
valid value for each and every property.

=head1 CLASS METHODS

=head2 new
A constructor that returns a new profile with all properties unset.

    my $profile = Zonemaster::Engine::Profile->new;

=head2 default

A contstructor that returns a new profile with the default property
values declared in the L</PROFILE PROPERTIES> section.

    my $default_profile = Zonemaster::Engine::Profile->default;

=head2 load

A constructor that returns a new profile with values loaded from a
profile file.

    my $profile = Zonemaster::Engine::Profile->load( '/path/to/file.profile' );

The returned profile has set values for all properties specified in the
given file.
The remaining properties are unset.

Dies if the given profile file is invalid.

For details on the file format see the L</JSON REPRESENTATION> section.

=head1 INSTANCE METHODS

=head2 get

Get the value of a property.

    my $value = $profile1->get( 'net.ipv6' );

Returns value of the given property, or C<undef> if the property is unset.
The returned value is a deep copy.

Dies if the given property name is invalid.

=head2 set

Set the value of a property.

    $profile1->set( 'net.ipv6', 0 );

Takes a property name and value and updates the property accordingly.

Returns C<$self>.

Dies if the given property name is invalid.

Dies if the value is invalid for the given property.

=head2 merge

Merge the profile data of another profile into this one.

    $profile1->merge( $other );

Properties from the other profile take precedence when the same property
name exists in both profiles.
The other profile object remains unmodified.

Returns C<$self>;

=head1 PROFILE PROPERTIES

Each property has a name and is either set or unset.
If it is set it has a value that is valid for that specific property.
Here is a listing of all the properties and their respective sets of
valid values.

Default values are listed here as specified in the distributed default
profile JSON file.

=head2 resolver.defaults.usevc

A boolean. If C<true>, only use TCP. Default C<false>.

=head2 resolver.defaults.retrans

A number. The number of seconds between retries. Default 3.

=head2 resolver.defaults.dnssec

A boolean. If C<true>, sets the DO flag in queries. Default C<false>.

=head2 resolver.defaults.recurse

A boolean. If C<true>, sets the RD flag in queries. Default C<false>.

This should almost certainly be kept C<false>.

=head2 resolver.defaults.retry

A non-negative integer. The number of times a query is sent before we
give up. Default 2.

If set to zero, no queries will be sent at all, which isn't very useful.

=head2 resolver.defaults.igntc

A boolean. If C<false>, UDP queries that get responses with the C<TC>
flag set will be automatically resent over TCP. Default C<false>.

=head2 resolver.source

A string or C<undef>. The source address all resolver objects should
use when sending queries. If C<undef>, the OS default address is used.

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
Only test cases mapped to C<false> are considered, i.e. only those
included in the blacklisted.
Test cases mapped to C<true> are ignored, i.e. they are not included
the blacklist.

=head1 JSON REPRESENTATION

Property names in L</PROFILE PROPERTIES> section correspond to paths in
a datastructure of nested JSON objects.
Property values are stored at their respective paths.
Paths are formed from property names by splitting them at dot characters
(U+002E).
The left-most path component corresponds to a key in the top-most
JSON object.
Properties with unset values are omitted in the JSON representation.

E.g. a profile with the only two properties set, C<net.ipv4> = 1 and
C<net.ipv6> = 1 has this JSON representation:

    {
        "net": {
            "ipv4": true,
            "ipv6": true
        }
    }

=cut

1; # End of Zonemaster::Engine::Profile
