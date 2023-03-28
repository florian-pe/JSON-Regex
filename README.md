# JSON::Regex

A module for matching and parsing JSON strings with perl regexes.

The regex `$JSON::Regex::match` can be used to match JSON strings while the variable `$JSON::Regex::definition` can be interpolated inside a regex to access the various sub-rules constituting a JSON.

These rules are:
`(?&json_value), (?&json_number), (?&json_string), (?&json_array), (?&json_object)`


The subroutine `json_regex_parser()` can be used to generate a customized regex to parse a JSON string.
This subroutine takes a SCALAR reference as first parameter that will be closed over the regex, so that the regex engine can store the parse tree when a match/parse succeeded.

The various options can be used to decide what to store when encountering a base value (true, false, null, number, string) in order to differentiate them.

The different options
- "raw"

    Store the raw string of the JSON value. In the case of JSON strings, the double quotes are not included.

- "numify"

    Numify numbers with `0+`.

- "object"

    Store a blessed SCALAR reference with the package name being (JSON::Regex::true/false/null/number/string).

- CODE ref

    Call the specified CODE ref with the raw string value as argument and store the returning value.

- inlined code string

    Same as above except that the code is inlined. The argument is a string containing arbitrary perl code, prefixed with "CODE:". The inlined code will be enclosed in a `do` block. Since this is not a function call, the code will have to obtain the raw value directly from `$^N`.
 
- interpolate

    Substitute the backslash sequences (`\b`, `\f`, `\n`, `\r`, `\t`) in string values (not object keys) by their corresponding ascii characters.

- "ordered"

    Use `Tie::IxHash` for storing json objects instead of a regular perl hash in order to conserver the order of key/value pairs. This particular option was the main motivation for making this regex JSON parser.


The following shows the different parameters and their possible values.

- true, false, null
    - "raw" (default)
    - "object"
    - CODE ref
    - inlined code string
- number
    - "raw" (default)
    - "object"
    - CODE ref
    - inlined code string
    - "numify"
- string
    - "raw" (default)
    - "object"
    - CODE ref
    - inlined code string
    - "interpolate"
- object
    - undef (use a regular perl hash)
    - "ordered"

