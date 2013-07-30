use 5.008;
use strict;
use warnings;

package Dist::Zilla::Plugin::Test::Compile;
# ABSTRACT: common tests to check syntax of your modules

use Moose;
use Data::Section -setup;
with (
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::TextTemplate',
    'Dist::Zilla::Role::FileFinderUser' => {
        method          => 'found_module_files',
        finder_arg_names => [ 'module_finder' ],
        default_finders => [ ':InstallModules' ],
    },
    'Dist::Zilla::Role::FileFinderUser' => {
        method          => 'found_script_files',
        finder_arg_names => [ 'script_finder' ],
        default_finders => [ ':ExecFiles' ],
    },
    'Dist::Zilla::Role::PrereqSource',
);

use Moose::Util::TypeConstraints;

# -- attributes

has fake_home     => ( is=>'ro', isa=>'Bool', default=>0 );
has needs_display => ( is=>'ro', isa=>'Bool', default=>0 );
has fail_on_warning => ( is=>'ro', isa=>enum([qw(none author all)]), default=>'author' );
has bail_out_on_fail => ( is=>'ro', isa=>'Bool', default=>0 );

sub mvp_multivalue_args { qw(skips) }
sub mvp_aliases { return { skip => 'skips' } }

has skips => (
    isa => 'ArrayRef[Str]',
    traits => ['Array'],
    handles => { skips => 'elements' },
    default => sub { [] },
);

has _test_more_version => (
    is => 'ro', isa => 'Str',
    init_arg => undef,
    lazy => 1,
    default => sub { shift->bail_out_on_fail ? '0.94' : '0.88' },
);

# note that these two attributes could conceivably be settable via dist.ini,
# to avoid us using filefinders at all.
has _module_filenames  => (
    isa => 'ArrayRef[Str]',
    traits => ['Array'],
    handles => { _module_filenames => 'elements' },
    lazy => 1,
    default => sub { [ map { $_->name } @{shift->found_module_files} ] },
);
has _script_filenames => (
    isa => 'ArrayRef[Str]',
    traits => ['Array'],
    handles => { _script_filenames => 'elements' },
    lazy => 1,
    default => sub { [ map { $_->name } @{shift->found_script_files} ] },
);

around dump_config => sub
{
    my ($orig, $self) = @_;
    my $config = $self->$orig;

    $config->{'' . __PACKAGE__} = {
         module_finder => $self->module_finder,
         script_finder => $self->script_finder,
    };
    return $config;
};

sub register_prereqs
{
    my $self = shift;
    $self->zilla->register_prereqs(
        {
            type  => 'requires',
            phase => 'test',
        },
        'Test::More' => $self->_test_more_version,
        'Capture::Tiny' => '0',
        'blib' => '0',
        $self->fake_home ? ( 'File::Temp' => '0' ) : (),
        $self->_script_filenames ? ( 'Test::Script' => '1.05' ) : (),
    );
}

