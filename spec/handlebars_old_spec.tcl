lappend auto_path [file join [file dirname [info script]] ".."]
lappend auto_path [file join [file dirname [info script]] ".." ".." "tclspec"]

package require spec/autorun



namespace eval Handlebars {
    # Tokens returned by the lexer are simple dicts with the following keys:
    # - type:
    # - value:
    # - line:
    # - column:
    namespace eval Lexer {
        proc initialize { str } {
            return [list template $str state "" column 0 line 0]
        }

        proc read_token { lexer_var } {
            upvar $lexer_var lexer

            set template [dict get $lexer template]
            set state [dict get $lexer state]

            set open "{{"
            set close "}}"

            if { $state != "mu" } {
                if { [regexp -indices {^[^\x00]*?(?=\{\{)} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]

                    dict set lexer state "mu"

                    return [list CONTENT $value]
                } elseif { [regexp -indices {^[^\x00]+} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]

                    return [list CONTENT $value]
                }
            } elseif { $state == "mu" } {
                if { [regexp -indices {^\{\{>} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "OPEN_PARTIAL" $value]
                } elseif { [regexp -indices {^\{\{#} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "OPEN_BLOCK" $value]
                } elseif { [regexp -indices {^\{\{/} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "OPEN_ENDBLOCK" $value]
                } elseif { [regexp -indices {^\{\{\^} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "OPEN_INVERSE" $value]
                } elseif { [regexp -indices {^\{\{\s*else} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "OPEN_INVERSE" $value]
                } elseif { [regexp -indices {^\{\{\{} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "OPEN_UNESCAPED" $value]
                } elseif { [regexp -indices {^\{\{\&} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "OPEN_UNESCAPED" $value]
                } elseif { [regexp -indices {^\{\{} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "OPEN" $value]
                } elseif { [regexp -indices {^=} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "EQUALS" $value]
                } elseif { [regexp -indices {^\.(?=[\} ])} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "ID" $value]
                } elseif { [regexp -indices {^\.\.} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "ID" $value]
                } elseif { [regexp -indices {^[\/\.]} $template match]} {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "SEP" $value]
                } elseif { [regexp -indices {^\s+} $template match]} {
                    # Ignore whitespace
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                } elseif { [regexp -indices {^\}\}\}} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    dict set lexer state ""
                    return [list "CLOSE" $value]
                } elseif { [regexp -indices {^\}\}} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    dict set lexer state ""
                    return [list "CLOSE" $value]
                } elseif { [regexp -indices {^true(?=[\}\s])} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "BOOLEAN" $value]
                } elseif { [regexp -indices {^false(?=[\}\s])} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "BOOLEAN" $value]
                } elseif { [regexp -indices {^[0-9]+(?=[\}\s])} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "INTEGER" $value]
                } elseif { [regexp -indices {^[a-zA-Z0-9_$-]+(?=[=\}\s\/\.])} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "ID" $value]
                } elseif { [regexp -indices {^\[[^\]]*\]} $template match] } {
                    set value [string range $template [lindex $match 0]+1 [lindex $match 1]-1]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "ID" $value]
                } elseif { [regexp -indices {.} $template match] } {
                    set value [string range $template [lindex $match 0] [lindex $match 1]]
                    dict set lexer template [string range $template [lindex $match 1]+1 end]
                    return [list "INVALID" $value]
                }
            }

            if { $template == "" } {
                return [list "EOF"]
            }

            # If we haven't returned, just try again
            read_token lexer
        }
    }

    proc render { template context } {
        set compiled_template [compile $template]
        apply [lindex $compiled_template 0] $context
    }

    proc compile { template } {
        set state [list peek_token {} cur_token {} lexer [Handlebars::Lexer::initialize $template] output {}]

        handle_root state

        return [join [dict get $state output] "\n"]
    }

    proc handle_root { state_var } {
        upvar $state_var state

        while { true } {
            set peek_token [try_peek_token state]
            if { [lindex $peek_token 0] != "EOF" } {
                handle_program state
            } else {
                break
            }
        }
    }

    # Returns a list of the following structure: { { path params... } { ...options_hash... } }
    proc handle_in_mustache { state_var } {
        upvar $state_var state

        set params [handle_path state]

        set peek_token [try_peek_token state]
        while { [lindex $peek_token 0] == "ID" } {
            assert_type [next_token state] "ID"

            set peek_token [peek_token state]

            if { [lindex $peek_token 0] != "EQUALS" } {
                lappend params [token_value state]
            }
        }

        set hash [list]

        if { [lindex [peek_token state] 0] == "EQUALS" } {
            lappend hash [token_value state]
            assert_type [next_token state] "EQUALS"
            lappend hash [handle_path state]
        }

        while { [lindex [peek_token state] 0] == "ID" } {
            assert_type [next_token state] "ID"
            lappend hash [token_value state]
            assert_type [next_token state] "EQUALS"
            lappend hash [handle_path state]
        }

        return [list $params $hash]
    }

    proc handle_path { state_var } {
        upvar $state_var state

        set segments [list]

        assert_type [next_token state] "ID"
        lappend segments [lindex [dict get $state cur_token] 1]

        set peek_token [try_peek_token state]
        while { [lindex $peek_token 0] == "SEP" } {
            assert_type [next_token state] "SEP"
            assert_type [next_token state] "ID"
            lappend segments [lindex [dict get $state cur_token] 1]
        }

        return $segments
    }

    proc handle_program { state_var } {
        upvar $state_var state

        dict lappend state output "{{ context } {"
        dict lappend state output "  set output \[list]"

        set inverse false
        set statements [list]
        set inverse_statements [list]

        while { true } {
            set peek_token [try_peek_token state]
            set type [lindex $peek_token 0]

            if { $type == "OPEN_INVERSE" } {
                handle_simple_inverse_block state
                set inverse true
            } elseif { $type in {"CONTENT" "COMMENT" "OPEN" "OPEN_UNESCAPED" "OPEN_BLOCK"} } {
                if { $inverse == false } {
                    lappend statements [handle_statement state]
                } else {
                    lappend inverse_statements [handle_statement state]
                }
            } else {
                break
            }
        }

        dict lappend state output "  return \[join \$output \"\"]"
        dict lappend state output "}}"
    }

    # lappend $output [call_helper "with" {{context} {
    #     set output
    # }} {{context} {}}]

    proc handle_statement { state_var } {
        upvar $state_var state

        set peek_token [dict get $state peek_token]

        if { [lindex $peek_token 0] in {"OPEN" "OPEN_UNESCAPED"} } {
            return [handle_mustache state]
        } elseif { [lindex $peek_token 0] in {"OPEN_BLOCK"} } {
            return [handle_block state]
        } elseif { [lindex $peek_token 0] in {"CONTENT"} } {
            assert_type [next_token state] "CONTENT"
            dict lappend state output "  lappend output {[lindex [dict get $state cur_token] 1]}\n"
            return [list CONTENT_NODE]
        }
    }

    proc handle_simple_inverse_block { state_var } {
        upvar $state_var state

        dict lappend state output "\}\} \{\{context\} \{"
        dict lappend state output "  set output \[list]"
        assert_type [next_token state] "OPEN_INVERSE"
        assert_type [next_token state] "CLOSE"
    }

    proc handle_open_inverse_block { state_var } {
        upvar $state_var state

        assert_type [next_token state] "OPEN_INVERSE"
        handle_in_mustache state
        dict lappend state output "(begin inverse block: [lindex [dict get $state cur_token] 1])"
        assert_type [next_token state] "CLOSE"
    }

    proc handle_open_block { state_var } {
        upvar $state_var state

        assert_type [next_token state] "OPEN_BLOCK"

        set helper [handle_in_mustache state]
        dict lappend state output "lappend output \[call_helper {$helper} \$context \\"

        assert_type [next_token state] "CLOSE"
    }

    proc handle_close_block { state_var } {
        upvar $state_var state

        assert_type [next_token state] "OPEN_ENDBLOCK"
        set path [handle_path state]
        dict lappend state output "\]"
        assert_type [next_token state] "CLOSE"
        return $path
    }

    proc handle_block { state_var } {
        upvar $state_var state

        handle_open_block state

        handle_program state

        handle_close_block state
    }

    proc handle_mustache { state_var } {
        upvar $state_var state

        assert_type [next_token state] "OPEN" "OPEN_UNESCAPED"
        set escaped [expr { [lindex [dict get $state cur_token] 0] == "OPEN" }]

        assert_type [next_token state] "ID"

        if { $escaped } {
            dict lappend state output "  lappend output \[escape_html \[find_name {[lindex [dict get $state cur_token] 1]} \$context]]"
        } else {
            dict lappend state output "  lappend output \[find_name {[lindex [dict get $state cur_token] 1]} \$context]"
        }
        assert_type [next_token state] "CLOSE"
    }

    proc assert_type { token args } {
        if { !([lindex $token 0] in $args) } {
            error "Found $token, expected [join $args ", "]"
        }
    }

    proc token { state_var } {
        upvar $state_var state

        if { [dict get $state cur_token] == {} } {
            error "unexpected end of input"
        }

        dict get $state cur_token
    }

    proc token_value { state_var } {
        upvar $state_var state
        lindex [token state] 1
    }

    proc next_token { state_var } {
        upvar $state_var state
        set lexer [dict get $state lexer]

        if { [dict get $state peek_token] != {} } {
            dict set state cur_token [dict get $state peek_token]
        } else {
            dict set state cur_token [Handlebars::Lexer::read_token lexer]
        }

        dict set state peek_token {}
        dict set state lexer $lexer

        dict get $state cur_token
    }

    proc peek_token { state_var } {
        upvar $state_var state
        set lexer [dict get $state lexer]

        if { [dict get $state peek_token] == {} } {
            dict set state peek_token [Handlebars::Lexer::read_token lexer]
        }

        dict set state lexer $lexer

        if { [dict get $state peek_token] == {} } {
            error "unexpected end of input"
        }
        dict get $state peek_token
    }

    proc try_peek_token { state_var } {
        upvar $state_var state
        set lexer [dict get $state lexer]

        if { [dict get $state peek_token] == {} } {
            dict set state peek_token [Handlebars::Lexer::read_token lexer]
        }

        dict set state lexer $lexer

        dict get $state peek_token
    }
}

#puts [Handlebars::render "yay {{mustache}} {{{triple_mustache}}} {{#with}} {{mustache}} {{else}} asdfasdf {{/with}}"]

namespace eval Handlebars {
    variable escape_map {
        "&"     "&amp;"
        "<"     "&lt;"
        ">"     "&gt;"
        "\""    "&quot;"
        "'"     "&#39;"
    }
}

proc escape_html { html } {
    subst [regsub -all {&(?!\w+;)|[<>"']} $html \
                {[ expr { [dict exists $::Handlebars::escape_map {&}] ? [dict get $::Handlebars::escape_map {&}] : {&} } ]}]
}

proc exists_name { name context } {
    if { $name == "." } {
        return true
    }

    dict exists $context $name
}

proc find_name { name context } {
    if { $name == "." } {
        return $context
    } elseif { [dict exists $context $name] } {
        return [dict get $context $name]
    } else {
        return ""
    }
}

proc call_helper { helper context block {inverse {{context} {}}} } {
    set name [lindex [lindex $helper 0] 0]
    set params [lrange [lindex $helper 0] 1 end]
    set hash_params [lindex $helper 1]

    if { $name == "if" } {
        if { [exists_name [lindex $params 0] $context] && ![string is false [find_name [lindex $params 0] $context]] } {
            return [apply $block $context]
        } else {
            return [apply $inverse $context]
        }
    } else {
        puts "Unknown helper: $name"
        return ""
    }

    puts $name
    puts $params
    puts $hash_params

    puts $context

    return ""
}

puts [Handlebars::compile "{{#if goodbye}}GOODBYE {{/goodbye}}cruel {{world}}!"]

# puts [time {
#     apply [lindex "{{} { expr { 1 + 1 }}}" 0]
# } 1000]


# puts [Handlebars::compile "yay {{mustache}} {{{triple_mustache}}} {{#with asdf abc asdf a = b c = d}} {{mustache}} {{else}} asdfasdf {{/with}}"]


# puts [apply [lindex [Handlebars::compile "yay {{mustache}} {{{triple_mustache}}} {{#with}} {{mustache}} {{else}} asdfasdf {{/with}}"] 0] {
#     mustache "It works!"
#     triple_mustache "<b>It Works!</b>"
# }]


describe "Handlebars::render" {
    it "compiling with a basic context" {
        expect [
            Handlebars::render "Goodbye\n{{cruel}}\n{{world}}!" { cruel "cruel" world "world" }
        ] to equal "Goodbye\ncruel\nworld!"
    }

    it "comments" {
        expect [
            Handlebars::render "{{! Goodbye}}Goodbye\n{{cruel}}\n{{world}}!" { cruel "cruel" world "world" }
        ] to equal "Goodbye\ncruel\nworld!"
    }

    it "booleans" {
        expect [
            Handlebars::render "{{#if goodbye}}GOODBYE {{/goodbye}}cruel {{world}}!" { goodbye true world "world" }
        ] to equal "GOODBYE cruel world!"

        expect [
            Handlebars::render "{{#if goodbye}}GOODBYE {{/goodbye}}cruel {{world}}!" { goodbye false world "world" }
        ] to equal "cruel world!"
    }

    it "zeros" {
        expect [
            Handlebars::render "num1: {{num1}}, num2: {{num2}}" { num1 42 num2 0 }
        ] to equal "num1: 42, num2: 0"

        expect [
            Handlebars::render "num: {{.}}" 0
        ] to equal "num: 0"

        expect [
            Handlebars::render "num: {{num1/num2}}" [list num1 [list num2 0]]
        ] to equal "num: 0"
    }

    it "newlines" {
        expect [
            Handlebars::render "{{#if goodbye}}GOODBYE {{/goodbye}}cruel {{world}}!" { goodbye false world "world" }
        ] to equal "GOODBYE cruel world!"
    }
}

describe "Mustache::Lexer" {
    proc tokenize { template } {
        set lexer [Handlebars::Lexer::initialize $template]

        set tokens [list]
        while { [set token [Handlebars::Lexer::read_token lexer]] != "EOF" && [lindex $token 0] != "INVALID" } {
            if { $token != {} && [lindex $token 0] != "CONTENT" || [lindex $token 1] != "" } {
                lappend tokens $token
            }
        }
        return $tokens
    }

    proc map_to_types { tokens } {
        set types [list]
        foreach token $tokens {
            lappend types [lindex $token 0]
        }
        return $types
    }

    it "tokenizes a simple mustache as 'OPEN ID CLOSE'" {
        set tokens [tokenize "{{foo}}"]
        expect [map_to_types $tokens] to equal [list OPEN ID CLOSE]
    }

    # it "supports escaping delimiters" {
    #     set tokens [tokenize "{{foo}} \\{{bar}} {{baz}}"]
    #     expect [map_to_types $tokens] to equal [list OPEN ID CLOSE CONTENT CONTENT OPEN ID CLOSE]
    #     expect [lindex $tokens 4] to equal [list "CONTENT" "{{bar}}"]
    # }

    # it "supports escaping a triple stash"{
    #     set tokens [tokenize "{{foo}} \\{{{bar}}} {{baz}}"]
    #     expect [map_to_types $tokens] to equal [list OPEN ID CLOSE CONTENT CONTENT OPEN ID CLOSE]
    #     expect [lindex $tokens 4] to equal [list "CONTENT" "{{{bar}}}"]
    # }

    it "tokenizes a simple path" {
        set tokens [tokenize "{{foo/bar}}"]
        expect [map_to_types $tokens] to equal [list OPEN ID SEP ID CLOSE]
    }

    it "allows dot notation" {
        set tokens [tokenize "{{foo.bar}}"]
        expect [map_to_types $tokens] to equal [list OPEN ID SEP ID CLOSE]
    }

    it "allows path literals with \[]" {
        set tokens [tokenize "{{foo.\[bar]}}"]
        expect [map_to_types $tokens] to equal [list OPEN ID SEP ID CLOSE]
        expect [lindex $tokens 3] to equal [list "ID" "bar"]
    }

    it "allows multiple path literals on a line with \[]" {
        set tokens [tokenize "{{foo.\[bar]}}{{foo.\[baz]}}"]
        expect [map_to_types $tokens] to equal [list OPEN ID SEP ID CLOSE OPEN ID SEP ID CLOSE]
    }

    it "tokenizes {{.}} as OPEN ID CLOSE" {
        set tokens [tokenize "{{.}}"]
        expect [map_to_types $tokens] to equal [list OPEN ID CLOSE]
    }

    it "tokenizes a path as 'OPEN (ID SEP)* ID CLOSE'" {
        set tokens [tokenize "{{../foo/bar}}"]
        expect [map_to_types $tokens] to equal [list OPEN ID SEP ID SEP ID CLOSE]
        expect [lindex $tokens 1] to equal [list "ID" ".."]
    }

    it "tokenizes a path with .. as a parent path" {
        set tokens [tokenize "{{../foo.bar}}"]
        expect [map_to_types $tokens] to equal [list OPEN ID SEP ID SEP ID CLOSE]
        expect [lindex $tokens 1] to equal [list "ID" ".."]
    }

    it "tokenizes a path with this/foo as OPEN ID SEP ID CLOSE" {
        set tokens [tokenize "{{this/foo}}"]
        expect [map_to_types $tokens] to equal [list OPEN ID SEP ID CLOSE]
        expect [lindex $tokens 1] to equal [list "ID" "this"]
        expect [lindex $tokens 3] to equal [list "ID" "foo"]
    }

    it "tokenizes a simple mustache with spaces as 'OPEN ID CLOSE'" {
        set tokens [tokenize "{{  foo  }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID CLOSE]
        expect [lindex $tokens 1] to equal [list "ID" "foo"]
    }

    it "tokenizes a simple mustache with line breaks as 'OPEN ID ID CLOSE'" {
        set tokens [tokenize "{{  foo  \n   bar }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID ID CLOSE]
        expect [lindex $tokens 1] to equal [list "ID" "foo"]
    }

    it "tokenizes raw content as 'CONTENT'" {
        set tokens [tokenize "foo {{ bar }} baz"]
        expect [map_to_types $tokens] to equal [list CONTENT OPEN ID CLOSE CONTENT]
        expect [lindex $tokens 0] to equal [list "CONTENT" "foo "]
        expect [lindex $tokens 4] to equal [list "CONTENT" " baz"]
    }

    it "tokenizes a partial as 'OPEN_PARTIAL ID CLOSE'" {

    }

    it "tokenizes a partial with context as 'OPEN_PARTIAL ID ID CLOSE'" {

    }

    it "tokenizes a partial without spaces as 'OPEN_PARTIAL ID CLOSE'" {

    }

    it "tokenizes a partial space at the end as 'OPEN_PARTIAL ID CLOSE'" {

    }

    it "tokenizes a comment as 'COMMENT'" {

    }

    it "tokenizes open and closing blocks as 'OPEN_BLOCK ID CLOSE ... OPEN_ENDBLOCK ID CLOSE'" {

    }

    it "tokenizes inverse sections as 'OPEN_INVERSE CLOSE'" {

    }

    it "tokenizes inverse sections with ID as 'OPEN_INVERSE ID CLOSE'" {

    }

    it "tokenizes inverse sections with ID and spaces as 'OPEN_INVERSE ID CLOSE'" {

    }

    it "tokenizes mustaches with params as 'OPEN ID ID ID CLOSE'" {

    }

    it "tokenizes mustaches with String params as 'OPEN ID ID STRING CLOSE'" {

    }

    it "tokenizes String params with spaces inside as 'STRING'" {

    }

    it "tokenizes String params with escapes quotes as 'STRING'" {

    }

    it "tokenizes numbers" {
        set tokens [tokenize "{{ foo 1 }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID INTEGER CLOSE]
        expect [lindex $tokens 2] to equal [list "INTEGER" "1"]
    }

    it "tokenizes booleans" {
        set tokens [tokenize "{{ foo true }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID BOOLEAN CLOSE]
        expect [lindex $tokens 2] to equal [list "BOOLEAN" "true"]

        set tokens [tokenize "{{ foo false }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID BOOLEAN CLOSE]
        expect [lindex $tokens 2] to equal [list "BOOLEAN" "false"]
    }

    it "tokenizes hash arguments" {
        set tokens [tokenize "{{ foo bar=baz }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID ID EQUALS ID CLOSE]

        set tokens [tokenize "{{ foo bar baz=bat }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID ID ID EQUALS ID CLOSE]

        set tokens [tokenize "{{ foo bar baz=1 }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID ID ID EQUALS INTEGER CLOSE]

        set tokens [tokenize "{{ foo bar baz=true }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID ID ID EQUALS BOOLEAN CLOSE]

        set tokens [tokenize "{{ foo bar baz=false }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID ID ID EQUALS BOOLEAN CLOSE]

        set tokens [tokenize "{{ foo bar\n  baz=bat }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID ID ID EQUALS ID CLOSE]

        set tokens [tokenize "{{ foo bar baz=\"bat\" }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID ID ID EQUALS STRING CLOSE]

        set tokens [tokenize "{{ foo bar baz=\"bat\" bam=wot }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID ID ID EQUALS STRING ID EQUALS ID CLOSE]

        set tokens [tokenize "{{foo omg bar=baz bat=\"bam\"}}"]
        expect [map_to_types $tokens] to equal [list OPEN ID ID ID EQUALS ID ID EQUALS STRING CLOSE]
    }

    it "correctly tokenizes a mustache with a single \} followed by EOF" {
        set tokens [tokenize "\{{foo}"]
        expect [map_to_types $tokens] to equal [list OPEN ID]
    }

    it "correctly tokenizes a mustache when invalid ID characters are used" {
        set tokens [tokenize "{{foo & }}"]
        expect [map_to_types $tokens] to equal [list OPEN ID]
    }
}



# describe Handlebars {
#     it "does something" {
#         expect [
#             Handlebars::Renderer::render_section "a{{#test}}asdf{{/test}}z" {}
#         ] to equal []
#     }
# }


# describe "Handlebars" {
#     it "should render comments according to the mustache spec" {
#         expect [
#             Handlebars::render "12345{{! Comment Block! }}67890" {}
#         ] to equal "1234567890"

#         expect [
#             Handlebars::render "12345{{!
#                                     This is a
#                                     multi-line comment...
#                                 }}67890"
#         ] to equal "1234567890"

#         expect [
#             Handlebars::render "
#             Begin.
#             {{! Comment Block! }}
#             End."
#         ] to equal "
#             Begin.
#             End."
#     }

#     it "should correctly interpolate values" {

#     }
# }

# dict get { {a b c} a b c d e } b


# context set { dict {a {b {c {first_name "Arthur" last_name "Schreiber"}}}}
# }

# context set -dict a.b.c { first_name "Arthur" last_name "Schreiber" }
# context set -list a.b.c.days { a b c d e }
# context set a.b.c.test "Hello World"
# context set -lambda a.b.c.helper {{context}}


# Generated structure (as JSON):

# # Lambdas: {{context} { ..whatever.. }}


# # NO support for implicit iteration, as we can't differentiate between a dict and a list
# # #bla -> #bla has to be either true or [llength > 1] +  a dict or false [llength < 0]

# # use {{#each varname}} to iterate
# # use {{#with varname}} to shift the context
# # use {{#if varname}} to create an if expression
# # use {{#unless varname}} to create an unless expression
# # use {{varname/child}} to access child elements of a dict
# # use {{#helper}} to access a block helper of the current context (or if that does not exist, a global helper)
# # use {{{helper}}} to access a simple helper of the current context (or if that does not exist, a global helper)

# # Block helpers have to take an argument called 'context' at first position, and an argument called 'options' on second position.
# # Additional arguments are optional.

# # Helpers have to take an argument called 'options' on the first position.
# # Additional arguments are optional.

# dict create {
#     first_name "Arthur"
#     second_name "Schreiber"
#     some_list {1 2 3 4 5 6}
#     a_simple_helper {{options} {
#         return "12345"
#     }}
#     a_block_helper {{context options} {
#         expr { $context + 1 }
#     }}
# }

# <div class="person">
#     <div class="first_name">{{first_name}}</div>
#     <div class="last_name">{{last_name}}</div>
#     <ul>
#         {{#each some_list}}
#         <li>{{.}}</li>
#         {{else}}
#         <li>No items here, sorry!</li>
#         {{/each}}
#     </ul>
#     <div class="simple_helper">{{simple_helper}}</div>
#     <div class="block_helper">{{#a_block_helper}}{{/a_block_helper}}</div>
# </div>

# {
#     person: {
#         first_name: "Arthur",
#         last_name: "Schreiber",
#         list_ints: [1 2 3 4 5],

#         list_dicts: [{a: "b"}, {a: "c"}],
#         lambda: function(context) {}
#     }
# }



# # context set a {dict {string {first_name "Arthur"}} {{string {last_name "Schreiber"}}}

# # context set a b {lambda {{person} {
# #     # Called with a dict containing the following values:
# #     # first_name -> "Arthur"
# #     # last_name -> "Schreiber"
# #     # helper -> this lambda
# #     #
# # }}}


# # context set a b dict {}
# # context set a b c lambda {{} {}}
