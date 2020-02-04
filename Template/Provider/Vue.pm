package Template::Provider::Vue;
use base 'Template::Provider';

use strict;
use warnings;
use utf8;
use feature ':5.10';

use Template::Provider::Vue::Parser qw(parse_vue);
use FileHandle;

my $EXT = ['.vue', ''];

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
        my $tmpl = parse_vue($vue);
        return $tmpl;
    }
    return undef;
}
