use 5.008;
use strict;
use warnings;

package Dist::Zilla::Plugin::Test::Compile;
# ABSTRACT: common tests to check syntax of your modules

use Moose;
use Path::Tiny;
use Sub::Exporter::ForMethods 'method_installer'; # method_installer returns a sub.
use Data::Section 0.004 # fixed header_re
    { installer => method_installer }, '-setup';

with (
    'Dist::Zilla::Role::FileGatherer',
    'Dist::Zilla::Role::FileMunger',
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
use namespace::autoclean;

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
    default => sub { shift->bail_out_on_fail ? '0.94' : '0' },
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
        'IPC::Open3' => 0,
        'IO::Handle' => 0,
        $self->fake_home ? ( 'File::Temp' => '0' ) : (),
    );
}

sub gather_files
{
    my $self = shift;

    require Dist::Zilla::File::InMemory;

    for my $file (qw( t/00-compile.t )){
        $self->add_file( Dist::Zilla::File::InMemory->new(
            name => $file,
            content => ${$self->section_data($file)},
        ));
    }
}

sub munge_file
{
    my ($self, $file) = @_;

    # cannot check full name, as the file may have been moved by [ExtraTests].
    return unless $file->name =~ /\b00-compile.t$/;

    my @skips = map {; qr/$_/ } $self->skips;

    # we strip the leading lib/, and convert win32 \ to /, so the %INC entry
    # is correct - to avoid potentially loading the file again later
    my @module_filenames = map { path($_)->relative('lib')->stringify } $self->_module_filenames;

    @module_filenames = grep {
        (my $module = $_) =~ s{[/\\]}{::}g;
        $module =~ s/\.pm$//;
        not grep { $module =~ $_ } @skips
    } @module_filenames if @skips;

    # pod never returns true when loaded
    @module_filenames = grep { !/\.pod$/ } @module_filenames;

    my @script_filenames = $self->_script_filenames;

    $self->log_debug('adding module ' . $_) foreach @module_filenames;
    $self->log_debug('adding script ' . $_) foreach @script_filenames;

    $file->content(
        $self->fill_in_string(
            $file->content,
            {
                dist => \($self->zilla),
                plugin => \$self,
                test_more_version => \($self->_test_more_version),
                module_filenames => \@module_filenames,
                script_filenames => \@script_filenames,
                fake_home => \($self->fake_home),
                needs_display => \($self->needs_display),
                bail_out_on_fail => \($self->bail_out_on_fail),
                fail_on_warning => \($self->fail_on_warning),
            }
        )
    );

    return;
}

__PACKAGE__->meta->make_immutable;

=for Pod::Coverage::TrustPod
    mvp_multivalue_args
    mvp_aliases
    register_prereqs
    gather_files
    munge_file


=head1 SYNOPSIS

In your F<dist.ini>:

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

=back

This plugin accepts the following options:

=over 4

=item * C<skip>: a regex to skip compile test for modules matching it. The
match is done against the module name (C<Foo::Bar>), not the file path
(F<lib/Foo/Bar.pm>).  This option can be repeated to specify multiple regexes.

=for stopwords cpantesters

=item * C<fake_home>: a boolean to indicate whether to fake C<< $ENV{HOME} >>.
This may be needed if your module unilaterally creates stuff in the user's home directory:
indeed, some cpantesters will smoke test your dist with a read-only home
directory. Default to false.

=item * C<needs_display>: a boolean to indicate whether to skip the compile test
on non-Win32 systems when C<< $ENV{DISPLAY} >> is not set. Defaults to false.

=item * C<fail_on_warning>: a string to indicate when to add a test for
warnings during compilation checks. Possible values are:

=over 4

=item * C<none>: do not test for warnings

=item * C<author>: test for warnings only when AUTHOR_TESTING is set
(default, and recommended)

=item * C<all>: always test for warnings (not recommended, as this can prevent
installation of modules when upstream dependencies exhibit warnings in a new
Perl release)

=back

=item * C<bail_out_on_fail>: a boolean to indicate whether the test will BAIL_OUT
of all subsequent tests when compilation failures are encountered. Defaults to false.

