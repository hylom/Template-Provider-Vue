package Template::Context::Vue;
use base 'Template::Context';

use strict;
use warnings;
use utf8;
use feature ':5.10';
use Data::Dumper;

use Template::Provider::Vue::Stripper qw(strip);
use FileHandle;
use File::Basename;
use File::Spec;

my $EXT = ['.vue', ''];

sub _init {
    my ($self, $params) = @_;
    if (!Template::Context::_init($self, $params)) {
        return 0;
    }

    $self->{VUE_PARSE_COMPONENT} = $params->{VUE_PARSE_COMPONENT} // 0;
    $self->{VUE_IGNORE_ROOT_STYLE} = $params->{VUE_IGNORE_ROOT_STYLE} // $self->{VUE_PARSE_COMPONENT};
    $self->{VUE_IGNORE_ROOT_SCRIPT} = $params->{VUE_IGNORE_ROOT_SCRIPT} // $self->{VUE_PARSE_COMPONENT};
    $self->{VUE_SCRIPT_DIR} = $params->{VUE_SCRIPT_DIR} // '';
    return 1;
}


#------------------------------------------------------------------------
# insert($file)
#
# Insert the contents of a file without parsing.
#------------------------------------------------------------------------

sub insert {
    my ($self, $file) = @_;
    my ($prefix, $providers, $text, $error);
    my $output = '';

    my $files = ref $file eq 'ARRAY' ? $file : [ $file ];

    $self->debug("insert([ ", join(', '), @$files, " ])") 
        if $self->{ DEBUG };
 
 
    FILE: foreach $file (@$files) {
        my $name = $file;
 
        if (MSWin32) {
            # let C:/foo through
            $prefix = $1 if $name =~ s/^(\w{2,})://o;
        }
        else {
            $prefix = $1 if $name =~ s/^(\w+)://;
        }
 
        if (defined $prefix) {
            $providers = $self->{ PREFIX_MAP }->{ $prefix } 
                || return $self->throw(Template::Constants::ERROR_FILE,
                    "no providers for file prefix '$prefix'");
        }
        else {
            $providers = $self->{ PREFIX_MAP }->{ default }
                || $self->{ LOAD_TEMPLATES };
        }
 
        foreach my $provider (@$providers) {
            ($text, $error) = $provider->load($name, $prefix);
            next FILE unless $error;
            if ($error == Template::Constants::STATUS_ERROR) {
                $self->throw($text) if ref $text;
                $self->throw(Template::Constants::ERROR_FILE, $text);
            }
        }
        $self->throw(Template::Constants::ERROR_FILE, "$file: not found");
    }
    continue {
        $output .= $text;
    }
    return $output;
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
