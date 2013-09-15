use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;
use Cwd;
use Config;

BEGIN {
    use Dist::Zilla::Plugin::Test::Compile;
    $Dist::Zilla::Plugin::Test::Compile::VERSION = 9999
        unless $Dist::Zilla::Plugin::Test::Compile::VERSION;
}


# build fake dist
my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            'source/dist.ini' => simple_ini(
                [ GatherDir => ],
                [ MakeMaker => ],
                [ ExecDir => ],
                [ MetaJSON => ],
                [ 'Test::Compile' => { bail_out_on_fail => 1, fake_home => 1, } ],
                # we generate a new module after we insert the compile test,
                # to confirm that this module is picked up too
                [ GenerateFile => 'file-from-code' => {
                        filename => 'lib/Baz.pm',
                        is_template => 0,
                        content => [ 'package Baz;', '$VERSION = 0.001;', '1;' ],
                    },
                ],
            ),
            path(qw(source lib Foo.pm)) => <<'FOO',
package Foo;
# ABSTRACT: Foo
1;
__END__
FOO
            path(qw(source lib Bar.pod)) => qq{die 'this .pod file is not valid perl!';\n},
            path(qw(source lib Baz Quz.pm)) => <<'BAZQUZ',
package Baz::Quz;
# ABSTRACT: Baz::Quz
1;
__END__
BAZQUZ
            path(qw(source bin foobar)) => <<'FOOBAR',
#!/usr/bin/perl
print "foo\n";
FOOBAR
        },
    },
);
$tzil->build;

my $build_dir = $tzil->tempdir->subdir('build');
my $file = path($build_dir, 't', '00-compile.t');
ok( -e $file, 'test created');

my $content = $file->slurp;
unlike($content, qr/[^\S\n]\n/m, 'no trailing whitespace in generated test');

my @files = (
    path(qw(Foo.pm)),
    path(qw(Baz.pm)),
    path(qw(Baz Quz.pm)),
    path(qw(bin foobar)),
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
