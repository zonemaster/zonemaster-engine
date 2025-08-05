package TestUtil::DSL;

use warnings;
use strict;
use v5.24;

use Carp qw(confess croak);

use TestUtil::DSL::Compiler;

# This is needed in order to squelch “too late to run INIT block” warnings.
use Zonemaster::Engine ();

=encoding utf8

=head1 NAME

TestUtil::DSL - a domain-specific language for easy testing of test cases

=head1 SYNOPSIS

Because this package lies in the testing directory C<t/>, which is not listed in C<@INC> during testing,
it must be loaded using the following code:

    use File::Basename qw( dirname );
    use File::Spec::Functions qw( rel2abs );
    use lib dirname( rel2abs( $0 ) );
    use TestUtil::DSL;

A test case can then be tested with the following minimal skeleton:

    testing_test_case 'Example', 'example01';

    all_tags qw(EX01_ALL_GOOD
                EX01_MINOR_ISSUE
                EX01_SOMETHING_WRONG
                EX01_SOME_OTHER_PROBLEM
                EX01_BREAKS_ON_SOME_FEATURE);

    root_hints 'ns1' => [ qw(127.1.0.1 fda1:b2:c3::127:1:0:1) ],
               'ns2' => [ qw(127.1.0.2 fda1:b2:c3::127:1:0:2) ];
    zone_name_template '{SCENARIO}.{TESTCASE}.xa';

    scenario 'GOOD-{1..3}' => sub {
        expect EX01_ALL_GOOD;
    };

    # more scenarios here

    no_more_scenarios;

=cut

use Exporter 'import';

our @EXPORT = qw(all_tags
                 expect
                 expect_others
                 fake_ds
                 fake_ns
                 forbid
                 forbid_others
                 no_more_scenarios
                 not_testable
                 root_hints
                 scenario
                 testing_test_case
                 todo
                 zone
                 zone_name_template);

# Define a stack for internal context objects, some functions to manipulate it,
# and only expose the top of the stack.
{
    my @STACK = ();

    sub STATE () {
        $STACK[-1];
    }

    sub check_state ($) {
        my ($expected_state) = @_;

        if (defined $expected_state) {
            if (scalar @STACK == 0 or $expected_state ne STATE->{_STATE}) {
                croak "This keyword is not valid in this context."
            }
        }
        elsif (scalar @STACK != 0) {
            croak "This keyword can only be used once";
        }
    }

    sub pop_state {
        my $result = pop @STACK // croak "Attempted to pop empty stack";
        delete $result->{_STATE};
        return $result;
    }

    sub push_state ($) {
        push @STACK, { _STATE => $_[0] };
    }
}

# Internal mechanics

sub _is_uint_bits {
    my ($value, $bits) = @_;
    return ($value =~ /^\d+$/a and $value >= 0 and $value < (1 << $bits));
}

