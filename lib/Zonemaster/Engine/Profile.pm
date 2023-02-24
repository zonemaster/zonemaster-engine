package Zonemaster::Engine::Profile;

use 5.014002;

use strict;
use warnings;

use version; our $VERSION = version->declare( "v1.2.22" );

use File::ShareDir qw[dist_file];
use JSON::PP qw( encode_json decode_json );
use Scalar::Util qw(reftype);
use File::Slurp;
use Clone qw(clone);
use Data::Dumper;
use Net::IP::XS;
use Log::Any qw( $log );
use YAML::XS qw();

$YAML::XS::Boolean = "JSON::PP";

use Zonemaster::Engine::Constants qw( $RESOLVER_SOURCE_OS_DEFAULT $DURATION_5_MINUTES_IN_SECONDS $DURATION_1_HOUR_IN_SECONDS $DURATION_4_HOURS_IN_SECONDS $DURATION_12_HOURS_IN_SECONDS $DURATION_1_DAY_IN_SECONDS $DURATION_1_WEEK_IN_SECONDS $DURATION_180_DAYS_IN_SECONDS );

my %profile_properties_details = (
    q{redis} => {
        type    => q{HashRef},
    },
    q{resolver.defaults.debug} => {
        type    => q{Bool}
    },
    q{resolver.defaults.dnssec} => {
        type    => q{Bool}
    },
    q{resolver.defaults.edns_size} => {
        type    => q{Num}
    },
    q{resolver.defaults.igntc} => {
        type    => q{Bool}
    },
    q{resolver.defaults.fallback} => {
        type    => q{Bool}
    },
    q{resolver.defaults.recurse} => {
        type    => q{Bool}
    },
    q{resolver.defaults.retrans} => {
        type    => q{Num},
        min     => 1,
        max     => 255
    },
    q{resolver.defaults.retry} => {
        type    => q{Num},
        min     => 1,
        max     => 255
    },
    q{resolver.defaults.usevc} => {
        type    => q{Bool}
    },
    q{resolver.defaults.timeout} => {
        type    => q{Num}
    },
    q{resolver.source} => {
        type    => q{Str},
        test    => sub {
            if ( $_[0] ne $RESOLVER_SOURCE_OS_DEFAULT ) {
                Net::IP::XS->new( $_[0] ) || $log->warning( "Property resolver.source must be an IP address or the exact string $RESOLVER_SOURCE_OS_DEFAULT" );
            }
        }
    },
    q{resolver.source4} => {
        type    => q{Str},
        test    => sub {
            if ( $_[0] and $_[0] ne '' and not Net::IP::XS::ip_is_ipv4( $_[0] ) ) {
                $log->warning( "Property resolver.source4 must be an IPv4 address, the empty string or undefined" );
            }
            Net::IP::XS->new( $_[0] );
        }
    },
    q{resolver.source6} => {
        type    => q{Str},
        test    => sub {
            if ( $_[0] and $_[0] ne '' and not Net::IP::XS::ip_is_ipv6( $_[0] ) ) {
                $log->warning( "Property resolver.source6 must be an IPv6 address, the empty string or undefined" );
            }
            Net::IP::XS->new( $_[0] );
        }
    },
    q{net.ipv4} => {
        type    => q{Bool}
    },
    q{net.ipv6} => {
        type    => q{Bool}
    },
    q{no_network} => {
        type    => q{Bool}
    },
    q{asnroots} => {
        type    => q{ArrayRef},
        test    => sub {
            foreach my $ndd ( @{$_[0]} ) {
                die "Property asnroots has a NULL item" if not defined $ndd;
                die "Property asnroots has a non scalar item" if not defined ref($ndd);
                die "Property asnroots has an item too long" if length($ndd) > 255;
                foreach my $label ( split /[.]/, $ndd ) {
                    die "Property asnroots has a non domain name item" if $label !~ /^[a-z0-9](?:[-a-z0-9]{0,61}[a-z0-9])?$/;
                }
            }
        }
    },
    q{asn_db.style} => {
        type    => q{Str},
        test    => sub {
            if ( lc($_[0]) ne q{cymru} and lc($_[0]) ne q{ripe} ) {
                die "Property asn_db.style has 2 possible values : Cymru or RIPE (case insensitive)";
            }
            $_[0] = lc($_[0]);
        },
        default => q{cymru}
    },
    q{asn_db.sources} => {
        type    => q{HashRef},
        test    => sub {
            foreach my $db_style ( keys %{$_[0]} ) {
                if ( lc($db_style) ne q{cymru} and lc($db_style) ne q{ripe} ) {
                    die "Property asn_db.sources keys have 2 possible values : Cymru or RIPE (case insensitive)";
                }
                if ( not scalar @{ ${$_[0]}{$db_style} } ) {
                    die "Property asn_db.sources.$db_style has no items";
                }
                else {
                    foreach my $ndd ( @{ ${$_[0]}{$db_style} } ) {
                        die "Property asn_db.sources.$db_style has a NULL item" if not defined $ndd;
                        die "Property asn_db.sources.$db_style has a non scalar item" if not defined ref($ndd);
                        die "Property asn_db.sources.$db_style has an item too long" if length($ndd) > 255;
                        foreach my $label ( split /[.]/, $ndd ) {
                            die "Property asn_db.sources.$db_style has a non domain name item" if $label !~ /^[a-z0-9](?:[-a-z0-9]{0,61}[a-z0-9])?$/;
                        }
                    }
                    ${$_[0]}{lc($db_style)} = delete ${$_[0]}{$db_style};
                }
            }
        },
        default => { cymru => [ "asnlookup.zonemaster.net" ] }
    },
    q{logfilter} => {
        type    => q{HashRef},
        default => {}
    },
    q{test_levels} => {
        type    => q{HashRef}
    },
    q{test_cases} => {
        type    => q{ArrayRef}
    },
    q{test_cases_vars.dnssec04.REMAINING_SHORT} => {
        type    => q{Num},
        min     => 1,
        default => $DURATION_12_HOURS_IN_SECONDS
    },
    q{test_cases_vars.dnssec04.REMAINING_LONG} => {
        type    => q{Num},
        min     => 1,
        default => $DURATION_180_DAYS_IN_SECONDS
    },
    q{test_cases_vars.dnssec04.DURATION_LONG} => {
        type    => q{Num},
        min     => 1,
        default => $DURATION_180_DAYS_IN_SECONDS
    },
    q{test_cases_vars.zone02.SOA_REFRESH_MINIMUM_VALUE} => {
        type    => q{Num},
        min     => 1,
        default => $DURATION_4_HOURS_IN_SECONDS
    },
    q{test_cases_vars.zone04.SOA_RETRY_MINIMUM_VALUE} => {
        type    => q{Num},
        min     => 1,
        default => $DURATION_1_HOUR_IN_SECONDS
    },
    q{test_cases_vars.zone05.SOA_EXPIRE_MINIMUM_VALUE} => {
        type    => q{Num},
        min     => 1,
        default => $DURATION_1_WEEK_IN_SECONDS
    },
    q{test_cases_vars.zone06.SOA_DEFAULT_TTL_MAXIMUM_VALUE} => {
        type    => q{Num},
        min     => 1,
        default => $DURATION_1_DAY_IN_SECONDS
    },
    q{test_cases_vars.zone06.SOA_DEFAULT_TTL_MINIMUM_VALUE} => {
        type    => q{Num},
        min     => 1,
        default => $DURATION_5_MINUTES_IN_SECONDS
    }
);

