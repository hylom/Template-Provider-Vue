package Template::Provider::Vue::Parser;

use strict;
use warnings;
use utf8;
use feature ':5.10';

use HTML::Parser;
use HTML::Element;
use List::Util qw(any);

use Data::Dumper;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(parse_vue);

my $output_que = [];
my $nest_level = 0;
my $level_exit = {};
my $insert_end = {};
my $pre_level = -1;
my $context = "";
my $context_level = 0;

my $script_que = [];

my $_option = {};

sub parse_vue {
    my ($template, $option) = @_;
    $_option = $option // {};

    $output_que = [];
    $script_que = [];
    $nest_level = 0;
    $level_exit = {};
    $insert_end = {};
    $pre_level = -1;

    my $p = HTML::Parser->new( api_version => 3,
                               start_h => [\&start_cb, "tag, attr, attrseq, text"],
                               end_h   => [\&end_cb,   "tag, text"],
                               text_h  => [\&text_cb, "text"],
                               marked_sections => 1,
                           );
    $p->parse($template);
    my $html = join("", @$output_que);

    # trim first/last whitespaces
    $html =~ s/^\s*//;
    $html =~ s/\s*$//;
    utf8::decode($html) if !utf8::is_utf8($html);

    if (wantarray) {
        my $script = join("", @$script_que);
        $script =~ s/^\s*//;
        $script =~ s/\s*$//;
        utf8::decode($script) if !utf8::is_utf8($script);
        return ($html, $script);
    }
    else {
        return $html;
    }
}

sub template_tag {
    my $content = shift;
    return "[% $content %]";
}

sub template_if {
    my $content = shift;
    return template_tag("IF $content");
}

sub template_elsif {
    my $content = shift;
    return template_tag("ELSIF $content");
}

sub template_else {
    return template_tag("ELSE");
}

sub template_foreach {
    my ($key, $array) = @_;
    return template_tag("FOREACH $key IN $array");
}

sub template_end {
    return template_tag("END");
}

sub make_element {
    my ($tag, $attr, $attr_seq) = @_;
    my @attrs;
    for my $attr_name (@$attr_seq) {
        my $value = $attr->{$attr_name};
        if (!utf8::is_utf8($value)) {
            #utf8::decode($value);
        }
        push @attrs, $attr_name, $value;
    }
    my $a = HTML::Element->new($tag, @attrs);
    return $a->starttag('&">');
}

sub include_component {
    my ($tag, $attr, $attr_seq) = @_;
    my $comp = $_option->{VUE_COMPONENTS}{$tag};

    my @args;
    for my $attr_name (@$attr_seq) {
        my $arg_str = $attr->{$attr_name};
        my $arg_name = $attr_name;

        if ($attr_name =~ m/^(?:v-bind)?:(.*)/) {
            $arg_name = $1;
        }
        else {
            $arg_str = "\"$arg_str\""
        }
        push @args, "$arg_name=$arg_str";
    }
    return template_tag('INCLUDE ' . $comp->{path} . " " . join(" ", @args));
}

sub remove_previous_end {
    while (@$output_que) {
        my $prev = pop @$output_que;
        last if $prev eq template_end();
    }
}

sub pre_mode {
    my $lv = shift;
    if (defined $lv) {
        if ($lv) {
            $pre_level = $nest_level;
        }
        else {
            $pre_level = -1;
        }
    }
    else {
        return $pre_level >= 0 && $nest_level >= $pre_level;
    }
}

