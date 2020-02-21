package Template::Provider::Vue::Stripper;

use strict;
use warnings;
use utf8;
use feature ':5.10';

use HTML::Parser;
use HTML::Element;

use Data::Dumper;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(strip_template strip_sript strip);

my $output_que = [];
my $nest_level = 0;
my $level_exit = {};
my $insert_end = {};
my $pre_level = -1;
my $context = "";
my $context_level = 0;

my $script_que = [];

my $_option = {};

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

sub strip {
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
        return;
    }
    elsif ($tag eq "style") {
        $context = "style";
        $context_level = 1;
        return;
    }
    elsif ($tag eq "script") {
        $context = "script";
        $context_level = 1;
        return;
    }

    push @$output_que, make_element($tag, $attr, $attrseq);
}

sub end_cb {
    my ($tagname, $text) = @_;

    if ($tagname eq "/template") {
        if ($context_level == 1) {
            $context = "";
        }
        $context_level--;
        return;
    }
    elsif ($tagname eq "/style" && $context eq "style") {
        $context = "";
        return;
    }
    elsif ($tagname eq "/script" && $context eq "script") {
        $context = "";
        return;
    }
    push @$output_que, $text;
}

sub text_cb {
    my ($text,) = @_;

    if ($context eq "style") {
        return;
    }
    if ($context eq "script") {
        push @$script_que, $text;
        return;
    }
    if ($context eq "template") {
        push @$output_que, $text;
        return;
    }
}

1;
