package App::Dn::PassDump;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.5');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(confess croak);
use Const::Fast;
use Date::Simple;
use English;
use Env qw($HOME);
use File::Find::Rule;
use IPC::Run qw(timeout);
use MooX::HandlesVia;
use MooX::Options protect_argv => 0;
use Term::ProgressBar::Simple;
use Text::Wrap;
use Types::Path::Tiny;
use Type::Tiny;
use Types::Standard;

const my $TRUE    => 1;
const my $FALSE   => 0;
const my $DIVIDER => '--------------------------';
const my $INDENT  => 5;
const my $SPACE   => q{ };
const my $TABSTOP => 4;
const my $TIMEOUT => 30;
const my $WIDTH   => 75;                             # }}}1

# options

# author    (-a)    {{{1
option 'author' => (
  is      => 'ro',
  format  => 's@',
  default => sub { [] },
  short   => 'a',
  doc     => q{Author of output file [default: 'David Nebauer']},
);

# dump_file (-d)    {{{1
option 'dump_file' => (
  is      => 'ro',
  format  => 's@',         ## no critic (ProhibitDuplicateLiteral)
  default => sub { [] },
  short   => 'd',
  doc     => 'Output file path [default=~/.password-store/dump.{md,txt}]',
);

# format    (-f)    {{{1
option 'format' => (
  is      => 'ro',
  format  => 's@',         ## no critic (ProhibitDuplicateLiteral)
  default => sub { [] },
  short   => 'f',
  doc     => q{Output format ['markdown' (default) or 'text']},
);

# preserve  (-p)    {{{1
option 'preserve' => (
  is        => 'ro',
  short     => 'p',
  negatable => $TRUE,
  doc       => 'Preserve existing output file [default: false]',
);

# root_dir  (-r)    {{{1
option 'root_dir' => (
  is      => 'ro',
  format  => 's@',         ## no critic (ProhibitDuplicateLiteral)
  default => sub { [] },
  short   => 'r',
  doc     => 'Root of passwords directory tree [default=~/.password-store]',
);                         # }}}1

# attributes

# _author    {{{1
has '_author' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self    = shift;
    my @authors = @{ $self->author };
    confess 'Multiple author names provided' if scalar @authors > 1;
    return $authors[0] if @authors;    # only one value from user
    my $default = 'David Nebauer';     # no value, so use default
    say "Using default user: $default" or croak;
    return $default;
  },
  doc => q{Validate and return value of 'author' option},
);

# _dump_file    {{{1
has '_dump_file' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsPath,
  coerce  => Types::Path::Tiny::AbsPath->coercion,
  lazy    => $TRUE,
  default => sub {
    my $self       = shift;
    my @dump_files = @{ $self->dump_file };
    confess 'Multiple dump file paths provided' if scalar @dump_files > 1;
    return $dump_files[0] if @dump_files;    # one value from user
    my $extension;                  # no filepath given, so use default
    my $format = $self->_format;    # default is based on format
    for ($format) {
      if    (/\Amarkdown\Z/xsm) { $extension = 'md'; }
      elsif (/\Atext\Z/xsm)     { $extension = 'txt'; }
      else                      { confess "Invalid format '$format'"; }
    }
    my $default = "$HOME/.password-store/dump.$extension";
    say "Using default $format dump file: $default" or croak;
    return $default;
  },
  doc => q{Validate and return value of 'dump_file' option},
);

# _format    {{{1
my $valid_format = Type::Tiny->new(
  name       => 'ValidFormat',
  constraint => sub {/\Amarkdown|text\Z/xsm},
  message    => sub {"format: expected 'markdown'|'text', got '$_'"},
);

has '_format' => (
  is      => 'ro',
  isa     => $valid_format,
  lazy    => $TRUE,
  default => sub {
    my $self    = shift;
    my @formats = @{ $self->format };
    confess 'Multiple formats provided' if scalar @formats > 1;
    return $formats[0] if @formats;    # only one value from user
    my $default = 'markdown';          # no value provided so use default
    say "Using default format: $default" or croak;
    return $default;
  },
  doc => q{Validate and return value of 'format' option},
);

