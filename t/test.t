use strict;
use warnings;
use utf8;
use feature ':5.10';

use Test::More;
use FindBin;
use Template;
use Template::Provider::Vue;
use Template::Provider::Vue::Parser qw(parse_vue);
use Template::Provider::Vue::Stripper qw(strip);

my $_current_option = {};

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
    my $file = $FindBin::Bin . "/template/" . $template;
    my $template = do { local( @ARGV, $/ ) = $file ; <> } ;
    diag "compiled template: " . parse_vue($template, $_current_option);
  }
}

sub new_tt {
  my ($option,) = @_;
  $option ||= {};
  $_current_option = $option;

  # create TT2 instance
  my $tt_options = { ENCODING => 'utf8',
                     INCLUDE_PATH => $FindBin::Bin . "/template",
                   };
  my $vue_provider = Template::Provider::Vue->new({%$tt_options, %$option});
  my $tt_provider = Template::Provider->new($tt_options);

  $tt_options->{LOAD_TEMPLATES} = [ $vue_provider, $tt_provider];
  my $tt = Template->new($tt_options);
  return $tt;
}

sub slurp {
    my $pathname = shift;
    if (ok(open(my $fh, "<", $pathname), "open $pathname")) {
        my $rs = do { local $/; <$fh> };
        close($fh);
        return $rs;
    }
    return "";
}

subtest "use vue template as TT2 template" => sub {
  my $tt = new_tt();

  # template tests
  tt_ok($tt, 'raw_brace.vue', '<span>Test: message</span>', "{{ }} directive");
  tt_ok($tt,
        'v-text.vue',
        '<span>message</span><span>&lt;i&gt;message&lt;/i&gt;</span>',
        "v-text directive");
  tt_ok($tt, 'v-html.vue', '<span><i>message</i></span>', "v-html directive");
  tt_ok($tt, 'v-show.vue', '<span>foo bar</span>', "v-show directive");
  tt_ok($tt, 'v-on.vue', '<span>foo bar</span><span>hoge</span>', "v-show directive");
  tt_ok($tt, 'v-bind.vue',
        '<span foo="message">foo bar</span><span hoge="message">hoge</span>',
        "v-bind directive");
  tt_ok($tt, 'v-pre.vue',
        '<span><span>{{ msg }}</span><span v-text="msg"></span></span>',
        "v-pre directive");
  tt_ok($tt, 'v-once.vue',
        '<span><span>message</span><span>message</span></span>',
        "v-once directive");

 TODO: {
    local $TODO = "not implemented";

    tt_ok($tt,
        'v-text2.vue',
        '<span>message</span><span>&lt;i&gt;message&lt;/i&gt;</span>',
        "v-text directive 2");
    tt_ok($tt, 'v-bind2.vue', '<span foo="message">foo bar</span><span hoge="message">hoge</span>', "v-bind directive 2");
    tt_ok($tt, 'v-model.vue', '<input value="model_value"></input>', "v-model directive 2");
    tt_ok($tt, 'v-model2.vue', '<textarea>model_value</textarea>', "v-model directive 2");
    tt_ok($tt, 'v-model3.vue', '<input type="checkbox" checked">', "v-model directive 3");
    tt_ok($tt,
          'v-model4.vue',
          '<input type="radio" checked><input type="radio">',
          "v-model directive 4");
    tt_ok($tt,
          'v-model5.vue',
          '<select><option value="foo">foo</option><option value="message" selected>hoge</option></select>',
          "v-model directive 5");

    # TODO: v-slot
    # TODO: v-clock
    # TODO: :key attribute
    # TODO: ref keyword
    # TODO: is keyword
  }
};

subtest "use vue component" => sub {
    my $TEST_JS = "./t/test_output/component.js";
    my $tt = new_tt({ VUE_PARSE_COMPONENT => 1,
                      VUE_SCRIPT_DIR => "./t/test_output",
                 });

    # template tests
    tt_ok($tt, 'component.vue', "<template id=\"component\">\n  <div class=\"example\">message</div>\n</template>", "use vue component");
    is(slurp($TEST_JS), "export default {\n  data () {\n    return {\n      msg: 'Hello world!'\n    }\n  }\n}", "check generated js file");
    ok(unlink($TEST_JS), "unlink generated js file");

    # insert tests
    tt_ok($tt, 'insert.html.tt2', "<script type=\"text/x-template\" id=\"component\">\n  <div class=\"example\">{{ msg }}</div>\n</script>", "use tt2 INSERT directive");
    is(slurp($TEST_JS), "export default {\n  data () {\n    return {\n      msg: 'Hello world!'\n    }\n  }\n}", "check generated js file");
    ok(unlink($TEST_JS), "unlink generated js file");

};

subtest "test strip" => sub {
    my $TEST_VUE = "./t/template/component.vue";
    my $vue = slurp($TEST_VUE);
    my ($template, $script) = strip($vue);
    is($template, '<div class="example">{{ msg }}</div>', "strip template");
    is($script, "export default {\n  data () {\n    return {\n      msg: 'Hello world!'\n    }\n  }\n}", "strip script");
};

done_testing();

