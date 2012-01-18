package provide handlebars 0.1

namespace eval Handlebars {
    variable escape_map {
        "&"     "&amp;"
        "<"     "&lt;"
        ">"     "&gt;"
        "\""    "&quot;"
        "'"     "&#39;"
    }

    proc escape_html { html } {
        subst [regsub -all {&(?!\w+;)|[<>"']} $html \
                    {[ expr { [dict exists $::Handlebars::escape_map {&}] ? [dict get $::Handlebars::escape_map {&}] : {&} } ]}]
    }

    proc find_name { name stack } {
        if { $name == "." } {
            return [lindex $stack end]
        } elseif { $name == ".." } {
            return [lindex $stack end-1]
        }

        set names [split $name "./"]
        set last_index [expr { [llength $names] - 1 }]
        set target [lindex $names end]

        set value ""

        set i [llength $stack]
        while { $i } {
            set context [lindex $stack [incr i -1]]

            set j 0
            while { $j < $last_index } {
                if { [dict exists $context [lindex $names $j]] } {
                    set context [dict get $context [lindex $names $j]]
                } else {
                    set context [list]
                    break
                }

                incr j
            }

            if { [dict exists $context $target] } {
                set value [dict get $context $target]
                break
            }
        }

        return $value
    }

    proc get_escaped { source stack } {
        escape_html [find_name $source $stack]
    }

    proc get_plain { source stack } {
        find_name $source $stack
    }

    proc render { template {context {}} } {
        set output [list]

        set open_tag "\{\{"
        set close_tag "\}\}"

        set stack [list $context]

        set length [string length $template]
        for {set i 0} {$i < $length} {incr i} {
            if { [string range $template $i $i+1] == $open_tag } {
                incr i [string length $open_tag]
                set c [string index $template $i]

                set next_open_tag $open_tag
                set next_close_tag $close_tag

                switch $c {
                    "\{" {
                        incr i
                        set close_tag "\}$close_tag"
                        set command "get_plain"
                    }
                    "&" {
                        incr i
                        set command "get_plain"
                    }
                    default {
                        set command "get_escaped"
                    }
                }

                set end [string first $close_tag $template $i]
                if { $end == -1 } {
                    error "Tag '$open_tag' was not closed properly"
                }

                set source [string range $template $i $end-1]
                lappend output [$command $source $stack]

                set i [expr { $end + [string length $close_tag] - 1}]

                set open_tag $next_open_tag
                set close_tag $next_close_tag
            } else {
                set c [string index $template $i]
                lappend output $c
            }
        }

        join $output ""
    }
}