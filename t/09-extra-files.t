use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
                [ 'Test::Compile' => { fail_on_warning => 'none', file => [ 'Bar.pm' ] } ],
            ),
            path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
        },
    },
);

$tzil->build;

my $content = path($tzil->tempdir)->child(qw(build t 00-compile.t))->slurp_utf8;

like($content, qr'
my @module_files = \(
    \'Bar\.pm\',
    \'Foo\.pm\'
\);
', 'test checks explicitly added file',);

done_testing;