sub start_cb {
    my ($tag, $attr, $attrseq, $text) = @_;

    my @push_after;
    my @push_before;
    my @attr_result;

    if ($tag eq "template") {
        if ($context eq "template") {
            $context_level++;
        }
        else {
            $context = "template";
            $context_level = 1;
        }
    }
    elsif ($tag eq "style" && $_option->{VUE_IGNORE_ROOT_STYLE}) {
        $context = "style";
        $context_level = 1;
        return;
    }
    elsif ($tag eq "script" && $_option->{VUE_IGNORE_ROOT_SCRIPT}) {
        $context = "script";
        $context_level = 1;
        return;
    }

    if ($_option->{VUE_PARSE_COMPONENT}) {
        return if $context ne "template";
        if ($tag eq "template" && $context_level == 1) {
            return;
        }
    }

    my $component_tag = 0;
    if ($_option->{VUE_COMPONENTS}
        && any { $tag eq $_ } keys %{$_option->{VUE_COMPONENTS}}) {
        $component_tag = 1;
    }

    my @classes;
    my @class_directives;
    for my $attr_name (@$attrseq) {
        if (pre_mode()) {
            push @attr_result, $attr_name;
            next;
        }

        if ($attr_name eq "v-pre") {
            pre_mode(1);
            next;
        }

        if ($attr_name eq "v-once") {
            next;
        }

        if ($attr_name eq "v-for") {
            my $val = $attr->{$attr_name};
            if ($val =~ m/^\s*(\S+?)\s+in\s+(\S+)/) {
                push @push_before, template_foreach($1, $2);
                $insert_end->{$nest_level} += 1;
            }
            next;
        }

        if ($attr_name eq "v-show") {
            push @push_before, template_if($attr->{'v-show'});
            $insert_end->{$nest_level} += 1;
            next;
        }

        if ($attr_name eq "v-if") {
            push @push_before, template_if($attr->{'v-if'});
            $insert_end->{$nest_level} += 1;
            next;
        }

        if ($attr_name eq "v-else-if") {
            remove_previous_end();
            push @push_before, template_elsif($attr->{'v-else-if'});
            $insert_end->{$nest_level} += 1;
            next;
        }

        if ($attr_name eq "v-else") {
            remove_previous_end();
            push @push_before, template_else();
            $insert_end->{$nest_level} = 1;
            next;
        }

        if ($attr_name eq "v-html") {
            push @push_after, template_tag($attr->{'v-html'});
            next;
        }

        if ($attr_name eq "v-text") {
            push @push_after, template_tag($attr->{'v-text'} . ' | html');
            next;
        }

        if (lc($attr_name) eq "class") {
            push @classes, $attr->{$attr_name};
            next;
        }

        if (!$component_tag && $attr_name =~ m/^(?:v-bind)?:class/i) {
            # v-bind:class is special case.
            my $val = $attr->{$attr_name};
            if ($val =~ m/\{(.*)}/) {
                my @terms = split(/\s*,\s*/, $1);
                for my $term (@terms) {
                    my ($k, $v) = split(/\s*:\s*/, $term);
                    if ($k && $v) {
                        my $result = template_if($v) . " $k" . template_end;
                        push @class_directives, $result;
                    }
                }
            }
            else {
                push @classes, template_tag($val);
            }
            next;
        }

        if (!$component_tag && $attr_name =~ m/^(?:v-bind)?:(.*)/) {
            $attr->{$1} = template_tag($attr->{$attr_name});
            push @attr_result, $1;
            next;
        }

        if ($attr_name =~ m/^(?:v-on:|@)(.*)/) {
            next;
        }

        push @attr_result, $attr_name;
    }
    if (@classes) {
        push @attr_result, 'class';
        $attr->{class} = join(" ", @classes) . join("", @class_directives);
    }

    $nest_level++;
    push @$output_que, @push_before if @push_before;

    if ($component_tag) {
        push @$output_que, include_component($tag, $attr, \@attr_result);
    }
    else {
        push @$output_que, make_element($tag, $attr, \@attr_result);
    }

    push @$output_que, @push_after if @push_after;
}

sub end_cb {
    my ($tagname, $text) = @_;
    my $bypass = 0;

    if ($tagname eq "/template") {
        if ($context_level == 1) {
            $bypass = 1;
            $context = "";
        }
        $context_level--;
    }
    elsif ($tagname eq "/style" && $context eq "style") {
        $context = "";
        return;
    }
    elsif ($tagname eq "/script" && $context eq "script") {
        $context = "";
        # $script_que
        return;
    }

    if ($_option->{VUE_COMPONENTS}) {
        my $tag = substr($tagname, 1);
        if (any { $tag eq $_ } keys %{$_option->{VUE_COMPONENTS}}) {
            $bypass = 1;
        }
    }
    if (!$bypass) {
        push @$output_que, $text;
    }

    $nest_level--;
    if ($pre_level == $nest_level) {
        $pre_level = -1;
    }

    if ($level_exit->{$nest_level}) {
        push @$output_que, $level_exit->{$nest_level};
        delete $level_exit->{$nest_level};
    }

    while ($insert_end->{$nest_level}) {
        push @$output_que, template_end();
        $insert_end->{$nest_level} -= 1;
    }
}

sub text_cb {
    my ($text,) = @_;

    if ($_option->{VUE_IGNORE_ROOT_STYLE} && $context eq "style") {
        return;
    }
    if ($_option->{VUE_IGNORE_ROOT_SCRIPT} && $context eq "script") {
        push @$script_que, $text;
        return;
    }

    if (!pre_mode()) {
        $text =~ s/\{\{\s+(.*)\s+}}/template_tag($1)/e;
    }
    push @$output_que, $text;
}

1;
