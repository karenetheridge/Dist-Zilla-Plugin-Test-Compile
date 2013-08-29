use strict;
use warnings;

use Test::More;
use Test::Warnings;
use Test::DZil;
use Path::Class;
use Cwd;
use Config;
use JSON;
use Module::CoreList 2.77;
use version;

# build fake dist
my $tzil = Builder->from_config({
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


# confirm that all injected prereqs are in core

my $minimum_perl = version->parse('5.006002');  # minimum perl for any version of the prereq
my $in_core_perl = version->parse('5.012000');  # minimum perl to contain the version we use

my $metadata = JSON->new->ascii(1)->decode($tzil->slurp_file('build/META.json'));

foreach my $prereq (keys %{$metadata->{prereqs}{test}{requires}})
{
    my $added_in = Module::CoreList->first_release($prereq);

    # this code is borrowed ethusiastically from [OnlyCorePrereqs]
    fail('detected a ' . 'test'
        . ' requires dependency that is not in core: ' . $prereq)
            if not defined $added_in;

    fail('detected a ' . 'test'
        . ' requires dependency that was not added to core until '
        . $added_in . ': ' . $prereq)
            if version->parse($added_in) > $minimum_perl;

    my $has = $Module::CoreList::version{$in_core_perl->numify}{$prereq};
    $has = version->parse($has);    # version.pm XS hates tie() - RT#87983
    my $wanted = version->parse($metadata->{prereqs}{test}{requires}{$prereq});

    fail('detected a ' . 'test' . ' requires dependency on '
        . $prereq . ' ' . $wanted . ': perl ' . $in_core_perl
        . ' only has ' . $has)
                if $has < $wanted;

    my $deprecated_in = Module::CoreList->deprecated_in($prereq);
    fail('detected a ' . 'test'
        . ' requires dependency that was deprecated from core in '
        . $deprecated_in . ': '. $prereq)
            if $deprecated_in;

    pass("$prereq is available in perl $minimum_perl");
    pass("$prereq $wanted is available in perl $in_core_perl") if $wanted;
}

chdir $cwd;

done_testing;