sub gather_files {

    my ( $self , ) = @_;

    my @skips = map {; qr/$_/ } $self->skips;

    my @module_filenames = $self->_module_filenames;
    @module_filenames = grep {
        (my $module = $_) =~ s{^lib/}{};
        $module=~ s{[/\\]}{::}g;
        $module=~ s/\.pm$//;
        not grep { $module =~ $_ } @skips
    } @module_filenames if @skips;

    # pod never returns true when loaded
    @module_filenames = grep { !/\.pod$/ } @module_filenames;

    require Dist::Zilla::File::InMemory;

    for my $file (qw( t/00-compile.t )){
        $self->add_file( Dist::Zilla::File::InMemory->new(
            name => $file,
            content => $self->fill_in_string(
                ${$self->section_data($file)},
                {
                    plugin_version => \($self->VERSION),
                    test_more_version => \($self->_test_more_version),
                    module_filenames => \@module_filenames,
                    script_filenames => [ $self->_script_filenames ],
                    fake_home => \($self->fake_home),
                    needs_display => \($self->needs_display),
                    bail_out_on_fail => \($self->bail_out_on_fail),
                    fail_on_warning => \($self->fail_on_warning),
                }
            ),
        ));
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=for Pod::Coverage::TrustPod
    mvp_multivalue_args
    mvp_aliases
    register_prereqs
    gather_files


=head1 SYNOPSIS

In your dist.ini:

    [Test::Compile]
    skip      = Test$
    fake_home = 1
    needs_display = 1
    fail_on_warning = author
    bail_out_on_fail = 1


=head1 DESCRIPTION

This is a plugin that runs at the L<gather files|Dist::Zilla::Role::FileGatherer> stage,
providing the following files:

=over 4

=item * F<t/00-compile.t> - a standard test to check syntax of bundled modules

This test will find all modules and scripts in your dist, and try to
compile them one by one. This means it's a bit slower than loading them
all at once, but it will catch more errors.

We currently only check F<bin/>, F<script/> and F<scripts/> for scripts.

=back


This plugin accepts the following options:

=over 4

=item * skip: a regex to skip compile test for modules matching it. The
match is done against the module name (C<Foo::Bar>), not the file path
(F<lib/Foo/Bar.pm>).  This option can be repeated to specify multiple regexes.

=item * fake_home: a boolean to indicate whether to fake C<< $ENV{HOME} >>.
This may be needed if your module unilateraly creates stuff in homedir:
indeed, some cpantesters will smoke test your dist with a read-only home
directory. Default to false.

=item * needs_display: a boolean to indicate whether to skip the compile test
on non-Win32 systems when C<< $ENV{DISPLAY} >> is not set. Defaults to false.

=item * fail_on_warning: a string to indicate when to add a test for
warnings during compilation checks. Possible values are:

=over 4

=item * none: do not check for warnings

=item * author: check for warnings only when AUTHOR_TESTING is set
(default, and recommended)

=item * all: always test for warnings (not recommended, as this can prevent
installation of modules when upstream dependencies exhibit warnings in a new
Perl release)

=item * module_finder

This is the name of a L<FileFinder|Dist::Zilla::Role::FileFinder> for finding
modules to check.  The default value is C<:InstallModules>; this option can be
used more than once.  .pod files are always omitted.

Other pre-defined finders are listed in
L<FileFinder|Dist::Zilla::Role::FileFinderUser/default_finders>.
You can define your own with the
L<Dist::Zilla::Plugin::FileFinder::ByName|[FileFinder::ByName]> plugin.

=item * script_finder

Just like C<module_finder>, but for finding scripts.  The default value is
C<:ExecFiles> (you can use the L<Dist::Zilla::Plugin::ExecDir> plugin to mark
those files as executables).

=back

=item * bail_out_on_fail: a boolean to indicate whether the test will BAIL_OUT
of all subsequent tests when compilation failures are encountered. Defaults to false.

=back

=head1 SEE ALSO

L<Test::NeedsDisplay>

You can also look for information on this module at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Dist-Zilla-Plugin-Test-Compile>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dist-Zilla-Plugin-Test-Compile>

=item * Open bugs

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Dist-Zilla-Plugin-Test-Compile>

=item * Git repository

L<http://github.com/jquelin/dist-zilla-plugin-test-compile.git>.

=back

=cut

__DATA__
___[ t/00-compile.t ]___
use strict;
use warnings;

# This test was generated via Dist::Zilla::Plugin::Test::Compile {{ $plugin_version }}

use Test::More {{ $test_more_version }};

{{
$needs_display
    ? <<'CODE'
BEGIN {
    # Skip all tests if you need a display for this test and $ENV{DISPLAY} is not set
    if( not $ENV{DISPLAY} and not $^O eq 'MSWin32' ) {
        plan skip_all => 'Needs DISPLAY';
        exit 0;
    }
}
CODE
    : ''
}}

use Capture::Tiny qw{ capture };

my @module_files = qw(
{{ join("\n", sort @module_filenames) }}
);

my @scripts = qw(
{{ join("\n", sort @script_filenames) }}
);

{{
$fake_home
    ? <<'CODE'
# fake home for cpan-testers
use File::Temp;
local $ENV{HOME} = File::Temp::tempdir( CLEANUP => 1 );
CODE
    : '# no fake home requested';
}}

my @warnings;
for my $lib (@module_files)
{
    my ($stdout, $stderr, $exit) = capture {
        system($^X, '-Mblib', '-e', qq{require qq[$lib]});
    };
    is($?, 0, "$lib loaded ok");
    warn $stderr if $stderr;
    push @warnings, $stderr if $stderr;
}

{{
($fail_on_warning ne 'none'
    ? q{is(scalar(@warnings), 0, 'no warnings found')}
    : '# no warning checks')
.
($fail_on_warning eq 'author'
    ? ' if $ENV{AUTHOR_TESTING};'
    : ';')
}}

{{
@script_filenames
    ? <<'CODE'
use Test::Script 1.05;
foreach my $file ( @scripts ) {
    script_compiles( $file, "$file compiles" );
}
CODE
    : '';
}}

{{
$bail_out_on_fail
    ? 'BAIL_OUT("Compilation problems") if !Test::More->builder->is_passing;'
    : '';
}}

done_testing;