_init_profile_properties_details_defaults();

sub _init_profile_properties_details_defaults {
    my $default_file   = dist_file( 'Zonemaster-Engine', 'profile.json');
    my $json           = read_file( $default_file );
    my $default_values = decode_json( $json );
    foreach my $property_name ( keys %profile_properties_details ) {
        if ( defined _get_value_from_nested_hash( $default_values, split /[.]/, $property_name ) ) {
            $profile_properties_details{$property_name}{default} = clone _get_value_from_nested_hash( $default_values, split /[.]/, $property_name );
        }
    }
}

sub _get_profile_paths {
    my ( $paths_ref, $data, @path ) = @_;

    foreach my $key (sort keys %$data) {

        my $path = join '.', @path, $key;
        if (ref($data->{$key}) eq 'HASH' and not exists $profile_properties_details{$path} ) {
            _get_profile_paths($paths_ref, $data->{$key}, @path, $key);
            next;
        }
        else {
            $paths_ref->{$path} = 1;
        }
    }
}

sub _get_value_from_nested_hash {
    my ( $hash_ref, @path ) = @_;

    my $key = shift @path;
    if ( exists $hash_ref->{$key} ) {
        if ( @path ) {
            my $value_type = reftype($hash_ref->{$key});
            if ( $value_type eq q{HASH} ) {
                return _get_value_from_nested_hash( $hash_ref->{$key}, @path );
            }
            else {
                return undef;
            }
        }
        else {
            return $hash_ref->{$key};
        }
    }
    else {
        return undef;
    }
}

