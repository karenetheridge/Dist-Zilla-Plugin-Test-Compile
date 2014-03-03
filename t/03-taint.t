use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Warnings 0.009 ':no_end_test', ':all';
use Test::DZil;
use Path::Tiny;
use File::pushd 'pushd';
use Config;

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
                [ MakeMaker => ],
                [ ExecDir => ],
                [ 'Test::Compile' => { fail_on_warning => 'none' } ],
            ),
            path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
            path(qw(source bin foo)) => <<'EXECUTABLE',
#!/usr/bin/perl -wT
warn 'warning issued when executable is run';
EXECUTABLE
        },
    },
);

$tzil->build;

my $build_dir = path($tzil->tempdir)->child('build');
my $file = $build_dir->child(qw(t 00-compile.t));
ok( -e $file, 'test created');

# run the tests

my @warnings = warnings {
    subtest 'run the generated test' => sub
    {
        my $wd = pushd $build_dir;
        system($^X, 'Makefile.PL');
        system($Config{make});

        do $file;
        warn $@ if $@;
    };
};

is(@warnings, 0, 'no warnings from compiling an executable using -T')
    or diag 'got warning(s): ', explain(\@warnings);

had_no_warnings if $ENV{AUTHOR_TESTING};
done_testing;
