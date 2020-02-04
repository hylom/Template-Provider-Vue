use strict;
use warnings;
use utf8;
use feature ':5.10';

use Test::More;
use FindBin;
use Template;
use Template::Provider::Vue;
use Template::Provider::Vue::Parser qw(parse_vue);

# utility function
sub tt_ok {
  my ($tt, $template, $expected, $test_name) = @_;
  $test_name //= "";
  my $output = "";
  my $vars = { msg => 'message',
               html_msg => '<i>message</i>',
               flag_true => 1,
               flag_false => 0,
               num => 10,
               model => 'model_value',
             };
  my $rs = $tt->process($template, $vars, \$output);

  if (!$rs) {
    fail($test_name);
    diag $tt->error;
    return;
  }

  if (!is($output, $expected, $test_name)) {
    my $file = $FindBin::Bin . "/template/" . $template . ".vue";
    my $template = do { local( @ARGV, $/ ) = $file ; <> } ;
    diag "compiled template: " . parse_vue($template);
  }
}

sub new_tt {
  # create TT2 instance
  my $tt_options = { ENCODING => 'utf8',
                     INCLUDE_PATH => $FindBin::Bin . "/template",
                   };
  my $vue_provider = Template::Provider::Vue->new($tt_options);
  my $tt_provider = Template::Provider->new($tt_options);

  $tt_options->{LOAD_TEMPLATES} = [ $tt_provider, $vue_provider ];
  my $tt = Template->new($tt_options);
  return $tt;
}

subtest "use vue template as TT2 template" => sub {
  my $tt = new_tt();

  # template tests
  tt_ok($tt, 'raw_brace', '<span>Test: message</span>', "{{ }} directive");
  tt_ok($tt,
        'v-text',
        '<span>message</span><span>&lt;i&gt;message&lt;/i&gt;</span>',
        "v-text directive");
  tt_ok($tt, 'v-html', '<span><i>message</i></span>', "v-html directive");
  tt_ok($tt, 'v-show', '<span>foo bar</span>', "v-show directive");
  tt_ok($tt, 'v-on', '<span>foo bar</span><span>hoge</span>', "v-show directive");
  tt_ok($tt, 'v-bind',
        '<span foo="message">foo bar</span><span hoge="message">hoge</span>',
        "v-bind directive");
  tt_ok($tt, 'v-pre',
        '<span><span>{{ msg }}</span><span v-text="msg"></span></span>',
        "v-pre directive");
  tt_ok($tt, 'v-once',
        '<span><span>message</span><span>message</span></span>',
        "v-once directive");

 TODO: {
    local $TODO = "not implemented";

  tt_ok($tt,
        'v-text2',
        '<span>message</span><span>&lt;i&gt;message&lt;/i&gt;</span>',
        "v-text directive 2");
    tt_ok($tt, 'v-bind2', '<span foo="message">foo bar</span><span hoge="message">hoge</span>', "v-bind directive 2");
    tt_ok($tt, 'v-model', '<input value="model_value"></input>', "v-model directive 2");
    tt_ok($tt, 'v-model2', '<textarea>model_value</textarea>', "v-model directive 2");
    tt_ok($tt, 'v-model3', '<input type="checkbox" checked">', "v-model directive 3");
    tt_ok($tt,
          'v-model4',
          '<input type="radio" checked><input type="radio">',
          "v-model directive 4");
    tt_ok($tt,
          'v-model5',
          '<select><option value="foo">foo</option><option value="message" selected>hoge</option></select>',
          "v-model directive 5");

    # TODO: v-slot
    # TODO: v-clock
    # TODO: :key attribute
    # TODO: ref keyword
    # TODO: is keyword
  }
};


done_testing();