sub _set_value_to_nested_hash {
    my ( $hash_ref, $value, @path ) = @_;

    my $key = shift @path;

    if (  ! exists $hash_ref->{$key} ) {
        $hash_ref->{$key} = {};
    }
    if ( @path ) {
        _set_value_to_nested_hash( $hash_ref->{$key}, $value, @path );
    }
    else {
        $hash_ref->{$key} = clone $value;
    }
}

our $effective = Zonemaster::Engine::Profile->default;

sub new {
    my $class = shift;
    my $self = {};
    $self->{q{profile}} = {};

    bless $self, $class;

    return $self;
}

sub default {
    my ( $class ) = @_;
    my $new = $class->new;
    foreach my $property_name ( keys %profile_properties_details ) {
        if ( exists $profile_properties_details{$property_name}{default} ) {
            $new->set( $property_name, $profile_properties_details{$property_name}{default} );
        }
    }
    $new->check_validity;
    return $new;
}

sub check_validity {
    my ( $self ) = @_;
    my $resolver = $self->{profile}{resolver};
    if ( exists $resolver->{source} and ( exists $resolver->{source4} or exists $resolver->{source6} ) ) {
        $log->warning( "Error in profile: 'resolver.source' (deprecated) can't be used in combination with 'resolver.source4' or 'resolver.source6'." );
    }
}

sub get {
    my ( $self, $property_name ) = @_;

    die "Unknown property '$property_name'"  if not exists $profile_properties_details{$property_name};

    if ( $profile_properties_details{$property_name}->{type} eq q{ArrayRef} or $profile_properties_details{$property_name}->{type} eq q{HashRef} ) {
        return clone _get_value_from_nested_hash( $self->{q{profile}}, split /[.]/, $property_name );
    } else {
        return _get_value_from_nested_hash( $self->{q{profile}}, split /[.]/, $property_name );
    }
}

sub set {
    my ( $self, $property_name, $value ) = @_;

    $self->_set( q{DIRECT}, $property_name, $value );
}

