package JSON::Regex;
use strict;
use warnings;
use v5.10;
use re 'eval';
use Carp;

sub import {
    shift;
    no strict 'refs';
    my $caller = caller;
    *{"$caller\::json_regex_parser"} = \&{"JSON::Regex::json_regex_parser"};
}

my $json_base_regex = qr{
    (?(DEFINE)
        (?<json_value>
                VALUE_STRING_PATTERN VALUE_STRING_ACTION
            |
                VALUE_NUMBER_PATTERN VALUE_NUMBER_ACTION
            |
                true VALUE_TRUE_ACTION
            |
                false VALUE_FALSE_ACTION
            |
                null VALUE_NULL_ACTION
            |
                (?&json_array)
            |
                (?&json_object)
        )

        (?<json_string>
            (?> (?: [^"\\]++ | (?: \\["\\/bfnrt] | \\u[0-9a-fA-F]{4} ) )* )
        )

        (?<json_number>
            (?>
               [-]? (?: 0 | [1-9] [0-9]*  )
                    (?: \. [0-9]+         )?    (?# fraction)
                    (?: [eE] [-+]? [0-9]+ )?    (?# exponent)
            )
        )

        (?<json_array>
            (?>
            \[ \s*
            
            ARRAY_INIT

            (?:
                (?&json_value) \s* ARRAY_VALUE_ACTION
                
                (?: ,
                    \s* (?&json_value) \s* ARRAY_VALUE_ACTION
                )*
            )?
            \]
            )
        )

        (?<json_object>
            (?>
            \{ \s*

            OBJECT_INIT
            
            (?:
                OBJECT_STRING_PATTERN \s* OBJECT_STRING_ACTION
                
                : \s* (?&json_value) \s* OBJECT_VALUE_ACTION

                (?: ,
                    \s* OBJECT_STRING_PATTERN \s* OBJECT_STRING_ACTION
                
                    : \s* (?&json_value) \s* OBJECT_VALUE_ACTION
                )*
            )?
            \}
            )
        )
    )
}x;

our $definition = $json_base_regex
    =~ s/VALUE_STRING_PATTERN/"(?&json_string)"/r
    =~ s/VALUE_STRING_ACTION//r
    =~ s/VALUE_NUMBER_PATTERN/(?&json_number)/r
    =~ s/VALUE_NUMBER_ACTION//r
    =~ s/VALUE_TRUE_ACTION//r
    =~ s/VALUE_FALSE_ACTION//r
    =~ s/VALUE_NULL_ACTION//r

    =~ s/ARRAY_INIT//r
    =~ s/ARRAY_VALUE_ACTION//gr

    =~ s/OBJECT_INIT//r
    =~ s/OBJECT_STRING_PATTERN/"(?&json_string)"/gr
    =~ s/OBJECT_STRING_ACTION//gr
    =~ s/OBJECT_VALUE_ACTION//gr
;    

our $match = qr{ ((?&json_value)) $JSON::Regex::definition }x;

sub indent {
    my ($level, $string) = @_;
    my $indent = " " x (4 * $level);
    $string =~ s/^/$indent/mgr
}

sub heredoc {
    my ($level, $string) = @_;
    my $indent = " " x (4 * $level);
    $string =~ s/^$indent//mgr
}

our @stack;
our $sp;

sub make_regex {
    my ($ref, %args) = @_;
    my %opt;
    my ($true_action, $false_action, $null_action, $number_action, $string_action);

    for (qw(true false null number string)) {
        if (!defined $args{$_}) {
            croak "parameter '$_': undefined value"
        }
        elsif ($args{$_} eq "raw") { # default

            $opt{$_} = heredoc 3, q{
            (?{
                $stack[$sp] = $^N;
                local $sp = $sp+1;
            })
            };
        }
        elsif ($args{$_} eq "object") {

            if ($_ eq "number" || $_ eq "string") {

                $opt{$_} = heredoc 4, qq{
                (?{
                    \$stack[\$sp] = do { my \$o = \$^N; bless \\\$o, "JSON::Regex::$_" };
                    local \$sp = \$sp+1;
                })
                };
            }
            else {
                $opt{$_} = heredoc 4, qq{
                (?{
                    \$stack[\$sp] = do { my \$o; bless \\\$o, "JSON::Regex::$_" };
                    local \$sp = \$sp+1;
                })
                };
            }
        }
        elsif ($args{$_} =~ /^\s*CODE\s*:/) {
            
            my $code = indent(2, $args{$_} =~ s/^\s*CODE\s*://r);

            $opt{$_} = heredoc 3, qq{
            (?{
                \$stack[\$sp] = do {
            $code
                };
                local \$sp = \$sp+1;
            })
            };
        }
        elsif (ref $args{$_} eq "CODE") {

            if ($_ eq "string") {
                $string_action = $args{$_};
            }
            elsif ($_ eq "number") {
                $number_action = $args{$_};
            }
            elsif ($_ eq "true") {
                $true_action = $args{$_};
            }
            elsif ($_ eq "false") {
                $false_action = $args{$_};
            }
            elsif ($_ eq "null") {
                $null_action = $args{$_};
            }

            $opt{$_} = heredoc 3, qq{
            (?{
                \$stack[\$sp] = \$${_}_action->(\$^N);
                local \$sp = \$sp+1;
            })
            };
        }
        elsif ($_ eq "number" && $args{number} eq "numify") {

            $opt{number} = heredoc 3, q{
            (?{
                $stack[$sp] = 0+$^N;
                local $sp = $sp+1;
            })
            };
        }
        elsif ($_ eq "string" && $args{string} eq "interpolate") {

            $opt{string} = heredoc 3, q{
            (?{
                $stack[$sp] = $^N
                =~ s/\\b/\b/gr
                =~ s/\\f/\f/gr
                =~ s/\\n/\n/gr
                =~ s/\\r/\r/gr
                =~ s/\\t/\t/gr;
                local $sp = $sp+1;
            })
            };
        }
        else {
            croak "parameter '$_': unrecognized value '$args{$_}'"
        }
    }

    my $object_init;

    if (defined $args{object} && $args{object} eq "ordered") {
        require Tie::IxHash;
        Tie::IxHash->import;
        $object_init = q/(?{ tie my %obj, "Tie::IxHash"; $stack[$sp] = \%obj; local $sp = $sp+1; })/;
    }
    else {
        $object_init = q/(?{ $stack[$sp] = {}; local $sp = $sp+1; })/;
    }

    my $array_value_action = heredoc 1, q{
    (?{
        push $stack[$sp-2]->@*,
        $stack[$sp-1];
        local $sp = $sp-1;
    })
    };

    my $object_string_action = heredoc 1, q{
    (?{
        $stack[$sp] = $^N;
        local $sp = $sp+1;
    })
    };

    my $object_value_action = heredoc 1, q{
    (?{
        $stack[$sp-3]->{$stack[$sp-2]} = $stack[$sp-1];
        local $sp = $sp-2;
    })
    };

    my $regex =
    q{
        ^ \s*

        (?{
            local @stack;
            local $sp = 0;
        })
 
        (?&json_value)

        (?{
            $$ref = $stack[0];
            @stack = ();
        })

        \s* $
    }
    .
    $json_base_regex
    =~ s/VALUE_STRING_PATTERN/"((?&json_string))"/r
    =~ s/VALUE_STRING_ACTION/ indent(4, $opt{string})/re

    =~ s/VALUE_NUMBER_PATTERN/((?&json_number))/r
    =~ s/VALUE_NUMBER_ACTION/ indent(4, $opt{number})/re

    =~ s/VALUE_TRUE_ACTION/   indent(4, $opt{true})  /re
    =~ s/VALUE_FALSE_ACTION/  indent(4, $opt{false}) /re
    =~ s/VALUE_NULL_ACTION/   indent(4, $opt{null})  /re

    =~ s/ARRAY_INIT/(?{ \$stack[\$sp] = []; local \$sp = \$sp+1; })/r
    =~ s/ARRAY_VALUE_ACTION/ indent(4, $array_value_action)/re
    =~ s/ARRAY_VALUE_ACTION/ indent(5, $array_value_action)/re

    =~ s/OBJECT_INIT/$object_init/r
    =~ s/OBJECT_STRING_PATTERN/"((?&json_string))"/gr
    =~ s/OBJECT_STRING_ACTION/ indent(4, $object_string_action)/re
    =~ s/OBJECT_STRING_ACTION/ indent(5, $object_string_action)/re
    =~ s/OBJECT_VALUE_ACTION/  indent(4, $object_value_action) /re
    =~ s/OBJECT_VALUE_ACTION/  indent(5, $object_value_action) /re
;    

    eval q{qr/$regex/x};
}

sub json_regex_parser {
    my $ref = shift;
    if (!defined $ref || ref $ref ne "SCALAR") {
        croak "JSON::Regex::json_regex_parser() argument is not a SCALAR reference"
    }

    make_regex($ref,
        true    => "raw",
        false   => "raw",
        null    => "raw",
        number  => "raw",
        string  => "raw",
        @_
    );
}



1;