# _add_lines, _lines    {{{1
has '_lines_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _add_lines => 'push',
    _lines     => 'elements',
  },
  doc => 'Output lines',
);

# _pass_files    {{{1
has '_pass_files_list' => (
  is      => 'ro',
  isa     => Types::Standard::ArrayRef [Types::Path::Tiny::AbsFile],
  coerce  => $TRUE,
  lazy    => $TRUE,
  default => sub {
    my $self  = shift;
    my $root  = $self->_root_dir->canonpath;
    my @files = sort File::Find::Rule->file()->name('*.gpg')->in($root);
    die "No *.gpg files found in $root\n" if not @files;
    return [@files];
  },
  handles_via => 'Array',
  handles     => { _pass_files => 'elements' },
  doc         => 'Password files',
);

# _preserve    {{{1
has '_preserve' => (
  is      => 'ro',
  isa     => Types::Standard::Bool,
  lazy    => $TRUE,
  default => sub {
    my $self     = shift;
    my $preserve = $self->preserve;

    # defaults to undef if unset, which can read as false negative
    # if use a test like "if ($self->preserve) {...";
    # so set to false rather than leaving as undef
    if (not defined $preserve) {
      $preserve = $FALSE;
      say 'Will overwrite an existing dump file as per default setting'
          or croak;
    }
    return $preserve;
  },
  doc => q{Validate and return value of 'preserve' option},
);

# _root_dir    {{{1
has '_root_dir' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  coerce  => Types::Path::Tiny::AbsDir->coercion,
  lazy    => $TRUE,
  default => sub {
    my $self  = shift;
    my @roots = @{ $self->root_dir };
    confess 'Multiple root passwords directories provided'
        if scalar @roots > 1;
    return $roots[0] if @roots;               # one value provided by user
    my $default = "$HOME/.password-store";    # no value so use default
    say "Using default root passwords directory: $default" or croak;
    return $default;
  },
  doc => q{Validate and return value of 'root_dir' option},
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # check args
  $self->_check_args;

  # enter password if necessary
  $self->_enter_password;

  # assemble output
  $self->_assemble_output;

  # write output
  $self->_write_output;

  return;
}

# _assemble_entity_output($entity)    {{{1
#
# does:   assemble markdown-formatted output content for single entity
# params: $entity - entity whose details are to be used [string, required]
# prints: feedback
# return: n/a, dies on failure
sub _assemble_entity_output ($self, $entity)
{    ## no critic (RequireInterpolationOfMetachars)

  # for each entity extract:
  # - password (first line of extracted content)
  # - remaining content of entity file

  my (@cmd, $in, $out, $err);
  push @cmd, 'pass', 'show', $entity;
  IPC::Run::run \@cmd, \$in, \$out, \$err, timeout($TIMEOUT)
      or croak "pass: $CHILD_ERROR";
  chomp $out;
  my @content  = split /\n/xsm, $out;
  my $password = shift @content;

  my @out;

  # generate content depending on format
  my $format = $self->_format;
  for ($format) {
    if (/\Amarkdown\Z/xsm) {
      push @out, q{};
      push @out, "## $entity ##";
      push @out, q{};
      push @out, '~~~';
      push @out, "$password";
      push @out, '~~~';             ## no critic (ProhibitDuplicateLiteral)
      if (@content) {
        push @out, q{};
        for my $line (@content) {
          my @sanitised_lines = $self->_sanitise_line($line);
          for my $sanitised_line (@sanitised_lines) {
            push @out, "| $sanitised_line";
          }
        }
      }
      push @out, q{};
      push @out, '---';
    }
    elsif (/\Atext\Z/xsm) {
      push @out, q{};
      push @out, "$entity";
      push @out, q{};
      push @out, "  Password: $password";
      if (@content) {
        push @out, q{};
        for my $line (@content) {
          push @out, "  $line";
        }
      }
      push @out, q{};
      push @out, $DIVIDER;
    }
    else { confess "Invalid format '$format'"; }
  }

  $self->_add_lines(@out);
  return;
}

