#!/usr/bin/perl

use strict;
use warnings;
use v5.10;
use lib "../";
use JSON::Regex;
use Data::Dumper;
$Data::Dumper::Sortkeys=1; # comment this when testing hash => "ordered"
$Data::Dumper::Indent = 1;

my $file = shift // exit;

local $/;
open my $fh, "<", $file;
$file = <$fh>;
close $fh;

my $json;
# the generated regex closes over a reference to the output variable
my $json_parser = json_regex_parser(\$json);


# VARIOUS OPTIONS TESTED HERE
# my $json_parser = json_regex_parser(\$json, hash => "ordered");
# my $json_parser = json_regex_parser(\$json,
#     true => "object", false => "object", null => "object"
# );
# my $json_parser = json_regex_parser(\$json, number => "object");
# my $json_parser = json_regex_parser(\$json, string => "object");

my $code = q{CODE:
say "got string '$^N'";
my $o = $^N;
bless \$o, "String";
};

my $string_action = sub {
    my $string = shift;
    say "got string '$string'";
    my $o = $string;
    bless \$o, "String";
};

my $number_action = sub {
    my $number = shift;
    say "got number '$number'";
    my $o = 0+$number;
    bless \$o, "Number";
};


# my $json_parser = json_regex_parser(\$json, string => $code);
# my $json_parser = json_regex_parser(\$json, string => $code, number => "numify");
# my $json_parser = json_regex_parser(\$json, string => "interpolate", number => "numify");
#
# my $json_parser = json_regex_parser(\$json, string => $string_action, number => $number_action);



# say $json_parser;

if ($file =~ $json_parser) {
    say Dumper $json;
    say "match"
}
else {
    say "fail"
}