sub _set {
    my ( $self, $from, $property_name, $value ) = @_;
    my $value_type = reftype($value);
    my $data_details;

    die "Unknown property '$property_name'" if not exists $profile_properties_details{$property_name};

    $data_details = sprintf "[TYPE=%s][FROM=%s][VALUE_TYPE=%s][VALUE=%s]\n%s",
                            exists $profile_properties_details{$property_name}->{type} ? $profile_properties_details{$property_name}->{type} : q{UNDEF},
                            defined $from ? $from : q{UNDEF},
                            defined $value_type ? $value_type : q{UNDEF},
                            defined $value ? $value : q{[UNDEF]},
                            Data::Dumper::Dumper($value);
    # $value is a Scalar
    if ( ! $value_type  or $value_type eq q{SCALAR} ) {
        die "Property $property_name can not be undef" if not defined $value;

        # Boolean
        if ( $profile_properties_details{$property_name}->{type} eq q{Bool} ) {
            if ( $from eq q{DIRECT} and !$value ) {
                $value = JSON::PP::false;
            }
            elsif ( $from eq q{DIRECT} and $value ) {
                $value = JSON::PP::true;
            }
            elsif ( $from eq q{JSON} and $value_type and $value == JSON::PP::false ) {
                $value = JSON::PP::false;
            }
            elsif ( $from eq q{JSON} and $value_type and $value == JSON::PP::true ) {
                $value = JSON::PP::true;
            }
            else {
                die "Property $property_name is of type Boolean $data_details";
            }
        }
        # Number. In our case, only non-negative integers
        elsif ( $profile_properties_details{$property_name}->{type} eq q{Num} ) {
            if ( $value !~ /^(\d+)$/ ) {
                die "Property $property_name is of type non-negative integer $data_details";
            }
            if ( exists $profile_properties_details{$property_name}->{min} and $value < $profile_properties_details{$property_name}->{min} ) {
                die "Property $property_name value is out of limit (smaller)";
            }
            if ( exists $profile_properties_details{$property_name}->{max} and $value > $profile_properties_details{$property_name}->{max} ) {
                die "Property $property_name value is out of limit (bigger)";
            }

            $value = 0+ $value;    # Make sure JSON::PP doesn't serialize it as a JSON string
        }
    }
    else {
        # Array
        if ( $profile_properties_details{$property_name}->{type} eq q{ArrayRef} and reftype($value) ne q{ARRAY} ) {
            die "Property $property_name is not a ArrayRef $data_details";
        }
        # Hash
        elsif ( $profile_properties_details{$property_name}->{type} eq q{HashRef} and reftype($value) ne q{HASH} ) {
            die "Property $property_name is not a HashRef $data_details";
        }
        elsif ( $profile_properties_details{$property_name}->{type} eq q{Bool} or $profile_properties_details{$property_name}->{type} eq q{Num} or $profile_properties_details{$property_name}->{type} eq q{Str} ) {
            die "Property $property_name is a Scalar $data_details";
        }
    }

    if ( $profile_properties_details{$property_name}->{test} ) {
        $profile_properties_details{$property_name}->{test}->( $value );
    }

    return _set_value_to_nested_hash( $self->{q{profile}}, $value, split /[.]/, $property_name );
}

sub merge {
    my ( $self, $other_profile ) = @_;

    die "Merge with ", __PACKAGE__, " only" if ref($other_profile) ne __PACKAGE__;

    foreach my $property_name ( keys %profile_properties_details ) {
        if ( defined _get_value_from_nested_hash( $other_profile->{q{profile}}, split /[.]/, $property_name ) ) {
            $self->_set( q{JSON}, $property_name, _get_value_from_nested_hash( $other_profile->{q{profile}}, split /[.]/, $property_name ) );
        }
    }
    $self->check_validity;
    return $other_profile->{q{profile}};
}

sub from_json {
    my ( $class, $json ) = @_;
    my $new = $class->new;
    my $internal = decode_json( $json );
    my %paths;
    _get_profile_paths(\%paths, $internal);
    foreach my $property_name ( keys %paths ) {
        if ( defined _get_value_from_nested_hash( $internal, split /[.]/, $property_name ) ) {
            $new->_set( q{JSON}, $property_name, _get_value_from_nested_hash( $internal, split /[.]/, $property_name ) );
        }
    }

    $new->check_validity;
    return $new;
}

sub to_json {
    my ( $self ) = @_;

    return encode_json( $self->{q{profile}} );
}

sub from_yaml {
    my ( $class, $yaml ) = @_;
    my $data = YAML::XS::Load( $yaml );
    return $class->from_json( encode_json( $data ) );
}

sub to_yaml {
    my ( $self ) = @_;

    return YAML::XS::Dump( $self->{q{profile}} );
}

sub effective {
    return $effective;
}

1;

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

Here is an example for updating the effective profile with values from
a given file and setting all properties not mentioned in the file to
default values.
For details on the file format see the L</REPRESENTATIONS> section.

    use Zonemaster::Engine::Profile;

    my $json    = read_file( "/path/to/foo.profile" );
    my $foo     = Zonemaster::Engine::Profile->from_json( $json );
    my $profile = Zonemaster::Engine::Profile->default;
    $profile->merge( $foo );
    Zonemaster::Engine::Profile->effective->merge( $profile );

Here is an example for serializing the default profile to JSON.

    my $string = Zonemaster::Engine::Profile->default->to_json;

For any given profile:

=over

=item * At any moment, each property is either set or unset.

=item * At any moment, every set property has a valid value.

=item * It is possible to set the value of each unset property.

=item * It is possible to update the value of each set property.

=item * It is NOT possible to unset the value of any set property.

=back

=head1 CLASS ATTRIBUTES

=head2 effective

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

A constructor that returns a new profile with the default property
values declared in the L</PROFILE PROPERTIES> section.

    my $default = Zonemaster::Engine::Profile->default;

