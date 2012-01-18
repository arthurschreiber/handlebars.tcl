lappend auto_path [file join [file dirname [info script]] ".."]
lappend auto_path [file join [file dirname [info script]] ".." ".." "tclspec"]

package require spec/autorun
package require handlebars

describe "Handlebars" {
    describe "::escape_html" {
        it "returns the given input with all special html characters escaped" {
            expect [
                Handlebars::escape_html "<a href='test.com?a=1&b=2' class=\"yay\">Click here!</a>"
            ] to equal "&lt;a href=&#39;test.com?a=1&amp;b=2&#39; class=&quot;yay&quot;&gt;Click here!&lt;/a&gt;"
        }
    }

    it "should be able to render a very basic template" {
        expect [
            Handlebars::render {Hello {{planet}}!} [list planet "World"]
        ] to equal "Hello World!"
    }

    it "should be able to render templates with variables that point to sub-keys" {
        expect [
            Handlebars::render {Hello {{person.name}}!} [list person [list name "Arthur"]]
        ] to equal "Hello Arthur!"
    }

    it "correctly renders templates with a variables pointing at the current context" {
        expect [
            Handlebars::render {Hello {{.}}!} [list person [list name "Arthur"]]
        ] to equal "Hello person {name Arthur}!"
    }

    it "correctly renders templates with missing variables" {
        expect [
            Handlebars::render {Hello {{planet}}!} [list]
        ] to equal "Hello !"

        expect [
            Handlebars::render {Hello {{person.name}}!} [list]
        ] to equal "Hello !"
    }

    it "escapes values by default" {
        expect [
            Handlebars::render {Escaped: {{html}}} { html "<b>Yay!</b>" }
        ] to equal "Escaped: &lt;b&gt;Yay!&lt;/b&gt;"
    }

    it "correctly renders unescaped values" {
        expect [
            Handlebars::render {Escaped: {{{html}}}} { html "<b>Yay!</b>" }
        ] to equal "Escaped: <b>Yay!</b>"

        expect [
            Handlebars::render {Escaped: {{&html}}} { html "<b>Yay!</b>" }
        ] to equal "Escaped: <b>Yay!</b>"
    }

    it "correctly ignores comments" {
        expect [
            Handlebars::render {<h1>Today{{! ignore me }}.</h1>}
        ] to equal "<h1>Today.</h1>"
    }
}