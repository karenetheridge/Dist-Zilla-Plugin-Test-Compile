use strict;
use warnings;

use Dist::Zilla::Tester;
use Path::Class;
use Cwd;
use Test::More tests => 2;

# build fake dist
my $tzil = Dist::Zilla::Tester->from_config({
    dist_root => dir(qw(t test-compile)),
});
my $cwd = getcwd;
chdir $tzil->tempdir->subdir('source');
$tzil->build;

my $dir = $tzil->tempdir->subdir('build');
my $file = file($dir, 't', '00-compile.t');
ok( -e $file, 'test created');

unlike($file->slurp(chomp => 1), qr/\s$/m, 'no trailing whitespace in generated test');

chdir $cwd;