=head2 from_json

A constructor that returns a new profile with values parsed from a JSON string.

    my $profile = Zonemaster::Engine::Profile->from_json( '{ "no_network": true }' );

The returned profile has set values for all properties specified in the
given string.
The remaining properties are unset.

Dies if the given string is illegal according to the L</JSON REPRESENTATION>
section or if the property values are illegal according to the L</PROFILE
PROPERTIES> section.

=head2 from_yaml

A constructor that returns a new profile with values parsed from a YAML string.

    my $profile = Zonemaster::Engine::Profile->from_yaml( <<EOF
    no_network: true
    EOF
    );

The returned profile has set values for all properties specified in the
given string.
The remaining properties are unset.

Dies if the given string is illegal according to the L</YAML REPRESENTATION>
section or if the property values are illegal according to the L</PROFILE
PROPERTIES> section.

=head1 INSTANCE METHODS

=head2 check_validity

Verify that the profile does not allow confusing combinations.

=head2 get

Get the value of a property.

    my $value = $profile1->get( 'net.ipv6' );

Returns value of the given property, or C<undef> if the property is unset.
For boolean properties the returned value is either C<1> for true or C<0> for
false.
For properties with complex types, the returned value is a
L<deep copy|https://en.wiktionary.org/wiki/deep_copy#Noun>.

Dies if the given property name is invalid.

=head2 set

Set the value of a property.

    $profile1->set( 'net.ipv6', 0 );

Takes a property name and value and updates the property accordingly.
For boolean properties any truthy value is interpreted as true and any falsy
value except C<undef> is interpreted as false.

Dies if the given property name is invalid.

Dies if the value is C<undef> or otherwise invalid for the given property.

=head2 merge

Merge the profile data of another profile into this one.

    $profile1->merge( $other );

Properties from the other profile take precedence when the same property
name exists in both profiles.
The other profile object remains unmodified.

=head2 to_json

Serialize the profile to the L</JSON REPRESENTATION> format.

    my $string = $profile->to_json();

Returns a string.

=head2 to_yaml

Serialize the profile to the L</JSON REPRESENTATION> format.

    my $string = $profile->to_yaml();

Returns a string.

=head1 SUBROUTINES

=head2 _get_profile_paths

Internal method used to get all the paths of a nested hashes-of-hashes.
It creates a hash where keys are dotted keys of the nested hashes-of-hashes
that exist in %profile_properties_details.

    _get_profile_paths(\%paths, $internal);

=head2 _get_value_from_nested_hash

Internal method used to get a value in a nested hashes-of-hashes.

    _get_value_from_nested_hash( $hash_ref, @path );

Where $hash_ref is the hash to explore and @path are the labels of the property to get.

   @path = split /\./,  q{resolver.defaults.usevc};

=head2 _set_value_to_nested_hash

Internal method used to set a value in a nested hashes-of-hashes.

    _set_value_from_nested_hash( $hash_ref, $value, @path );

Where $hash_ref is the hash to explore and @path are the labels of the property to set.

   @path = split /\./,  q{resolver.defaults.usevc};

=head1 PROFILE PROPERTIES

Each property has a name and is either set or unset.
If it is set it has a value that is valid for that specific property.
Here is a listing of all the properties and their respective sets of
valid values.

Default values are listed here as specified in the distributed default
profile JSON file.

=head2 resolver.defaults.usevc

A boolean. If true, only use TCP. Default false.

=head2 resolver.defaults.retrans

An integer between 1 and 255 inclusive. The number of seconds between retries.
Default 3.

=head2 resolver.defaults.dnssec

*DEPRECATED as of 2023.1. Planned for removal in 2023.2*
A boolean. If true, sets the DO flag in queries. Default false.

=head2 resolver.defaults.edns_size

*DEPRECATED as of 2023.1. Planned for removal in 2023.2*
An integer. The EDNS0 UDP size used in EDNS queries. Default 512.

=head2 resolver.defaults.recurse

A boolean. If true, sets the RD flag in queries. Default false.

This should almost certainly be kept false.

=head2 resolver.defaults.retry

An integer between 1 and 255 inclusive.
The number of times a query is sent before we give up. Default 2.

