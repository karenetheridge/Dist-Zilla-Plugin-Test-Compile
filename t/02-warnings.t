use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Warnings 0.009 ':no_end_test', ':all';
use Test::DZil;
use Path::Tiny;
use File::pushd 'pushd';

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
                [ MakeMaker => ],
                [ 'Test::Compile' => { fail_on_warning => 'none' } ],
            ),
            path(qw(source lib LittleKaboom.pm)) => <<'MODULE',
package LittleKaboom;
use strict;
use warnings;
warn 'there was supposed to be a kaboom';
1;
MODULE
        },
    },
);

$tzil->build;

my $build_dir = path($tzil->tempdir)->child('build');
my $file = $build_dir->child(qw(t 00-compile.t));
ok( -e $file, 'test created');

# run the tests

my $files_tested;
my $warning = warning {
    subtest 'run the generated test' => sub
    {
        my $wd = pushd $build_dir;
        $tzil->plugin_named('MakeMaker')->build;

        do $file;
        warn $@ if $@;

        $files_tested = Test::Builder->new->current_test;
    };
};
like(
    $warning,
    qr/^there was supposed to be a kaboom/,
    'warnings from compiling LittleKaboom are captured',
) or diag 'got warning(s): ', explain($warning);

is($files_tested, 1, 'correct number of files were tested (no warning checks)');

had_no_warnings if $ENV{AUTHOR_TESTING};
done_testing;
