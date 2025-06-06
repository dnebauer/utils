package App::TW::Select::Plugins;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.5');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(croak);
use Const::Fast;
use Env qw($TIDDLYWIKI_PLUGIN_PATH);
use File::Find::Rule;
use List::SomeUtils;
use MooX::HandlesVia;
use MooX::Options protect_argv => 0;
use Perl::OSType;
use Tk;
use Tk::ErrorDialog;    # invoked by perl/Tk in response to background errors
use Types::Path::Tiny;
use Types::Standard;

const my $TRUE        => 1;
const my $FALSE       => 0;
const my $COMMA_SPACE => q{, };
const my $DEFAULT_PLUGDIR =>
    '/usr/local/lib/node_modules/tiddlywiki/plugins/';
const my $TITLE => 'TiddlyWiki plugins';    # }}}1

# options

# plugins_directory  (-d)    {{{1
option 'plugins_directory' => (
  is         => 'ro',
  format     => 's',          ## no critic (ProhibitDuplicateLiteral)
  repeatable => $TRUE,
  required   => $FALSE,
  default    => sub { [] },
  short      => 'd',
  doc        => 'Server plugins directory [can use multiple times]',
);

# font  (-f)    {{{1
option 'font' => (
  is         => 'ro',
  format     => 's',
  repeatable => $TRUE,
  required   => $FALSE,
  default    => sub { [] },
  short      => 'f',
  doc        => 'Widget font [default: "LucidaSans,18"]',
);

sub _font ($self) {    ## no critic (RequireInterpolationOfMetachars)
  my $default = 'LucidaSans,18';
  my @options = @{ $self->font };
  my $count   = @options;
  die "Expected 1 font, got $count\n" if $count > 1;
  my $font_str;
  $font_str = ($count == 1) ? $options[0] : $default;
  my @font_parts = split /,/xsm, $font_str;
  my $font       = [@font_parts];
  return $font;
}

# indent  (-i)    {{{1
option 'indent' => (
  is         => 'ro',
  format     => 'i',
  repeatable => $TRUE,
  required   => $FALSE,
  default    => sub { [] },
  short      => 'i',          ## no critic (ProhibitDuplicateLiteral)
  doc        => 'Size of indent in output [default: 8]',
);

sub _indent ($self) {    ## no critic (RequireInterpolationOfMetachars)
  const my $DEFAULT_INDENT => 8;
  my @options = @{ $self->indent };
  my $count   = @options;
  die "Expected 1 indent, got $count\n" if $count > 1;
  my $indent;
  $indent = ($count == 1) ? $options[0] : $DEFAULT_INDENT;
  return $indent;
}                        # }}}1

# attributes

# _plugin_dirs    {{{1
has '_plugin_dirs_array' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Path::Tiny::AbsDir],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _plugin_dirs     => 'elements',
    _add_plugin_dirs => 'push',
  },
  doc => 'Server plugin directories',
);

# _plugins_dir    {{{1
has '_plugins_dir' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  coerce  => Types::Path::Tiny::AbsDir->coercion,
  lazy    => $TRUE,
  default => sub {
    my $self  = shift;
    my @dirs  = @{ $self->plugins_directory };
    my $count = @dirs;

    # use default if no directory provided by user
    return $DEFAULT_PLUGDIR if $count == 0;

    # can only handle one directory!
    die "Expected 1 plugin directory, got $count\n" if $count > 1;

    # okay, only one directory provided
    return $dirs[0];
  },
  doc => "Server plugin directory [default: $DEFAULT_PLUGDIR]",
);

# _current_plugins, _add_current_plugins    {{{1
has '_current_plugins_list' => (
  is          => 'rw',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  required    => $FALSE,
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _current_plugins     => 'elements',
    _add_current_plugins => 'push',
  },
  doc => 'Currently selected plugins',
);

