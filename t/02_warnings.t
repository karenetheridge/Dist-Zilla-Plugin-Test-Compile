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
                [ 'Test::Compile' => { fail_on_warning => 'none' } ],
            ),
            file(qw(source lib LittleKaboom.pm)) => <<'MODULE',
package LittleKaboom;
use strict;
use warnings;
warn "there was supposed to be a kaboom\n";
1;
MODULE
        },
    },
);

$tzil->build;

my $build_dir = $tzil->tempdir->subdir('build');
my $file = file($build_dir, 't', '00-compile.t');
ok( -e $file, 'test created');

# run the tests

my $cwd = getcwd;
is(
    warning {
        subtest 'run the generated test' => sub
        {
            chdir $build_dir;
            system($^X, 'Makefile.PL');
            system($Config{make});

            do $file;
        };
    },
    "there was supposed to be a kaboom\n",
    'warnings from compiling LittleKaboom are captured',
);

chdir $cwd;

done_testing;
