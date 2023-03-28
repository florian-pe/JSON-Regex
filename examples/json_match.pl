#!/usr/bin/perl

use strict;
use warnings;
use v5.10;
use lib "../";
use JSON::Regex;

my $file = shift // exit;

local $/;
open my $fh, "<", $file;
$file = <$fh>;
close $fh;

# say $JSON::Regex::match;

if ($file =~ / ^ $JSON::Regex::match $ /x) {
    say "match"
}
else {
    say "fail"
}