# _set_server_plugin[s], _enabled_plugins, _server_plugins    {{{2
has '_server_plugins_hash' => (
  is          => 'rw',
  isa         => Types::Standard::HashRef [Types::Standard::Str],
  required    => $FALSE,
  default     => sub { {} },
  handles_via => 'Hash',
  handles     => {
    _set_server_plugin   => 'set',
    _set_server_plugins  => 'set',
    _server_plugins      => 'elements',
    _server_plugin_names => 'keys',
  },
  doc => 'Server plugins',
);

sub _enabled_plugins ($self) {  ## no critic (RequireInterpolationOfMetachars)
  my %status  = $self->_server_plugins;
  my @enabled = grep { $status{$_} } sort keys %status;
  return @enabled;
}                               # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: nil, except error messages
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # check indent
  $self->_indent;

  # load plugin directories to search in
  $self->_load_plugin_dirs;

  # load current and server plugins
  $self->_load_current_plugins;
  $self->_load_server_plugins;

  # check for current plugins not in server plugin list
  $self->_sanity_check;

  # user selects plugins
  $self->_select_plugins;

  # output enabled plugins
  $self->_output_enabled;

  return;
}

# _load_current_plugins()    {{{1
#
# does:   load current plugins attribute
# params: nil
# prints: nil, except error messages
# return: n/a, dies on failure
sub _load_current_plugins ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # read stdin
  my @input = <STDIN>;    ## no critic (ProhibitExplicitStdin)
  chomp @input;

  # trim whitespace front and back
  my @trimmed = map {s/\A\s*"(\S+)",?\s*\Z/$1/xsmr} @input;

  $self->_add_current_plugins(@trimmed);
  return;
}

# _load_plugin_dirs()    {{{1
#
# does:   determine which plugin dirs to use
# params: nil
# prints: nil, except error messages
# return: n/a, dies on failure
sub _load_plugin_dirs ($self) { ## no critic (RequireInterpolationOfMetachars)
  my @dirs;

  # try first for command-line dirs    {{{2
  my @user_dirs = @{ $self->plugins_directory };
  if (scalar @user_dirs > 0) {
    my @existing_user_dirs = grep {-d} @user_dirs;
    if (not @existing_user_dirs) {
      my $dir_list = join $COMMA_SPACE, @user_dirs;
      my $user_err =
          'Error: Invalid user-provided ' . "plugin directories: $dir_list";
      die "$user_err\n";
    }
    my @missing_user_dirs = grep { not -d } @user_dirs;
    if (@missing_user_dirs) {
      my $miss_list = join $COMMA_SPACE, @missing_user_dirs;
      my $warning =
            'WARNING: Could not locate all plugins directories '
          . "supplied on the command line.\n\n"
          . "Invalid: $miss_list.";
      $self->_warn_dlg($warning);
    }
    push @dirs, @existing_user_dirs;
  }

  # then try $TIDDLYWIKI_PLUGIN_PATH    {{{2
  if ((not @dirs) and (defined $TIDDLYWIKI_PLUGIN_PATH)) {
    my %delimiters = (Unix => q{:}, Windows => q{;});
    my $os_type    = Perl::OSType::os_type;
    die "Error: Unrecognised OS type '$os_type'\n"
        if not exists $delimiters{$os_type};
    my $delimiter         = $delimiters{$os_type};
    my @var_dirs          = split /$delimiter/xsm, $TIDDLYWIKI_PLUGIN_PATH;
    my @existing_var_dirs = grep {-d} @var_dirs;
    if (not @existing_var_dirs) {
      my $var_list = join $COMMA_SPACE, @var_dirs;
      ## no critic (RequireInterpolationOfMetachars)
      my $var_err = 'Error: $TIDDLYWIKI_PLUGIN_PATH provides invalid '
          . "plugin directories: $var_list";
      ## use critic
      die "$var_err\n";
    }
    my @missing_var_dirs = grep { not -d } @var_dirs;
    if (@missing_var_dirs) {
      my $miss_list = join $COMMA_SPACE, @missing_var_dirs;
      my $warning =
            'WARNING: Could not locate all plugin directories '
          . "defined in \$TIDDLYWIKI_PLUGIN_PATH.\n\n"
          . "Invalid: $miss_list.";
      $self->_warn_dlg($warning);
    }
    push @dirs, @existing_var_dirs;
  }

  # finally try default dir    {{{2
  if (not @dirs) {
    die "Cannot locate default plugin directory '$DEFAULT_PLUGDIR'\n"
        if not -d $DEFAULT_PLUGDIR;
    push @dirs, $DEFAULT_PLUGDIR;
  }    # }}}2

  # logic used above means @dirs CANNOT be empty at this point
  my @paths = map { Path::Tiny::path($_) } List::SomeUtils::uniq @dirs;
  $self->_add_plugin_dirs(@paths);
  return;
}

