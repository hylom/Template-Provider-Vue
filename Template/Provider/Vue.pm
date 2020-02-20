package Template::Provider::Vue;
use base 'Template::Provider';

use strict;
use warnings;
use utf8;
use feature ':5.10';
use Data::Dumper;

use Template::Provider::Vue::Parser qw(parse_vue);
use FileHandle;
use File::Basename;
use File::Spec;

my $EXT = ['.vue', ''];

sub _init {
    my ($self, $params) = @_;
    if (!Template::Provider::_init($self, $params)) {
        return 0;
    }

    $self->{VUE_PARSE_COMPONENT} = $params->{VUE_PARSE_COMPONENT} // 0;
    $self->{VUE_IGNORE_ROOT_STYLE} = $params->{VUE_IGNORE_ROOT_STYLE} // $self->{VUE_PARSE_COMPONENT};
    $self->{VUE_IGNORE_ROOT_SCRIPT} = $params->{VUE_IGNORE_ROOT_SCRIPT} // $self->{VUE_PARSE_COMPONENT};
    $self->{VUE_SCRIPT_DIR} = $params->{VUE_SCRIPT_DIR} // '';
    return 1;
}

sub _find_template {
    my ($self, $fname) = @_;
    foreach my $ext (@$EXT) {
        my $path = $fname . $ext;
        if (-f $path) {
            return $path;
        }
    }
    return undef;
}

sub _template_modified {
    my ($self, $fname) = @_;
    my $path = $self->_find_template($fname);
    return undef if !$path;
    return (stat($path))[9];
}

sub _template_content {
    my ($self, $fname) = @_;
    my $path = $self->_find_template($fname);
    return undef if !$path;

    my $fh = FileHandle->new;
    if ($fh->open($path, "r")) {
        my $vue = do { local $/; <$fh> };
        $fh->close;

        if ($self->{VUE_PARSE_COMPONENT}) {
            my ($filename, ) = fileparse($path, qr/\.[^.]*/);
            my $component_name = $filename;
            my ($tmpl, $script) = parse_vue($vue,
                                            { VUE_PARSE_COMPONENT => $self->{VUE_PARSE_COMPONENT},
                                              VUE_IGNORE_ROOT_STYLE => $self->{VUE_IGNORE_ROOT_STYLE},
                                              VUE_IGNORE_ROOT_SCRIPT => $self->{VUE_IGNORE_ROOT_SCRIPT},
                                              VUE_COMPONENT_NAME => $component_name,
                                          });
            if ($self->{VUE_SCRIPT_DIR}) {
                $self->_write_script($script, $component_name);
            }

            return $tmpl;
        }

        my $tmpl = parse_vue($vue);
        return $tmpl;
    }
    return undef;
}

sub _write_script {
    my ($self, $script, $component_name) = @_;
    my $pathname = File::Spec->catfile($self->{VUE_SCRIPT_DIR}, "$component_name.js");
    my $fh = FileHandle->new;
    if ($fh->open($pathname, "w")) {
        $fh->write($script);
        $fh->close;
    }
    else {
        warn "cannot open file: $pathname";
    }
}
