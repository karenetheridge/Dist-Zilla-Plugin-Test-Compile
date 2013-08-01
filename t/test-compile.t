use strict;
use warnings;

use Dist::Zilla::Tester;
use Path::Class;
use Cwd;
use Config;
use Test::More;

# build fake dist
my $tzil = Dist::Zilla::Tester->from_config({
    dist_root => dir(qw(t test-compile)),
});
$tzil->build;

my $build_dir = $tzil->tempdir->subdir('build');
my $file = file($build_dir, 't', '00-compile.t');
ok( -e $file, 'test created');

unlike($file->slurp(chomp => 1), qr/\s$/m, 'no trailing whitespace in generated test');

my $cwd = getcwd;
subtest 'run the generated test' => sub
{
    chdir $build_dir;
    system($^X, 'Makefile.PL');
    system($Config{make});

    do $file;
};

chdir $cwd;

done_testing;
