#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use feature ':5.10';

BEGIN { push @INC, '../'; }

use Template;
use Template::Provider;
use Template::Provider::Vue;


# add TT2 options
my $tt_options = {};
$tt_options->{ENCODING} = 'utf8';

# create TT2 provider
my $tt2_provider = Template::Provider->new($tt_options);

# create Vue provider
my $vue_provider = Template::Provider::Vue->new($tt_options);

# register provider
$tt_options->{LOAD_TEMPLATES} = [$vue_provider, $tt2_provider];

# create Template object
my $tt = Template->new($tt_options);

# vars
my $vars = { foo => "hogehoge",
             bar => 1, };

# render
$tt->process('sample.html.tt2', $vars);