=head2 resolver.defaults.igntc

A boolean. If false, UDP queries that get responses with the C<TC>
flag set will be automatically resent over TCP. Default false.

=head2 resolver.defaults.fallback

A boolean. If true, UDP queries that get responses with the C<TC>
flag set will be automatically resent over TCP or using EDNS. Default
true.

In ldns-1.7.0 (NLnet Labs), in case of truncated answer when UDP is used,
the same query is resent with EDNS0 and TCP (if needed). If you
want the original answer (with TC bit set) and avoid this kind of
replay, set this flag to false.

=head2 resolver.source

Deprecated (planned removal: v2024.1).
Use L</resolver.source4> and L</resolver.source6>.
A string that is either an IP address or the exact string C<"os_default">.
The source address all resolver objects should use when sending queries.
If C<"os_default">, the OS default address is used.
Default C<"os_default">.

=head2 resolver.source4

A string that is an IPv4 address or the empty string or undefined.
The source address all resolver objects should use when sending queries over IPv4.
If the empty string or undefined, use the OS default IPv4 address if available.
Default "" (empty string).

=head2 resolver.source6

A string that is an IPv6 address or the empty string or undefined.
The source address all resolver objects should use when sending queries over IPv6.
If the empty string or undefined, use the OS default IPv6 address if available.
Default "" (empty string).

=head2 net.ipv4

A boolean. If true, resolver objects are allowed to send queries over
IPv4. Default true.

=head2 net.ipv6

A boolean. If true, resolver objects are allowed to send queries over
IPv6. Default true.

=head2 no_network

A boolean. If true, network traffic is forbidden. Default false.

Use when you want to be sure that any data is only taken from a preloaded
cache.

=head2 asnroots (DEPRECATED)

An arrayref of domain names. Default C<["asnlookup.zonemaster.net",
"asnlookup.iis.se", "asn.cymru.com"]>.

The domains will be assumed to be Cymru-style AS lookup zones.
Normally only the first name in the list will be used, the rest are
backups in case the earlier ones don't work.

=head2 asn_db.style

A string that is either C<"Cymru"> or C<"RIPE">. Defines which method will
be used for AS lookup zones.
Default C<"Cymru">.

=head2 asn_db.sources

An arrayref of domain names when asn_db.style is set to C<"Cymru"> or whois
servers when asn_db.style is set to C<"RIPE">. Normally only the first item
in the list will be used, the rest are backups in case the earlier ones don't
work.
Default C<"asnlookup.zonemaster.net">.

=head2 logfilter

A complex data structure. Default C<{}>.

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

The hash with conditions should have keys matching the attributes of
the log entry that's being filtered (check the translation files to see
what they are). The values for the keys should be either a single value
that the attribute should be, or an array of values any one of which the
attribute should be.

A complete logfilter structure might look like this:

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

The various L<test case specifications|
https://github.com/zonemaster/zonemaster/tree/master/docs/specifications/tests/README.md>
define the default severity level for some of the messages.
These specifications are the only authoritative documents on the default
severity level for the various messages.
For messages not defined in any of these specifications please refer to the file
located by L<dist_file("Zonemaster-Engine", "default.profile")|
File::ShareDir/dist_file>.
For messages neither defined in test specifications, nor listed in
C<default.profile>, the default severity level is C<DEBUG>.

I<Note:> Sometimes multiple test cases within the same test module define
messages for the same tag.
When they do, it is imperative that all test cases define the same severity
level for the tag.

=head2 test_cases

An arrayref of names of implemented test cases as listed in the
L<test case specifications|
https://github.com/zonemaster/zonemaster/tree/master/docs/specifications/tests/ImplementedTestCases.md>.
Default is an arrayref listing all the test cases.

Specifies which test cases to consider when a test module is asked
to run of all of its test cases.

Test cases not included here can still be run individually.

The test cases C<basic00>, C<basic01> and C<basic02> are always considered no
matter if they're excluded from this property.
This is because part of their function is to verify that the given domain name
can be tested at all.

=head2 test_cases_vars.dnssec04.REMAINING_SHORT

A positive integer value.
Recommended lower bound for signatures' remaining validity time (in seconds) in
test case L<DNSSEC04|
https://github.com/zonemaster/zonemaster/blob/master/docs/specifications/tests/DNSSEC-TP/dnssec04.md>.
Related to the REMAINING_SHORT message tag from this test case.
Default C<43200> (12 hours in seconds).