# _load_server_plugins()    {{{1
#
# does:   load server plugins attribute
# params: nil
# prints: nil, except error messages
# return: n/a, dies on failure
sub _load_server_plugins ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # variables    {{{2
  my %server;
  my %current     = map { $_ => $TRUE } $self->_current_plugins;
  my @plugin_dirs = map { $_->canonpath } $self->_plugin_dirs;

  # process plugin directories in turn    {{{2
  for my $dir (@plugin_dirs) {

    # get immediate subdirectories of plugins directory    {{{3
    my $finder = File::Find::Rule->new;
    $finder->directory;
    $finder->mindepth(2);
    $finder->maxdepth(2);
    my @full_paths = $finder->in($dir);

    # must have plugins since dir contains core plugins    {{{3
    die "No plugins found in $dir\n" if not @full_paths;

    # remove base directory    {{{3
    my @plugins = map {s/\A$dir\/(\S+)\Z/$1/xsmr} @full_paths;

    # load into hash with enabled status    {{{3
    for my $plugin (@plugins) {
      my $enabled = exists $current{$plugin};
      $server{$plugin} = $enabled;
    }    # }}}3
  }

  # save plugin names and enabled status    {{{2
  $self->_set_server_plugins(%server);    # }}}2

  return;
}

# _sanity_check()    {{{1
#
# does:   check for current plugins not listed in server plugins
# params: nil
# prints: error on failure, gui message
# return: n/a, dies on failure
sub _sanity_check ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # are any current plugins missing from plugin list?
  my @dirs    = map { $_->canonpath } $self->_plugin_dirs;
  my %plugins = map { $_ => $TRUE } $self->_server_plugin_names;
  my @current = $self->_current_plugins;
  my @missing = grep { not $plugins{$_} } @current;

  # if so, display warning
  if (@missing) {
    my $dir_list  = join $COMMA_SPACE, @dirs;
    my $miss_list = join $COMMA_SPACE, @missing;
    my $warning =
          'WARNING: Not all currently selected plugins have '
        . "been found in server directories ($dir_list).\n\n"
        . "Missing: $miss_list.";
    $self->_warn_dlg($warning);
  }

  return;
}

