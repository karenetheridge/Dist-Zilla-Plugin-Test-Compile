use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;
use Test::Deep;
use Test::Deep::JSON;

BEGIN {
    use Dist::Zilla::Plugin::Test::Compile;
    $Dist::Zilla::Plugin::Test::Compile::VERSION = 9999
        unless $Dist::Zilla::Plugin::Test::Compile::VERSION;
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does-not-exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ GatherDir => ],
                    [ MetaJSON => ],
                    [ 'Test::Compile' => { phase => 'develop' } ],
                ),
                path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
            },
        },
    );

    $tzil->build;

    my $build_dir = path($tzil->tempdir)->child('build');
    my $file = $build_dir->child(qw(t 00-compile.t));
    ok(-e $file, 'test created');

    my $json = $build_dir->child('META.json')->slurp_utf8;
    cmp_deeply(
        $json,
        json(superhashof({
            prereqs => {
                    develop => {
                        requires => {
                            'Test::More' => '0',
                            'File::Spec' => '0',
                            'IPC::Open3' => '0',
                            'IO::Handle' => '0',
                        },
                    },
                },
            }),
        ),
        'prereqs are properly injected for the develop phase',
    );
}

{
    my $tzil = Builder->from_config(
        { dist_root => 't/does-not-exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ GatherDir => ],
                    [ MetaJSON => ],
                    [ 'Test::Compile' => { phase => '' } ],
                ),
                path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
            },
        },
    );

    $tzil->build;

    my $build_dir = path($tzil->tempdir)->child('build');
    my $file = $build_dir->child(qw(t 00-compile.t));
    ok(-e $file, 'test created');

    my $json = $build_dir->child('META.json')->slurp_utf8;
    cmp_deeply(
        $json,
        json(superhashof({ prereqs => {} })),
        'no prereqs are injected',
    );
}

done_testing;
