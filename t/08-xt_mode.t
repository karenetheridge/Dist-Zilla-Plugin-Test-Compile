use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;
use File::pushd 'pushd';
use Test::Deep;
use Test::Deep::JSON;

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
                [ MetaJSON => ],
                [ 'Test::Compile' => { fail_on_warning => 'none', xt_mode => 1 } ],
            ),
            path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
        },
    },
);

$tzil->build;

my $build_dir = path($tzil->tempdir)->child('build');
ok(!-e $build_dir->child(qw(t 00-compile.t)), 'default test not created');
my $file = $build_dir->child(qw(xt author 00-compile.t));
ok(-e $file, 'test created using new name');

my $json = $build_dir->child('META.json')->slurp_raw;
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

my $files_tested;
subtest 'run the generated test' => sub
{
    my $wd = pushd $build_dir;
    # intentionally not running Makefile.PL...

    do $file;
    warn $@ if $@;

    $files_tested = Test::Builder->new->current_test;
};

is($files_tested, 1, 'correct number of files were tested');

done_testing;