# _select_plugins()    {{{1
#
# does:   select plugins and set plugins appropriately
# params: nil
# prints: error on failure, displays Listbox widget
# return: n/a, dies on failure
sub _select_plugins ($self) {   ## no critic (RequireInterpolationOfMetachars)

  # variables    {{{2
  my %plugins     = $self->_server_plugins;
  my @items       = sort keys %plugins;
  my $set_plugins = $FALSE;
  my $font        = $self->_font;
  my $title       = $TITLE;

  # create widgets    {{{2
  my $mw = Tk::MainWindow->new;
  $mw->title($title);
  my $lb = $mw->Scrolled(
    'Listbox',
    -scrollbars => 'osoe',        # os=south/below, oe=east/right
    -selectmode => 'multiple',    # select multiple items
    -font       => $font,
    -width      => 0,             # fit longest item
  )->pack(-side => 'left');
  $mw->Button(
    -text    => 'Abort',
    -font    => $font,
    -command => sub {
      $mw->destroy;
    },
  )->pack(-side => 'bottom');
  $mw->Button(
    -text    => 'Set!',
    -font    => $font,
    -command => sub {

      # capture plugin selections
      $set_plugins = $TRUE;
      for my $plugin (@items) {
        $plugins{$plugin} = $FALSE;
      }
      for my $index ($lb->curselection) {
        my $plugin = $items[$index];
        $plugins{$plugin} = $TRUE;
      }
      $mw->destroy;
    },
  )->pack(-side => 'bottom');    ## no critic (ProhibitDuplicateLiteral)

  # insert and pre-select menu items    {{{2
  $lb->insert('end', @items);
  my $index = 0;
  for my $plugin (@items) {
    my $enabled = $plugins{$plugin};
    if ($enabled) {
      $lb->selectionSet($index);
    }
    $index++;
  }
  MainLoop;

  # set plugins    {{{2
  if ($set_plugins) {
    for my $plugin (@items) {
      my $enabled = $plugins{$plugin};
      $self->_set_server_plugin($plugin => $enabled);
    }
  }    # }}}2

  return;
}

# _output_enabled()    {{{1
#
# does:   output enabled plugins
# params: nil
# prints: nil, except error messages
# return: n/a, dies on failure
sub _output_enabled ($self) {   ## no critic (RequireInterpolationOfMetachars)

  my $indent  = q{ } x $self->_indent;
  my @plugins = $self->_enabled_plugins;
  my @quoted  = map {"$indent\"$_\""} @plugins;
  my $output  = join ",\n", @quoted;
  say $output or croak 'Unable to write to console';

  return;
}

# _warn_dlg($msg)    {{{1
#
# does:   display warning dialog
# params: $msg - message [string, required]
# prints: nil, displays gui message box
# return: n/a, dies on failure
sub _warn_dlg ($self, $msg) {   ## no critic (RequireInterpolationOfMetachars)
  my $title = $TITLE;
  my $mw    = Tk::MainWindow->new;
  $mw->withdraw;
  $mw->messageBox(
    -title   => $title,
    -message => $msg,
    -type    => 'OK',
    -icon    => 'warning',
  );
  $mw->destroy;
  return;
}                               # }}}1

1;

# POD    {{{1

__END__

=encoding utf8

=head1 NAME

App::TW::Select::Plugins - interactive filter for selecting plugins

=head1 VERSION

This documentation is for C<App::TW::Select::Plugins> version 0.5.

=head1 SYNOPSIS

    use App::TW::Select::Plugins;
    App::TW::Select::Plugins->new_with_options->run;

=head1 DESCRIPTION

In client-server L<TiddlyWiki|https://tiddlywiki.com/> plugins are referred to
by the subdirectory path to plugin files within a plugins directory. The
customary practice is to use two levels of subdirectory:
F<PLUGIN_AUTHOR/PLUGIN_NAME>.

This script is an interactive filter that accepts a newline-separated list of
enabled plugins via standard input. The user is then presented with a list box
containing all plugins in the specified plugins directories (the method of
plugins directory selection is discussed in L</Plugins directory selection>
below). The plugins provided via standard input are pre-selected. The user can
select additional plugins and deselect currently enabled plugins. When the user
presses the C<Set!> button a newline-separated list of selected plugins is sent
to standard output.

If the user presses the C<Abort> button the list of plugins received via
standard input is sent to standard output.

=head2 Plugins directory selection

The script follows these steps to determine which plugins directories to use.

=over

=over

=item Supplied on command line

The script tries first to obtain plugins directories from command line options
(C<-d> or C<--plugins_directory>). If directories are provided via this method,
and at least one of them is valid, they are used.

=item Supplied by an environmental variable

If no plugins directories are provided on the command line, the script tries to
obtain them from the C<$TIDDLYWIKI_PLUGIN_PATH> environmental variable. If at
least one valid directory is provided by this method, they are used.

