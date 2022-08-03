# Profiles

## Default profile

The default profile is documented in the [profile properties] section
of the Zonemaster::Engine::Profile module.

The default profile is stored in a default profile file, [profile.json],
always loaded by Zonemaster-Engine.

## Creating profiles

Some properties are empty by default such as `logfilter` and
`test_cases_vars`. These properties are not present in the default
profile. For an example of their usage, refer to the example file,
[profile_example.json]. The content of the two files, as is or modified, can be
merged into a custom profile file that can be loaded by Zonemaster-Engine. Both
Zonemaster-CLI and Zonemaster-Backend has direct options for loading a custom
profile file.

[profile.json]:          ../share/profile.json
[profile_example.json]:  ../share/profile_example.json
[Profile properties]:    https://metacpan.org/pod/Zonemaster::Engine::Profile#PROFILE-PROPERTIES
