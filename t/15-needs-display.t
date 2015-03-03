use strict;
use warnings;

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;
use Test::Deep;

use lib 't/lib';
use Helper;

foreach my $display (undef, ':0.0')
{
    local $ENV{DISPLAY} = $display;

    my $tzil = Builder->from_config(
        { dist_root => 't/does-not-exist' },
        {
            add_files => {
                path(qw(source dist.ini)) => simple_ini(
                    [ GatherDir => ],
                    [ MakeMaker => ],
                    [ ExecDir => ],
                    [ 'Test::Compile' => { needs_display => 1 } ],
                ),
                path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
            },
        },
    );

    $tzil->chrome->logger->set_debug(1);
    $tzil->build;

    my $build_dir = path($tzil->tempdir)->child('build');
    my $file = $build_dir->child(qw(t 00-compile.t));
    ok( -e $file, 'test created');

    my $display_str = $display || '<undef>';

    if (run_test_file($tzil, $file, "run the generated test (\$DISPLAY=$display_str)"))
    {
        my $tb = Test::Builder->new;
        my $skip = !$ENV{DISPLAY} && $^O ne 'MSWin32';
        cmp_deeply(
            # run_test_file had 3 tests; we care about the first.
            ($tb->details)[$tb->current_test - 3],
            superhashof({
               ok       => 1,
               type     => !$skip ? '' : 'skip',
               reason   => !$skip ? '' : 'Needs DISPLAY',
               name     => !$skip
                            ? "run the generated test (\$DISPLAY=$display_str)"
                            : any('', "run the generated test (\$DISPLAY=$display_str)"),   # older TB handled this oddly
            }),
            !$skip ? 'test file ran successfully' : 'test file skipped because $DISPLAY was not set',
        );
    }

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
}

done_testing;