=item Default directory

If no plugins directories are provided via either of the previous methods, the
script attempts to use the default server plugins directory used by the debian
C<npm> install, F</usr/local/lib/node_modules/tiddlywiki/plugins/>, if it is
valid.

=back

=back

In all the methods above, if an invalid directory is detected but the script
proceeds, the user is warned of the missing directories via a gui message
dialog.

=head2 Vim users

This script is intended for use with L<vim|https://www.vim.org/> and vim clones
when editing a F<tiddlywiki.info> file. You can follow these steps to change
the list of selected plugins:

=over

=item *

Perform a line-wise selection of the plugin list.

=item *

Press the colon key. This causes the command line to display the selection
marks '<,'> which indicate the following command will apply to the selected
text.

=item *

Type an exclamation point followed by the script name and any necessary
options. The command line will look something like:

    :'<,'>!tw-select-plugins -f "Terminus,18"

=item *

Press Enter.

=back

A listbox widget will be displayed for the user to alter which plugins are
selected. If the "Set!" button is pressed, the selected text in vim is replaced
with a list of the newly selected plugins.

If an error occurs the selected text in vim may be replaced with the error
output. If this occurs the change can be easily reversed with the undo command,
invoked in Normal mode with the C<u> key.

=head2 When no standard input is provided

If no standard input is provided when this script is invoked, it waits
indefinitely for standard input. Pressing C<Ctrl-d> signals to the script that
standard input is complete and it will continue execution.

=head1 CONFIGURATION AND ENVIRONMENT

=head2 Standard input

This script is an interactive filter that accepts a newline-separated list of
enabled plugins via standard input. See L</DESCRIPTION> for more details.

=head2 Properties/attributes

None.

=head2 Options

=head3 -d | plugins_directory PATH

Server plugins directory.

If specifying multiple directories, use a separate C<-d> option for each.

If no directories are provided by the user with this option, the script will
attempt to use any directories specified with the environmental variable
C<$TIDDLYWIKI_PLUGIN_PATH>. If no directories are provided by command line
option or environmental variable, the script will use the debian default plugin
location of F</usr/local/lib/node_modules/tiddlywiki/plugins/> if it exists.

Path. Optional. Default: [see discussion above].

=head3 -f | --font FONT

Font name and size. Format as a single string like "font,size" with a comma
separating the elements and no extra spaces.

Note: the script does not check the validity of this option value. A
non-existent font name is ignored, while a non-numeric size causes a fatal
error.

String. Optional. Default: "LucidaSans,18".

=head3 -i | --indent INDENT

Size of indent used in output.

Integer. Optional. Default: 8. Negative values are silently ignored.

=head3 -h | --help

Display help and exit. Flag. Optional. Default: false.

=head2 Configuration files

None used.

=head2 Environment variables

=head3 TIDDLYWIKI_PLUGIN_PATH

If no plugins directories are provided on the command line, the script tries to
obtain them from the C<$TIDDLYWIKI_PLUGIN_PATH> environmental variable. If at
least one valid directory is provided by this method, they are used.

=head1 SUBROUTINES/METHODS

=head2 run()

The only public method. It runs an interactive filter for selecting plugins as
described in L</DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 Errors (fatal)

=head3 '...' isn't numeric at /PATH/TO/Tk/Widget.pm line 205

This error occurs when a non-numeric font size is provided. For example,
passing the value "Terminus,JK" to the C<--font> option will result in an error
like:

    'JK' isn't numeric at
    /usr/lib/x86_64-linux-gnu/perl5/5.28/Tk/Widget.pm
    line 205

=head3 Cannot locate default plugin directory '...'

This script tries first to obtain plugin directories from command line options.
If none are provided, the script tries to obtain them from the
C<$TIDDLYWIKI_PLUGIN_PATH> environmental variable. If no directories are
provided via either of these methods, the script attempts to use the default
server plugin directory used by the debian C<npm> install:
F</usr/local/lib/node_modules/tiddlywiki/plugins/>. This error occurs if that
directory is unavailable.

