use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Warnings 0.005 ':all';
use Test::DZil;
use Path::Class;
use Cwd;
use Config;

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            'source/dist.ini' => simple_ini(
                [ GatherDir => ],
                [ MakeMaker => ],
                [ ExecDir => ],
                [ 'Test::Compile' => { fail_on_warning => 'none' } ],
            ),
            file(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
            file(qw(source bin foo)) => <<'EXECUTABLE',
#!/usr/bin/perl -wT
warn 'warning issued when executable is run';
EXECUTABLE
        },
    },
);

$tzil->build;

my $build_dir = $tzil->tempdir->subdir('build');
my $file = file($build_dir, 't', '00-compile.t');
ok( -e $file, 'test created');

# run the tests

my $cwd = getcwd;
my @warnings = warnings {
    subtest 'run the generated test' => sub
    {
        chdir $build_dir;
        system($^X, 'Makefile.PL');
        system($Config{make});

        do $file;
        warn $@ if $@;
    };
};

is(@warnings, 0, 'no warnings from compiling an executable using -T')
    or diag 'got warning(s): ', explain(\@warnings);

chdir $cwd;

done_testing;
