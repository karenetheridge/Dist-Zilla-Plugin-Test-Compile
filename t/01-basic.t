use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;
use Test::Deep;

use lib 't/lib';
use Helper;

BEGIN {
    use Dist::Zilla::Plugin::Test::Compile;
    $Dist::Zilla::Plugin::Test::Compile::VERSION = 9999
        unless $Dist::Zilla::Plugin::Test::Compile::VERSION;
}


my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
                [ MakeMaker => ],
                [ ExecDir => ],
                [ MetaConfig => ],
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
            path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
            path(qw(source lib Bar.pod)) => qq{die 'this .pod file is not valid perl!';\n},
            path(qw(source lib Baz Quz.pm)) => "package Baz::Quz;\n1;\n",
            path(qw(source bin foobar)) => <<'FOOBAR',
#!/usr/bin/perl
print "foo\n";
FOOBAR
        },
    },
);

$tzil->chrome->logger->set_debug(1);
# XXX run in an exception{}
$tzil->build;

my $build_dir = path($tzil->tempdir)->child('build');
my $file = $build_dir->child(qw(t 00-compile.t));
ok(-e $file, 'test created');

my $content = $file->slurp_utf8;
unlike($content, qr/[^\S\n]\n/m, 'no trailing whitespace in generated test');

my @files = (
    path(qw(Foo.pm)),
    path(qw(Baz.pm)),
    path(qw(Baz Quz.pm)),
    path(qw(bin foobar)),
);

like($content, qr/'\Q$_\E'/m, "test checks $_") foreach @files;

cmp_deeply(
    $tzil->distmeta,
    superhashof({
        prereqs => {
            configure => ignore,            # populated by [MakeMaker]
            test => {
                requires => {
                    'Test::More' => '0.94',
                    'File::Spec' => '0',
                    'IPC::Open3' => '0',
                    'IO::Handle' => '0',
                    'File::Temp' => '0',
                },
            },
        },
        x_Dist_Zilla => superhashof({
            plugins => supersetof(
                {
                    class => 'Dist::Zilla::Plugin::Test::Compile',
                    config => {
                        'Dist::Zilla::Plugin::Test::Compile' => {
                            module_finder => [ ':InstallModules' ],
                            script_finder => [ ':ExecFiles' ],
                            filename => 't/00-compile.t',
                            fake_home => 1,
                            needs_display => 0,
                            fail_on_warning => 'author',
                            bail_out_on_fail => 1,
                            phase => 'test',
                            skips => [],
                        },
                    },
                    name => 'Test::Compile',
                    version => ignore,
                },
            ),
        }),
    }),
    'prereqs are properly injected for the test phase; dumped configs are good',
) or diag 'got distmeta: ', explain $tzil->distmeta;

<<<<<<< Updated upstream
run_test_file($tzil, $file);
my $tb = Test::Builder->new;
diag explain($tb->details);

# XXX need to get this out of $tb
# XXX can we use Test::Stream::Context for this stuff?
my $files_tested = 20;
=======
my $files_tested;
subtest 'run the generated test' => sub
{
# XXX see DynamicPrereqs for a better way of running this
    my $wd = pushd $build_dir;
    $tzil->plugin_named('MakeMaker')->build;
>>>>>>> Stashed changes

#subtest 'run the generated test' => sub
#{
## XXX see DynamicPrereqs for a better way of running this
#    my $wd = pushd $build_dir;
#    $tzil->plugin_named('MakeMaker')->build;
#
#    local $ENV{AUTHOR_TESTING} = 1;
#    do $file;
#
#           # XXX TEST -- what happens if the test warns? does that get picked
#           up by Test::Warnings?  or does it just go to stderr and we need to
#           capture it, e.g. via Helper.pm?
#
#    note 'ran tests successfully' if not $@;
#    fail($@) if $@;
#
#    $files_tested = Test::Builder->new->current_test;
#};

# use t/lib/Helper run_makemaker
# and then.. how to run the test?
# do as in t/15

is($files_tested, @files + 1, 'correct number of files were tested, plus warnings checked');

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