=item * C<module_finder>

=for stopwords FileFinder

This is the name of a L<FileFinder|Dist::Zilla::Role::FileFinder> for finding
modules to check.  The default value is C<:InstallModules>; this option can be
used more than once.  .pod files are always omitted.

Other pre-defined finders are listed in
L<Dist::Zilla::Role::FileFinderUser/default_finders>.
You can define your own with the
L<[FileFinder::ByName]|Dist::Zilla::Plugin::FileFinder::ByName> plugin.

=item * C<script_finder>

=for stopwords executables

Just like C<module_finder>, but for finding scripts.  The default value is
C<:ExecFiles> (see also L<Dist::Zilla::Plugin::ExecDir>, to make sure these
files are properly marked as executables for the installer).

=back

=head1 SEE ALSO

=over 4

=item * L<Test::NeedsDisplay>

=item * L<Test::Script>

=back

=cut

__DATA__
___[ t/00-compile.t ]___
use strict;
use warnings;

# this test was generated with {{ ref($plugin) . ' ' . $plugin->VERSION }}

use Test::More {{ $test_more_version || '' }} tests => {{
    my $count = @module_filenames + @script_filenames;
    $count += 1 if $fail_on_warning eq 'all';
    $count .= ' + ($ENV{AUTHOR_TESTING} ? 1 : 0)' if $fail_on_warning eq 'author';
    $count;
}};

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

my @module_files = (
{{ join(",\n", map { "    '" . $_ . "'" } map { s/'/\\'/g; $_ } sort @module_filenames) }}
);

{{
    @script_filenames
        ? 'my @scripts = (' . "\n"
          . join(",\n", map { "    '" . $_ . "'" } map { s/'/\\'/g; $_ } sort @script_filenames)
          . "\n" . ');'
        : ''
}}

{{
$fake_home
    ? <<'CODE'
# fake home for cpan-testers
use File::Temp;
local $ENV{HOME} = File::Temp::tempdir( CLEANUP => 1 );
CODE
    : '# no fake home requested';
}}

use IPC::Open3;
use IO::Handle;

my @warnings;
for my $lib (@module_files)
{
    # see L<perlfaq8/How can I capture STDERR from an external command?>
    my $stdin = '';     # converted to a gensym by open3
    my $stderr = IO::Handle->new;

    my $pid = open3($stdin, '>&STDERR', $stderr, qq{$^X -Mblib -e"require q[$lib]"});
    waitpid($pid, 0);
    is($? >> 8, 0, "$lib loaded ok");

    if (my @_warnings = <$stderr>)
    {
        warn @_warnings;
        push @warnings, @_warnings;
    }
}

{{
@script_filenames
    ? <<'CODE'
foreach my $file (@scripts)
{ SKIP: {
    open my $fh, '<', $file or warn("Unable to open $file: $!"), next;
    my $line = <$fh>;
    close $fh and skip("$file isn't perl", 1) unless $line =~ /^#!.*?\bperl\b\s*(.*)$/;

    my $flags = $1;

    my $stdin = '';     # converted to a gensym by open3
    my $stderr = IO::Handle->new;

    my $pid = open3($stdin, '>&STDERR', $stderr, qq{$^X -Mblib $flags -c $file});
    waitpid($pid, 0);
    is($? >> 8, 0, "$file compiled ok");

    if (my @_warnings = grep { chomp; !/\bsyntax OK$/ } <$stderr>)
    {
        # temporary measure - win32 newline issues?
        warn map { _show_whitespace($_) } @_warnings;
        push @warnings, @_warnings;
    }
} }

sub _show_whitespace
{
    my $string = shift;
    $string =~ s/\n/[\\n]/g;
    $string =~ s/\r/[\\r]/g;
    $string =~ s/\t/[\\t]/g;
    $string =~ s/ /[\\s]/g;
    return $string;
}

CODE
    : '';
}}

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
$bail_out_on_fail
    ? 'BAIL_OUT("Compilation problems") if !Test::More->builder->is_passing;'
    : '';
}}
