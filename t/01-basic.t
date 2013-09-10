use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;
use Cwd;
use Config;
use version;

# build fake dist
my $tzil = Builder->from_config({
    dist_root => path(qw(t test-compile)),
});
$tzil->build;

my $build_dir = $tzil->tempdir->subdir('build');
my $file = path($build_dir, 't', '00-compile.t');
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
    warn $@ if $@;

    $files_tested = Test::Builder->new->current_test;
};

is($files_tested, @files + 1, 'correct number of files were tested, plus warnings checked');

chdir $cwd;

done_testing;