sub _expand_scenario_names {
    my @scenario_names = @_;
    my @result;

    for my $name (@scenario_names) {
        if ($name=~ /^ (?<prefix> [^{]*) \{
                       (?<start> \d+) \Q..\E (?<end> \d+)
                       \} $ /x ) {
            for my $i ($+{start}..$+{end}) {
                push @result, "$+{prefix}$i";
            }
        }
        else {
            push @result, $name;
        }
    }

    return @result;
}

# Used by expect, forbid and variations in order to catch undeclared tags
sub _ensure_tag_is_declared {
    my ( $tag, $clause ) = @_;

    exists STATE->{all_tags}{$tag}
        or croak "Tag '$tag' used in '$clause' clause but not declared in 'all_tags'";
}

=head1 TOP-LEVEL KEYWORDS

=head2 all_tags

    all_tags qw(SOME_TAG SOME_OTHER_TAG AND_ANOTHER_ONE);

List all the message tags that the test case being tested is expected to emit.

=cut

sub all_tags (@) {
    my @tags = @_;
    check_state 'testing_test_case';

    %{STATE->{all_tags}} = map { $_ => 1 } @tags;
}

=head2 no_more_scenarios

    no_more_scenarios;

Ends a declaration of a test. Similar to C<done_testing> in L<Test::More>.

=cut

sub no_more_scenarios () {
    check_state 'testing_test_case';
    my $spec = pop_state;

    # Do not clutter AST with data the compiler does not need
    delete $spec->{zone_name_template};
    delete $spec->{all_tags};

    TestUtil::DSL::Compiler::compile($spec)->();
}

=head2 scenario

Declares one or more scenario blocks.

A scenario is defined by a name and a set of expectations. The name is used to
derive the name of a zone on which to run the test case being tested. The
result of this run is a collection of messages, which are then compared to the
expected result declared in the scenario block.

The scenario block body is a special coderef, evaluated in a special context which
gives meaning to a set of scenario-specific keywords. See L<SCENARIO-SPECIFIC
KEYWORDS> for more information on what keywords are valid in a scenario block.

The C<scenario> keywords has several legal syntaxes.

The first form declares a single scenario:

    scenario 'SCENARIO-NAME' => sub {
        # scenario declaration here
    };

The second form declares multiple scenarios, all sharing the same expectations:

    scenario qw(SCENARIO-ONE SCENARIO-TWO) => sub {
        # scenario declaration here
    };

Scenario names may end with a number range expressed as C<{M..N}> where C<M>
and C<N> are integers. This is a shorthand for listing scenarios that all
share the same prefix but differ only by a numbered suffix. This notation
allows for concise declarations of scenarios that may be configured
differently but are expected to yield the same set of messages from the test
case. For example, the following two declarations are equivalent:

    scenario qw(GOOD-{1..2} EXAMPLE-{1..4}) => sub { ... };

    scenario qw(GOOD-1 GOOD-2
                EXAMPLE-1 EXAMPLE-2 EXAMPLE-3 EXAMPLE-4) => sub { ... };


=cut

sub scenario (@) {
    check_state 'testing_test_case';

    croak "At least two arguments required" unless scalar @_ >= 2;
    croak "A 'root_hints' must appear before a 'scenario' block"
        unless exists STATE->{root_hints};

    my $definition = pop @_;
    my @names = _expand_scenario_names(@_);

    my @context = caller(0);

    my $scenario = {
        names => \@names,
        caller => [ @context[1..2] ],
        body => do {
            my $PARENT_STATE = STATE;
            push_state 'scenario';

            STATE->{status} = [ 'testable' ];

            # Keep track of contents of “all_tags” so that expect and forbid
            # can raise errors if given a tag not in that list.
            STATE->{all_tags} = $PARENT_STATE->{all_tags};

            # Keep track of keys never mentioned by “expect” or “forbid” respectively
            # so that “expect_others” and “forbid_others” can be defined in terms
            # of “expect” and “forbid” respectively.
            %{STATE->{not_expected}}  = map { $_ => 1 } keys %{STATE->{all_tags}};
            %{STATE->{not_forbidden}} = map { $_ => 1 } keys %{STATE->{all_tags}};

            # Evaluate definition
            my $obj = do { $definition->(); pop_state; };

            # Clean up
            delete $obj->{all_tags};
            delete $obj->{not_expected};
            delete $obj->{not_forbidden};

            # Set default zone name (template)
            $obj->{zone} //= STATE->{zone_name_template};

            # Sanity checks
            if (not defined $obj->{zone}) {
                croak "No 'zone' keyword in scenario block and no previous "
                    . "'zone_name_template' seen";
            }

            # TODO do we need more sanity checks?
            $obj;
        }
    };

    foreach my $name (@{$scenario->{names}}) {
        STATE->{scenario_status}{$name} = $scenario->{body}{status};
    }
    push @{STATE->{scenarios}}, [ scenario => $scenario ];
}


=head2 testing_test_case

    testing_test_case 'MyModule' 'mymodule01';

Declare a unit test for a test case. The arguments for that keyword are the
name of the test plan, and the name of the test case being tested
respectively.

The DSL expects this keyword to be used first, before any other keyword.

=cut

sub testing_test_case ($$) {
    check_state undef;
    push_state 'testing_test_case';

    my ($test_module, $test_case) = @_;

    STATE->{test_module} = $test_module;
    STATE->{test_case} = $test_case;
}


=head2 root_hints

    root_hints 'ns1.example' => [ qw(198.51.113.10 2001:db8:0:8::53) ],
               'ns2.example' => [ qw(198.51.113.20 2001:db8:0:8::1:53) ];

Declare the set of name servers which are authoritative for the root zone.
These root hints apply to all scenarios in the file.

This keyword may only appear once and must be used before the first scenario
block.

=cut

sub root_hints (%) {
    my (%root_hints) = @_;
    check_state 'testing_test_case';
    croak "root_hints may be used only once" if exists STATE->{root_hints};
    STATE->{root_hints} = \%root_hints;
}

=head2 zone_name_template

    zone_name_template '{SCENARIO}.{TESTCASE}.xa';
    zone_name_template 'child.parent.{SCENARIO}.{TESTCASE}.xa';

Declare a default zone name template for the C<scenario> specifications that follow.

The string passed as arguments may contain placeholders, such as C<{SCENARIO}>
or C<{TESTCASE}>, that are substituted accordingly.

=cut

sub zone_name_template ($) {
    my ($template) = @_;
    check_state 'testing_test_case';
    STATE->{zone_name_template} = $template;
}


=head1 SCENARIO-SPECIFIC KEYWORDS

=head2 zone

    zone 'myzone.example.xa';
    zone 'myzone.{SCENARIO}.{TESTCASE}.xb';

Declare a zone name to be used in the scenario.

This declaration is optional, because the default value is inherited from the
top-level keyword L<zone_name_template>. It can be useful for one or two
exceptions to a general rule.

The same placeholders that are valid for L<zone_name_template> can also be
used here.

=cut

sub zone ($) {
    my ($zone) = @_;
    check_state 'scenario';

    # Template expansion is done at a later stage
    STATE->{zone} = $zone;
}

=head2 fake_ds

    fake_ds <key tag>, <algo>, <type>, <digest>
    fake_ds 51966, 8, 3, 'ABCDABCDABCDABCD';

Provide a DS record as part of the fake delegation to be used in the scenario.

=cut

sub fake_ds($$$$) {
    my ($tag, $algo, $type, $digest) = @_;

    unless ( _is_uint_bits($tag, 16) ) {
        croak "$tag: not a valid key tag";
    }
    unless ( _is_uint_bits($algo, 8) ) {
        croak "$algo: not a valid algorithm";
    }
    unless ( _is_uint_bits($type, 8) ) {
        croak "$type: not a valid type";
    }
    unless ( $digest =~ /^ (?: [0-9a-f]{2} )+ $/ix ) {
        croak "$digest: not a valid digest";
    }

    push @{STATE->{fake_ds}}, {
        keytag => $tag,
        algorithm => $algo,
        type => $type,
        digest => $digest
    };
}

=head2 fake_ns

    fake_ns <nameserver>[, <IP address…>]

Provide an NS record as part of the fake delegation to be used in the scenario.
The keyword accepts a name server name and optionally a list of IP addresses that
will be used as glue records if given.

Examples:

    fake_ns 'ns1.example';
    fake_ns 'ns1.example' => '192.0.2.50';
    fake_ns 'ns1.example' => '192.0.2.50', '2001:db8:0:8::53';

Passing the same name server name to more than one C<fake_ns> keyword is not
allowed and is an error.

=cut

sub fake_ns($@) {
    my ($name, @ips) = @_;

    if (exists STATE->{fake_ns}{$name}) {
        croak "'fake_ns' cannot be used for '$name' more than once";
    }

    STATE->{fake_ns}{$name} = \@ips;
}

=head2 expect

List one or more tags that the test case is expected to generate when it is run
on the scenario being defined.

This keyword allows for multiple syntaxes.

The first form specifies that at least one message of a certain tag is to be
expected among the test case’s output for the scenario:

    expect <tag>;

The second form is a shorthand that avoids repeating the C<expect> keyword. It
is equivalent to using the first form as many times as there are tags given as
arguments.

    expect <tag1>, <tag2>, ...;

The third form specifies a single tag name and a hashref of keys and criteria.
It specifies that a message whose tag matches the name and whose arguments
exist and match the supplied criteria must exist among the test case’s output.
See L<Criteria> below for a more in-depth explanation of this form.

    expect <tag> => { <argument1> => <criterion1>, ... };

The fourth form takes a tag name and a coderef: it searches for all messages
whose tag matches, evaluates the coderef with C<@_> set to the list of
messages matching the tag and expects the coderef to return a true value. This
form is useful for situations where the third form falls short. See L<Criteria>
below for examples.

    expect <tag> => sub { my @messages = @_; ... };

The C<expect> keyword can be used more than once in a scenario. All of the
checks specified by C<expect> and C<forbid> keywords must pass in order for
the scenario to pass.

=head3 Criteria

For the third form, arguments can be matched against:

=over

=item strings, which are compared with C<eq>;

=item regular expressions;

=item and coderefs, where C<$_> is bound to the message parameter’s value.

=back

The following expects C<SOME_TAG> to be generated with arguments C<ns_list>,
C<other_argument>, C<third_argument> and C<fourth_argument>. C<ns_list> must
be equal to C<ns1.example/127.0.60.1>, C<other_argument> must match
C</^ns2\..*/>, C<third_argument> must be case-insensitively equal to
C<example> and C<fourth_argument> is only tested for presence.

    expect SOME_TAG => {
        ns_list => 'ns1.example/127.0.60.1',
        other_argument => qr/^ns2\..*/,
        third_argument => sub { fc $_ eq fc 'EXAMPLE' },
        fourth_argument => sub { 1 },
    };

Note that if the test case emits C<SOME_TAG> with an argument that is not
listed in the C<expect> keyword, it is deemed an error.

Checking that a message tag has no parameters at all can also be done as
follows:

    expect TAG_WITHOUT_PARAMETERS => {};

More free-form criteria can be provided by means of the fourth form. The following
example checks if the scenario generated exactly three times a given message tag:

    expect SOME_TAG => sub { scalar @_ == 3 };

The following example ensures that all instances of SOME_TAG have a
C<some_argument> parameter equal to the string C<ns1.example/127.0.60.1>:

    expect SOME_TAG => sub {
        my @messages = @_;
        for my $m (@messages) {
            return 0 if $m->{some_argument} ne 'ns1.example/127.0.60.1';
        }
        return 1;
    }

=cut

sub expect (@) {
    if (scalar @_ == 2 and ref $_[1] eq 'HASH') {
        # Third form
        my ($tag, $args) = @_;
        _declare_expect( $tag, args => $args );
    }
    elsif (scalar @_ == 2 and ref $_[1] eq 'CODE') {
        # Fourth form
        my ($tag, $code) = @_;
        _declare_expect( $tag, code => $code );
    }
    elsif (scalar @_ >= 1) {
        # First or second form
        foreach my $tag (@_) {
            _declare_expect( $tag );
        }
    }
    else {
        croak "Need at least one argument";
    }
}

sub _declare_expect {
    my ($tag, %args) = @_;
    my @context = caller(1);

    _ensure_tag_is_declared( $tag, 'expect' );
    delete STATE->{not_expected}{$tag};
    push @{STATE->{expect}}, { tag => $tag, caller => [ @context[1..2] ], %args };
}

=head2 forbid

    forbid <tag1>, <tag2>, …

Specifies that the listed tags are not to be emitted by the test case in the
scenario being defined. In other words, in the messages generated by the test
case, no message should appear whose tags are in the listed tags.

The C<forbid> keyword can be used more than once in a scenario. All of the
checks specified by C<expect> and C<forbid> keywords must pass in order for
the scenario to pass.

=cut

sub forbid (@) {
    my @tags = @_;

    croak "Need at least one argument" unless scalar @tags >= 1;

    foreach my $tag (@_) {
        _declare_forbid( $tag );
    }
}

sub _declare_forbid {
    my ($tag) = @_;
    my @context = caller(1);

    _ensure_tag_is_declared( $tag, 'forbid' );
    delete STATE->{not_forbidden}{$tag};
    push @{STATE->{forbid}}, { tag => $tag, caller => [ @context[1..2] ] };
}

=head2 expect_others

    expect_others;

Specifies that all tags not listed by any C<forbid> tag in the scenario
definition must appear in the test case’s output for the scenario.

=cut

sub expect_others () {
    croak "Cannot use expect_others if forbid_others is already given" if STATE->{forbid_others};
    croak "Cannot use expect_others more than once" if STATE->{expect_others};
    STATE->{expect_others} = 1;

    _declare_expect( $_ ) foreach ( keys %{STATE->{not_forbidden}} );
}

=head2 forbid_others

    forbid_others;

Specifies that all tags not listed by any C<expect> tag in the scenario
definition must not appear in the test case’s output for the scenario.

=cut

sub forbid_others () {
    croak "Cannot use forbid_others if expect_others is already given" if STATE->{expect_others};
    croak "Cannot use forbid_others more than once" if STATE->{forbid_others};
    STATE->{forbid_others} = 1;

    _declare_forbid( $_ ) foreach ( keys %{STATE->{not_expected}} );
}

=head2 not_testable

    not_testable 'optional reason';

Mark the scenario as not testable.

Scenarios marked as not testable are skipped during testing, unless they are
listed explicitly in the C<ZONEMASTER_SELECTED_SUBTESTS> environment variable.

It is semantically equivalent to L<Test::More#todo_skip>.

This facility is useful for defining scenarios which cannot be tested because
the infrastructure (e.g. DNS servers, test zones…) needed to elicit the set of
messages expected by the scenario is not yet available.

No packets related to the scenario are saved to the test’s C<.data> file when
C<ZONEMASTER_RECORD> is set in the environment. This means that no data is
recorded for a test zone that does not reflect the scenario accurately.
Rerecording is only necessary when the C<not_testable> keyword is removed.

The C<not_testable> keyword should not be used for other reasons than lack of
infrastructure, such as if the test fails because of a known bug in the test
case’s implementation. In those situations, C<todo> is more appropriate.

The optional reason, if supplied, is used in the test harness’s diagnostic
output. It is useful for documenting the exact reason why the test is not
testable, for example by referring to an item on an issue tracker.

=cut

sub not_testable (;$) {
    if (exists STATE->{todo}) {
        croak "'not_testable' cannot be combined with 'todo'";
    }
    if (exists STATE->{not_testable}) {
        croak "'not_testable' can only be given once";
    }
    STATE->{status} = [ 'not_testable', $_[0] ];
}

=head2 todo

    todo 'optional reason';

Mark the scenario as “to do”.

Scenarios marked as to do are executed normally during testing, but are
expected to fail. Failing “to do” scenarios do not cause the parent test suite
to fail.

It is semantically equivalent to L<Test::More#TODO:-BLOCK>.

This facility is useful for defining scenarios that are expected to fail
because of a known bug in the test case’s implementation that has not been
fixed yet.

Packets related to the scenario are saved to the test’s C<.data> file when
C<ZONEMASTER_RECORD> is set in the environment. This means that no rerecord is
necessary when the C<todo> keyword is removed or when trying to fix the
implementation.

The optional reason, if supplied, is used in the test harness’s diagnostic
output. It is useful for documenting the exact reason why the test is expected
to fail, for example by referring to an item on an issue tracker.

=cut

sub todo (;$) {
    if (exists STATE->{not_testable}) {
        croak "'todo' cannot be combined with 'not_testable'";
    }
    if (exists STATE->{todo}) {
        croak "'todo' can only be given once";
    }
    STATE->{status} = [ 'todo', $_[0] ];
}

1;