=head3 Directory PATH does not exist

This error occurs when an invalid directory path is supplied to the
C<--plugins_directory> option.

=head3 Expected 1 plugin directory, got INT

This error occurs if multiple directory paths are provided using multiple C<-d>
(C<--plugins_directory>) options.

=head3 Expected 1 font, got INT

This error occurs if multiple fonts are provided using multiple C<-f>
(C<--font>) options.

=head3 Expected 1 indent, got INT

This error occurs if multiple indent values are provided using multiple C<-i>
(C<--indent>) options.

=head3 Invalid user-provided plugin directories: PATH[, PATH...]

This script tries first to obtain plugin directories from command line option
C<-d> (C<--plugins_directory>). This error occurs if all directories provided
by this method are invalid.

=head3 Invalid var-provided plugin directories: PATH[, PATH...]

This script tries first to obtain plugin directories from command line options.
If none are provided, the script tries to obtain them from the
C<$TIDDLYWIKI_PLUGIN_PATH> environmental variable. This error occurs if all
directories in that environmental variable are invalid.

=head3 No plugins found in PATH

This error occurs when no subdirectories are found in the specified (or
default) server plugin directory. This is a fatal error because the server
plugin directory must contain tiddlywiki core plugins.

=head3 Option d requires an argument

This error occurs when no value is provided to the C<-d>
(C<--plugins_directory>) option.

=head3 Option f requires an argument

This error occurs when no value is provided to the C<-f> (C<--font>) option.

=head3 Option i requires an argument

This error occurs when no value is provided to the C<-i> (C<--indent>) option.

=head3 Unable to write to console

This error occurs when the script is unable to write to the terminal.

=head3 Unrecognised OS type '...'

This error occurs if the script is checking the contents of the
C<$TIDDLYWIKI_PLUGIN_PATH> (which occurs only if the user provides no plugin
directories via the command line option C<-d>). To interpret this variable it
is necessary to know the path delimiter used, which varies by operating system.
The script relies on L<Perl::OSType> to determine the operating system, and
this module can report only whether the operating system is a type of Windows
or a type of Unix (which use semicolons and colons as path delimiters,
respectively). This error occurs if the L<Perl::OSType> module does not report
the operating system as being of either Windows or Unix type.

=head3 Value "..." invalid for option i (number expected)

This error occurs when a non-numeric value is used for the C<-i> (C<--indent>)
option.

=head2 Warnings (non-fatal)

=head3 Could not locate all plugins directories supplied on the command lines

One or more of the plugins directories provided via the C<-d>
(C<--plugins_directory>) option is invalid (but at least one valid directory
has been provided). This message is followed by a list of the invalid
directories.

=head3 Could not locate all plugin directories defined in $TIDDLYWIKI_PLUGIN_PATH

This warning is displayed when invalid directories are specified in the
$TIDDLYWIKI_PLUGIN_PATH variable (but the variable includes at least one valid
directory). The warning message is followed by a list of the invalid
directories.

=head3 Not all currently selected plugins have been found in server directories

This warning is displayed when at least one plugin subdirectory provided via
standard input is not found in any of the specified plugins directories. This
may be caused by a misspelled plugin directory, obsolete plugin name, or
failing to specify the correct plugins directories.

The warning is followed by a list of the plugin subdirectories that could not
be located.

=head1 INCOMPATIBILITIES

There are no known incompatibilities.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Const::Fast, Env, File::Find::Rule, List::SomeUtils, Moo,
MooX::HandlesVia, MooX::Options, namespace::clean, Perl::OSType, strictures,
Tk, Tk::ErrorDialog, Types::Path::Tiny, Types::Standard, version.

=head1 AUTHOR

David Nebauer S<< <david@nebauer.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer S<< <david@nebauer.org> >>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
