use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::Compile <self>

use Test::More 0.94 tests => 1 + 1;



my @module_files = (
    'Foo.pm',
);



# no fake home requested

use File::Spec;
use IPC::Open3;
use IO::Handle;

my @warnings;
for my $lib (@module_files)
{
    # see L<perlfaq8/How can I capture STDERR from an external command?>
    open my $stdin, '<', File::Spec->devnull or die $!;
    my $stderr = IO::Handle->new;

    # XXX I changed -Mblib to -Ilib so a build is not needed
    my $pid = open3($stdin, '>&STDERR', $stderr, $^X, '-Ilib', '-e', "require q[$lib]");
    binmode $stderr, ':crlf' if $^O eq 'MSWin32';
    waitpid($pid, 0);
    is($? >> 8, 0, "$lib loaded ok");

    if (my @_warnings = <$stderr>)
    {
        warn @_warnings;
        push @warnings, @_warnings;
    }
}



is(scalar(@warnings), 0, 'no warnings found');

BAIL_OUT("Compilation problems") if !Test::More->builder->is_passing;
