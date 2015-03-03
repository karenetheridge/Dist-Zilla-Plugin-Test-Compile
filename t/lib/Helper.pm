use strict;
use warnings;

use Test::More ();
use Test::Fatal ();
use Path::Tiny ();
use File::pushd ();
use Capture::Tiny ();

sub run_test_file
{
    my ($tzil, $file, $test_name) = @_;

    $test_name ||= 'run the generated test';

    my ($exception, $stdout, $stderr, @rest);

    subtest $test_name => sub
    {
        ($stdout, $stderr, @rest) = Capture::Tiny::capture { $exception =
            Test::Fatal::exception {
                my $wd = File::pushd::pushd(Path::Tiny::path($tzil->tempdir)->child('build'));
                $tzil->plugin_named('MakeMaker')->build;

                # I'm not sure why, but if we just 'do $file', we get the
                # Test::Builder::Exception object back in $@ that is actually
                # being used for flow control in Test::Builder::skip_all --
                # but if we compile the code first and then run it, TB works
                # properly and the skip functionality completes
                my $test = eval 'sub { ' . $file->slurp_utf8 . ' }';
                die $@ if $@;
                $test->();
            }
        };
    };

    Test::More::note($stdout) if defined $stdout;
    Test::More::is($exception, undef, "failed to compile $file")
        or diag $stderr;

    # strangely, MakeMaker->build gives stderr='', but $test->() gives stderr=undef
    Test::More::ok((not defined $stderr or $stderr eq ''), "running $file did not produce warnings");
    return !$exception;
}

1;