# _assemble_file_footer()    {{{1
#
# does:   assemble output file header
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _assemble_file_footer ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  my @out;

  push @out, q{}, 'END OF FILE';

  $self->_add_lines(@out);
  return;
}

# _assemble_file_header()    {{{1
#
# does:   assemble output file header
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _assemble_file_header ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  my $format = $self->_format;
  my $author = $self->_author;
  my $date   = Date::Simple->today()->format('%e %B %Y');
  $date =~ s/\A\s+//xsm;

  my @out;

  for ($format) {
    if (/\Amarkdown\Z/xsm) {
      push @out, '---',    ## no critic (ProhibitDuplicateLiteral)
          q{title:  'Password Dump'},
          "author: '$author'",
          "date:   '$date'",
          'style:  [Standard, Latex14pt]',
          '...';
    }
    elsif (/\Atext\Z/xsm) {
      push @out, 'Password Dump', q{}, "$author, $date", $DIVIDER;
    }
    else { confess "Invalid format '$format'"; }
  }

  $self->_add_lines(@out);
  return;
}

# _assemble_output()    {{{1
#
# does:   assemble output content
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _assemble_output ($self) {  ## no critic (RequireInterpolationOfMetachars)

  my $format = $self->_format;

  # generate file header
  $self->_assemble_file_header();

  # get list of entities and cycle through them
  # - filepath can have form like either of:
  #     /path/to/password/root/ENTITY.gpg
  #     /path/to/password/root/parent/ENTITY.gpg
  # - so:
  #     first strip root directory path
  #     then strip '.gpg' extension
  my $root     = $self->_root_dir;
  my @no_root  = map {s{\A$root/?}{}xsmr} $self->_pass_files;
  my @entities = map {s{[.]gpg\Z}{}xsmr} @no_root;
  my $count    = @entities;
  my $progress;
  say "Processing $count password files:" or croak;
  $progress = Term::ProgressBar::Simple->new($count);

  for my $entity (@entities) {
    $self->_assemble_entity_output($entity);
    $progress++;
  }
  undef $progress;    # ensure final messages display

  # generate file footer
  $self->_assemble_file_footer();

  return;
}

# _check_args()    {{{1
#
# does:   check arguments
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _check_args ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # check format and author    {{{2
  # - because their constructors are lazy they can cause errors
  #   after user interaction
  # - force checks associated with instantiation
  my $format = $self->_format;
  my $author = $self->_author;

  # check for existing output file    {{{2
  # - to determine whether to preserve before generate output
  my $dump_file = $self->_dump_file->canonpath;
  my $preserve  = $self->_preserve;
  if (-e $dump_file) {
    if ($preserve) {
      warn "You have opted to preserve an existing dump file\n";
      die "Dump file '$dump_file' already exists\n";
    }
    else {    # do not preserve
      if (not(unlink $dump_file)) {    # sets $ERRNO on failure
        my @err = (
          "Unable to delete existing dump file '$dump_file'\n",
          "Error: $ERRNO\n",
        );
        confess @err;
      }
    }
  }    # }}}2
  return;
}

# _enter_password()    {{{1
#
# does:   gets user to enter password if necessary
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _enter_password ($self) {   ## no critic (RequireInterpolationOfMetachars)

  # advise user of what is happening
  say 'To ensure the master password is cached, this module' or croak;
  say 'will access the first password file; you may need'    or croak;
  say 'to enter the master password...'                      or croak;

  # access first entity
  my $root    = $self->_root_dir;
  my $fp      = ($self->_pass_files)[0];
  my $no_root = $fp      =~ s{\A$root/?}{}xsmr;
  my $entity  = $no_root =~ s/[.]gpg\Z//xsmr;

  system "pass show $entity &>/dev/null";

  say 'First password file accessed successfully!' or croak;

  return;
}

