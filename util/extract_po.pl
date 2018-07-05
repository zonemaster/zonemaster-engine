#!/usr/bin/env perl
use 5.14.2;
use strict;
use warnings;

use Zonemaster::Engine::Translator;

# Let Zonemaster::Engine extract its own messages
my $data = Zonemaster::Engine::Translator->new->data;

# Determine msgid order and the tags of each msgid
my @msgids;
my %tags;
for my $module ( sort keys %{$data} ) {
    next if ref( $data->{$module} ) ne 'HASH';
    for my $message ( sort keys %{ $data->{$module} } ) {
        my $msgid = $data->{$module}{$message};
        my $tag   = "$module:$message";
        push @msgids, $msgid if !exists $tags{$msgid};    # register first occurrance of each msgid
        push @{ $tags{$msgid} }, $tag;
    }
}

# Print prelude
print<<'PRELUDE';
msgid  ""
msgstr ""
"Project-Id-Version: 0.0.4\n"
"PO-Revision-Date: 2014-08-28\n"
"Last-Translator: calle@init.se\n"
"Language-Team: Zonemaster Team\n"
"Language: en\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=utf-8\n"
"Content-Transfer-Encoding: 8bit\n"

PRELUDE

# Print messages
for my $msgid ( @msgids ) {
    my $msgid_esc = ( $msgid =~ s/\"/\\"/gr );
    my $tag_string = join " ", @{ $tags{$msgid} };
    printf qq[#: %s\n],         $tag_string;
    printf qq[msgid  "%s"\n],   $msgid_esc;
    printf qq[msgstr "%s"\n\n], $msgid_esc;
}
