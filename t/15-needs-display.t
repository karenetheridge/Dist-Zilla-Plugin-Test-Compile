use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Path::Tiny;
use File::pushd 'pushd';
use Test::Deep;

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

    my $error;
    subtest 'run the generated test ($DISPLAY=' . ($display || '<undef>') . ')' => sub
    {
        my $wd = pushd $build_dir;
        $tzil->plugin_named('MakeMaker')->build;

        # I'm not sure why, but if we just 'do $file', we get the
        # Test::Builder::Exception object back in $@ that is actually being
        # used for flow control in Test::Builder::skip_all -- but if we
        # compile the code first and then run it, TB works properly and the
        # skip functionality completes
        my $test = eval 'sub { ' . $file->slurp_utf8 . ' }';
        return $error = $@ if $@;
        $test->();
    };

    if ($error)
    {
        fail('failed to compile test file: ' . $error);
    }
    else
    {
        my $tb = Test::Builder->new;
        cmp_deeply(
            $tb->{Test_Results}[$tb->current_test - 1],
            superhashof({
               ok       => 1,
               type     => 'skip',
               reason   => 'Needs DISPLAY',
            }),
            'test file skipped because $DISPLAY was not set',
        ) if not $ENV{DISPLAY};
    }

    diag 'got log messages: ', explain $tzil->log_messages
        if not Test::Builder->new->is_passing;
}

done_testing;