# _sanitise_line($line)    {{{1
#
# does:   enclose in backticks if necessary
#         if not backtick-enclosed, split long string over multiple lines
# params: $line - line to sanitise [string, required]
# prints: feedback
# return: list of string scalars, dies on failure
sub _sanitise_line ($self, $line)
{    ## no critic (RequireInterpolationOfMetachars)

  my @output;

  # enclose value in backticks if contain '/' or '\'    {{{2
  if ($line =~ m{[\/\\]}xsm) {
    $line =~ /:\s/xsm;    # put end of ': ' match in $LAST_PAREN_MATCH[0]
    my $label = substr $line, 0, $LAST_PAREN_MATCH[0];
    my $value = substr $line, $LAST_PAREN_MATCH[0];
    push @output, "$label`$value`";
    return @output;
  }

  # return string unchanged if not overlong    {{{2
  my $width = $WIDTH;
  if (length $line <= $width) {
    push @output, $line;
    return @output;
  }

  # split long string into multiple lines    {{{2
  # - bug in Text::Wrap adds '0' to beginning of each output line;
  #   avoid by adding extra space to beginning of each line;
  #   done with q{ }/$SPACE as first param to wrap, and +1 space to $indent;
  #   after operation remove that space from each output line;
  # ! perlcritic wants escaped chars in regex to be put in one-character
  #   character classes as per PBP p 247, but doing so causes it to stop
  #   breaking on commas; this occurred despite much tweaking, so leave
  #   as is and ignore perlcritic on this score!
  ## no critic (ProhibitEscapedMetacharacters)
  my $break = qr{(?<=[\\\/\+=,\?\s])}xsm;
  ## use critic
  my $indent = $SPACE x $INDENT;      # final indent will be four spaces
  local $Text::Wrap::break = $Text::Wrap::break;
  $Text::Wrap::break = $break;
  local $Text::Wrap::columns = $Text::Wrap::columns;
  $Text::Wrap::columns = $width;
  local $Text::Wrap::unexpand = $Text::Wrap::unexpand;
  $Text::Wrap::unexpand = $FALSE;     # no tabs in output
  local $Text::Wrap::tabstop = $Text::Wrap::tabstop;
  $Text::Wrap::tabstop = $TABSTOP;    # default of 8 is too large
  local $Text::Wrap::huge = $Text::Wrap::huge;
  $Text::Wrap::huge = 'wrap';         # default, do not die on huge words
  $line =~ /:\s/xsm;                  # locate ': '
  my @split = split /\n/xsm, Text::Wrap::wrap($SPACE, $indent, ($line));
  my @lines = map {s/\A\s//xsmr} @split;    # remove lead space
  push @output, @lines;
  return @output;                           # }}}2
}

# _write_output()    {{{1
#
# does:   write output to file
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _write_output ($self) {    ## no critic (RequireInterpolationOfMetachars)

  my @output = $self->_lines;
  my $file   = $self->_dump_file;

  # no need to worry about the 'overwrite' option because
  # any existing dump file was removed during initial checks

  # write file
  # - default is to die on error
  $self->_dump_file->spew_utf8(map {"$_\n"} @output);

  # check that a file was created
  confess "Unable to create '$file'" if not -e $file;

  # provide feedback if successful
  say "Created dump file '$file'" or croak;

  return;
}    # }}}1

1;

# POD    {{{1

__END__

=head1 NAME

App::Dn::PassDump - write passwords to file

=head1 VERSION

This documentation is for C<App::Dn::PassDump> version 0.5.

=head1 SYNOPSIS

    use App::Dn::PassDump;

    App::Dn::PassDump->new_with_options->run;

=head1 DESCRIPTION

This module accesses password information stored by
L<Pass|https://www.passwordstore.org/>, "the standard unix password manager",
and dumps (writes) it to an output file. The output format can be plain text or
markdown.

=head2 Pass configuration

The module accesses all password files stored in the password file tree. It
does this one at a time. It is not possible for the user to enter their
password for accessing these files because all console output is being
captured. For that reason the module initially accesses just one password file
without capturing the output, i.e., the user is able to enter the password for
this file. Pass must be configured to stay authenticated for a few minutes;
this can be done using
L<gpg-agent|https://www.gnupg.org/documentation/manuals/gnupg/>.

=head2 Output format

The output file has a header which includes a title, author and date of
writing. The file has a footer which states 'END OF FILE'.

In between the header and footer is a section for each password file, listed
alphabetically and with a horizontal line between them.

Here is the layout for each password section:

    url

    password

    field_1: value_1
    field_2: value_2
    etc.

In markdown-formatted output:

=over

=item *

The url is a second-level header.

=item *

The password is placed within a code fence.

=item *

Values which include a '/' or '\' can cause fatal errors during pdf generation.
For this reason any values containing either of these characters are enclosed
in backticks to ensure they are rendered as code spans. (This prevents their
interference with pdf production.) Unfortunately, most pdf generation processes
do not wrap code spans, so if they are long these values may extend beyond the
pdf page edge.

=item *

Lines whose values do I<not> include '\' or '/' will be split across multiple
lines if they are more than 70 characters long. Split lines have a four-space
hanging indent.

=back

In text output the password and field lines are indented by two spaces. There
is no line splitting as occurs with markdown output.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Options

=head3 -a | --author AUTHOR

Author to put in header of dump file.

String. Optional. Default: 'David Nebauer'.

=head3 -d | --dump_file /FILE/PATH

Path of dump file.

File path. Optional. Default: F<~/.password-store/dump.{md,txt}> where the
extension depends on output format - 'md' for markdown output and 'txt' for
text output.

=head3 -f | --format FORMAT

Format of output.

String. Optional. Must be either 'markdown' or 'text'. Default: 'markdown'.

=head3 -p | --preserve

Whether to preserve an existing dump file.

Flag. Optional. Default: false.

=head3 -r | --root /DIR/PATH

Root passwords directory.

Directory path. Optional. Default: F<~/.password-store>.

=head3 -h | --help

Display help and exit.

=head2 Attributes

None.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

The only public method. It dumps passwords to file as described in
L</DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 Dump file 'FILE' already exists

Occurs when the C<-p> option to preserve any existing dump file of the same
name, and such a file exists. Fatal.

=head2 Invalid format 'FORMAT'

An invalid format has been provided with the C<-f> option. Fatal.

=head2 Multiple author names provided

Occurs when multiple author names are provided using the C<-a> option. Fatal.

=head2 Multiple dump file paths provided

Occurs when multiple dump file names are provided using the C<-d> option.
Fatal.

=head2 Multiple formats provided

Occurs when multiple formats are provided using the C<-f> option. Fatal.

=head2 Multiple root passwords directories provided

Occurs when multiple root directories are provided using the C<-r> option.
Fatal.

=head2 No *.gpg files found in ROOT

Occurs when no F<.gpg> (password) files are found in the specified root
directory. Fatal.

=head2 pass: ERROR

Occurs when C<pass> fails to retrieve a password from a password file. Fatal.

=head2 Unable to create 'FILE'

The operating system was unable to write the password dump file. Fatal.

=head2 Unable to delete existing dump file 'FILE'

Occurs when the operating system is unable to delete an existing dump file.
The system error is displayed after this message. Fatal.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Const::Fast, Date::Simple, English, Env, File::Find::Rule, IPC::Run, Moo,
MooX::HandlesVia, MooX::Options, namespace::clean, strictures,
Term::ProgressBar::Simple, Text::Wrap, Type::Tiny, Types::Path::Tiny,
Types::Standard, version.

=head2 Executables

pass.

=head1 AUTHOR

David Nebauer S<< L<mailto:david@nebauer.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer S<< L<mailto:david@nebauer.org> >>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
