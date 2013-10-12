# NAME

Dist::Zilla::Plugin::Test::Compile - common tests to check syntax of your modules, only using core modules

# VERSION

version 2.035

# SYNOPSIS

In your `dist.ini`:

    [Test::Compile]
    skip      = Test$
    fake_home = 1
    needs_display = 1
    fail_on_warning = author
    bail_out_on_fail = 1

# DESCRIPTION

This is a [Dist::Zilla](http://search.cpan.org/perldoc?Dist::Zilla) plugin that runs at the [gather files](http://search.cpan.org/perldoc?Dist::Zilla::Role::FileGatherer) stage,
providing a test file (configurable, defaulting to `t/00-compile.t`).

This test will find all modules and scripts in your dist, and try to
compile them one by one. This means it's a bit slower than loading them
all at once, but it will catch more errors.

The generated test is guaranteed to only depend on modules that are available
in core.  Most options only require perl 5.6.2; the `bail_out_on_fail` option
requires the version of [Test::More](http://search.cpan.org/perldoc?Test::More) that shipped with perl 5.12 (but the
test still runs on perl 5.6).

This plugin accepts the following options:

- `filename`: the name of the generated file. Defaults to
`t/00-compile.t`.
- `phase`: the phase for which to register prerequisites. Defaults
to `test`.  Setting this to a false value will disable prerequisite
registration.
- `skip`: a regex to skip compile test for modules matching it. The
match is done against the module name (`Foo::Bar`), not the file path
(`lib/Foo/Bar.pm`).  This option can be repeated to specify multiple regexes.
- `fake_home`: a boolean to indicate whether to fake `$ENV{HOME}`.
This may be needed if your module unilaterally creates stuff in the user's home directory:
indeed, some cpantesters will smoke test your dist with a read-only home
directory. Default to false.
- `needs_display`: a boolean to indicate whether to skip the compile test
on non-Win32 systems when `$ENV{DISPLAY}` is not set. Defaults to false.
- `fail_on_warning`: a string to indicate when to add a test for
warnings during compilation checks. Possible values are:
    - `none`: do not test for warnings
    - `author`: test for warnings only when AUTHOR\_TESTING is set
    (default, and recommended)
    - `all`: always test for warnings (not recommended, as this can prevent
    installation of modules when upstream dependencies exhibit warnings in a new
    Perl release)
- `bail_out_on_fail`: a boolean to indicate whether the test will BAIL\_OUT
of all subsequent tests when compilation failures are encountered. Defaults to false.
- `module_finder`

    This is the name of a [FileFinder](http://search.cpan.org/perldoc?Dist::Zilla::Role::FileFinder) for finding
    modules to check.  The default value is `:InstallModules`; this option can be
    used more than once.  .pod files are always omitted.

    Other predefined finders are listed in
    ["default\_finders" in Dist::Zilla::Role::FileFinderUser](http://search.cpan.org/perldoc?Dist::Zilla::Role::FileFinderUser#default\_finders).
    You can define your own with the
    [\[FileFinder::ByName\]](http://search.cpan.org/perldoc?Dist::Zilla::Plugin::FileFinder::ByName) plugin.

- `script_finder`

    Just like `module_finder`, but for finding scripts.  The default value is
    `:ExecFiles` (see also [Dist::Zilla::Plugin::ExecDir](http://search.cpan.org/perldoc?Dist::Zilla::Plugin::ExecDir), to make sure these
    files are properly marked as executables for the installer).

# SEE ALSO

- [Test::NeedsDisplay](http://search.cpan.org/perldoc?Test::NeedsDisplay)
- [Test::Script](http://search.cpan.org/perldoc?Test::Script)

# AUTHOR

Jerome Quelin

# COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Jerome Quelin.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

# CONTRIBUTORS

- Ahmad M. Zawawi <azawawi@ubuntu.(none)>
- Chris Weyl <cweyl@alumni.drew.edu>
- David Golden <dagolden@cpan.org>
- Graham Knop <haarg@haarg.org>
- Harley Pig <harleypig@gmail.com>
- Jerome Quelin <jquelin@gmail.com>
- Jesse Luehrs <doy@tozt.net>
- Karen Etheridge <ether@cpan.org>
- Kent Fredric <kentfredric@gmail.com>
- Marcel Gruenauer <hanekomu@gmail.com>
- Olivier Mengué <dolmen@cpan.org>
- Peter Shangov <pshangov@yahoo.com>
- Randy Stauner <randy@magnificent-tears.com>
- Ricardo SIGNES <rjbs@cpan.org>
- fayland <fayland@gmail.com>
