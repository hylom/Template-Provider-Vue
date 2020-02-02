package Template::Provider::Vue::Parser;

use strict;
use warnings;
use utf8;
use feature ':5.10';

use HTML::Parser;
use HTML::Element;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(parse_vue);

my $output_que = [];
my $nest_level = 0;
my $level_exit = {};
my $insert_end = {};
my $pre_level = -1;

sub parse_vue {
    my ($template,) = @_;
    $output_que = [];
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
    return join("", @$output_que);
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

        if ($attr_name =~ m/^(?:v-bind)?:(.*)/) {
            $attr->{$1} = template_tag($attr->{$attr_name});
            push @attr_result, $1;
            next;
        }

        if ($attr_name =~ m/^(?:v-on:|@)(.*)/) {
            next;
        }

        push @attr_result, $attr_name;
    }
    
    $nest_level++;
    push @$output_que, @push_before if @push_before;
    push @$output_que, make_element($tag, $attr, \@attr_result);
    push @$output_que, @push_after if @push_after;
}

sub end_cb {
    my ($tagname, $text) = @_;
    push @$output_que, $text;

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
    if (!pre_mode()) {
        $text =~ s/{{\s+(.*)\s+}}/template_tag($1)/e;
    }
    push @$output_que, $text;
}

1;
