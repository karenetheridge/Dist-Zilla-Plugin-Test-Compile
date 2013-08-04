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

unlike($file->slurp, qr/[^\S\n]\n/m, 'no trailing whitespace in generated test');

my $cwd = getcwd;
my $files_tested;
subtest 'run the generated test' => sub
{
    chdir $build_dir;
    system($^X, 'Makefile.PL');
    system($Config{make});

    local $ENV{AUTHOR_TESTING} = 1;
    do $file;

    $files_tested = Test::Builder->new->current_test;
};

is($files_tested, 4, 'correct number of files were tested, plus warnings checked');

chdir $cwd;

done_testing;