=head2 test_cases_vars.dnssec04.REMAINING_LONG

A positive integer value.
Recommended upper bound for signatures' remaining validity time (in seconds) in
test case L<DNSSEC04|
https://github.com/zonemaster/zonemaster/blob/master/docs/specifications/tests/DNSSEC-TP/dnssec04.md>.
Related to the REMAINING_LONG message tag from this test case.
Default C<15552000> (180 days in seconds).

=head2 test_cases_vars.dnssec04.DURATION_LONG

A positive integer value.
Recommended upper bound for signatures' lifetime (in seconds) in the test case
L<DNSSEC04|
https://github.com/zonemaster/zonemaster/blob/master/docs/specifications/tests/DNSSEC-TP/dnssec04.md>.
Related to the DURATION_LONG message tag from this test case.
Default C<15552000> (180 days in seconds).

=head2 test_cases_vars.zone02.SOA_REFRESH_MINIMUM_VALUE

A positive integer value.
Recommended lower bound for SOA refresh values (in seconds) in test case
L<ZONE02|
https://github.com/zonemaster/zonemaster/blob/master/docs/specifications/tests/Zone-TP/zone02.md>.
Related to the REFRESH_MINIMUM_VALUE_LOWER message tag from this test case.
Default C<14400> (4 hours in seconds).

=head2 test_cases_vars.zone04.SOA_RETRY_MINIMUM_VALUE

A positive integer value.
Recommended lower bound for SOA retry values (in seconds) in test case
L<ZONE04|
https://github.com/zonemaster/zonemaster/blob/master/docs/specifications/tests/Zone-TP/zone04.md>.
Related to the RETRY_MINIMUM_VALUE_LOWER message tag from this test case.
Default C<3600> (1 hour in seconds).

=head2 test_cases_vars.zone05.SOA_EXPIRE_MINIMUM_VALUE

A positive integer value.
Recommended lower bound for SOA expire values (in seconds) in test case
L<ZONE05|
https://github.com/zonemaster/zonemaster/blob/master/docs/specifications/tests/Zone-TP/zone05.md>.
Related to the EXPIRE_MINIMUM_VALUE_LOWER message tag from this test case.
Default C<604800> (1 week in seconds).

=head2 test_cases_vars.zone06.SOA_DEFAULT_TTL_MINIMUM_VALUE

A positive integer value.
Recommended lower bound for SOA minimum values (in seconds) in test case
L<ZONE06|
https://github.com/zonemaster/zonemaster/blob/master/docs/specifications/tests/Zone-TP/zone06.md>.
Related to the SOA_DEFAULT_TTL_MAXIMUM_VALUE_LOWER message tag from this test case.
Default C<300> (5 minutes in seconds).

=head2 test_cases_vars.zone06.SOA_DEFAULT_TTL_MAXIMUM_VALUE

A positive integer value.
Recommended upper bound for SOA minimum values (in seconds) in test case
L<ZONE06|
https://github.com/zonemaster/zonemaster/blob/master/docs/specifications/tests/Zone-TP/zone06.md>.
Related to the SOA_DEFAULT_TTL_MAXIMUM_VALUE_HIGHER message tag from this test case.
Default C<86400> (1 day in seconds).

=head1 REPRESENTATIONS

=head2 JSON REPRESENTATION

Property names in L</PROFILE PROPERTIES> section correspond to paths in
a datastructure of nested JSON objects.
Property values are stored at their respective paths.
Paths are formed from property names by splitting them at dot characters
(U+002E).
The left-most path component corresponds to a key in the top-most
JSON object.
Properties with unset values are omitted in the JSON representation.

For a complete example, refer to the file located by L<dist_file(
"Zonemaster-Engine", "default.profile" )|File::ShareDir/dist_file>.
A profile with the only two properties set, C<net.ipv4> = true and
C<net.ipv6> = true has this JSON representation:

    {
        "net": {
            "ipv4": true,
            "ipv6": true
        }
    }

=head2 YAML REPRESENTATION

Similar to the L</JSON REPRESENTATION> but uses a YAML format.

=cut
