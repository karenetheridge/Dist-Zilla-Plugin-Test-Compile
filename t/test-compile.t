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

my $content = $file->slurp;
unlike($content, qr/[^\S\n]\n/m, 'no trailing whitespace in generated test');

my @files = qw(
    Foo.pm
    Baz.pm
    Baz/Quz.pm
    bin/foobar
);

like($content, qr/'\Q$_\E'/m, "test checks $_") foreach @files;

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

is($files_tested, @files + 1, 'correct number of files were tested, plus warnings checked');

chdir $cwd;

done_testing;
