package Template::Provider::Vue;
use base 'Template::Provider';

use strict;
use warnings;
use utf8;
use feature ':5.10';
use Data::Dumper;

use Template::Provider::Vue::Parser qw(parse_vue);
use Template::Provider::Vue::Stripper qw(strip);
use FileHandle;
use File::Basename;
use File::Spec;

my $EXT = ['.vue', ''];
# regex to match relative paths
our $RELATIVE_PATH = qr[(?:^|/)\.+/];

sub _init {
    my ($self, $params) = @_;
    if (!Template::Provider::_init($self, $params)) {
        return 0;
    }

    $self->{VUE_PARSE_COMPONENT} = $params->{VUE_PARSE_COMPONENT} // 0;
    $self->{VUE_IGNORE_ROOT_STYLE} = $params->{VUE_IGNORE_ROOT_STYLE} // $self->{VUE_PARSE_COMPONENT};
    $self->{VUE_IGNORE_ROOT_SCRIPT} = $params->{VUE_IGNORE_ROOT_SCRIPT} // $self->{VUE_PARSE_COMPONENT};
    $self->{VUE_SCRIPT_DIR} = $params->{VUE_SCRIPT_DIR} // '';
    $self->{VUE_COMPONENTS} = $params->{VUE_COMPONENTS} // {};
    return 1;
}

# override 'load' method to strip <template>, <style>, <script> tags
sub load {
    my ($self, $name) = @_;
    my $path = $name;
    my $error;

    # check path (from Template::Provider::load)
    if (File::Spec->file_name_is_absolute($name)) {
        # absolute paths (starting '/') allowed if ABSOLUTE set
        $error = "$name: absolute paths are not allowed (set ABSOLUTE option)"
          unless $self->{ ABSOLUTE };
    }
    elsif ($name =~ m[$RELATIVE_PATH]o) {
        # anything starting "./" is relative to cwd, allowed if RELATIVE set
        $error = "$name: relative paths are not allowed (set RELATIVE option)"
          unless $self->{ RELATIVE };
    }
    else {
      INCPATH: {
            # otherwise, it's a file name relative to INCLUDE_PATH
            my $paths = $self->paths()
              || return ($self->error(), Template::Constants::STATUS_ERROR);

            foreach my $dir (@$paths) {
                $path = File::Spec->catfile($dir, $name);
                last INCPATH
                  if defined $self->_template_modified($path);
            }
            undef $path;      # not found
        }
    }

    return ("not found: $name", Template::Constants::STATUS_ERROR) if !$path;

    my $fh = FileHandle->new;
    if ($fh->open($path, "r")) {
        my $vue = do { local $/; <$fh> };
        $fh->close;

        if ($self->{VUE_PARSE_COMPONENT}) {
            my ($filename, ) = fileparse($path, qr/\.[^.]*/);
            my $component_name = $filename;
            my ($html, $script) = strip($vue,
                                            { VUE_PARSE_COMPONENT => $self->{VUE_PARSE_COMPONENT},
                                              VUE_IGNORE_ROOT_STYLE => $self->{VUE_IGNORE_ROOT_STYLE},
                                              VUE_IGNORE_ROOT_SCRIPT => $self->{VUE_IGNORE_ROOT_SCRIPT},
                                              VUE_COMPONENT_NAME => $component_name,
                                          });
            if ($self->{VUE_SCRIPT_DIR}) {
                $self->_write_script($script, $component_name);
            }

            my $result = "<script type=\"text/x-template\" id=\"$component_name\">\n  $html\n</script>";
            return $result;
        }
        return $vue;
    }
    return undef;
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
            my $opts = { VUE_PARSE_COMPONENT => $self->{VUE_PARSE_COMPONENT},
                         VUE_IGNORE_ROOT_STYLE => $self->{VUE_IGNORE_ROOT_STYLE},
                         VUE_IGNORE_ROOT_SCRIPT => $self->{VUE_IGNORE_ROOT_SCRIPT},
                         VUE_COMPONENT_NAME => $component_name,
                         VUE_COMPONENTS => $self->{VUE_COMPONENTS},
            };
            my ($tmpl, $script) = parse_vue($vue, $opts);
            if ($self->{VUE_SCRIPT_DIR} && $script) {
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
