use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;
use File::pushd 'pushd';

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
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
