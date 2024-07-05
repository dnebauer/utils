package App::TW::Plugin::Join;

# modules    {{{1
use Moo;
use strictures 2;
use 5.006;
use 5.038_001;
use version; our $VERSION = qv('0.4');
use namespace::clean -except => [ '_options_data', '_options_config' ];
use Carp qw(croak);
use Const::Fast;
use English;
use File::Basename;
use File::Copy;
use File::Find::Rule;
use File::Spec;
use File::Which;
use IPC::Cmd;
use JSON::MaybeXS;
use MooX::HandlesVia;
use MooX::Options protect_argv => 0;
use Path::Tiny;
use Term::Clui;
use Types::Path::Tiny;
use Types::Standard;

const my $TW_MIN_VERSION => '5.1.20';    # for --savewikifolder command

const my $TRUE                            => 1;
const my $FALSE                           => 0;
const my $CMD_TIDDLYWIKI                  => 'tiddlywiki';
const my $FIELD_TEXT                      => 'text';
const my $FIELD_TITLE                     => 'title';
const my $FIELD_TYPE                      => 'type';
const my $FILE_PLUGIN_INFO                => 'plugin.info';
const my $MIMETYPE_APPLICATION_JAVASCRIPT => 'application/javascript';
const my $MIMETYPE_APPLICATION_JSON       => 'application/json';
const my $MIMETYPE_APPLICATION_X_TIDDLER  => 'application/x-tiddler';
const my $MIMETYPE_TEXT_PLAIN             => 'text/plain';
const my $OPT_LOAD                        => '--load';
const my $OPT_SETFIELD                    => '--setfield';
const my $OPT_SAVEWIKIFOLDER              => '--savewikifolder';
const my $PERIOD                          => q{.};
const my $REF_TYPE_ARRAY                  => 'ARRAY';
const my $SPACE                           => q{ };                      # }}}1

# options

# format (-f)    {{{1
option 'format' => (
  is         => 'ro',
  format     => 's',
  repeatable => $TRUE,
  default    => sub { [] },
  short      => 'f',
  required   => $FALSE,
  doc        => q{Output plugin format ['tid' (default) or 'json']},
);    # }}}1

# attributes

# _format    {{{1
has '_format' => (
  is      => 'ro',
  isa     => Types::Standard::Str,
  lazy    => $TRUE,
  default => sub {
    my $self    = shift;
    my @formats = @{ $self->format };
    my $default = 'tid';

    # handle default case
    return $default if not @formats;

    # handle case where multiple values provided
    my $count = @formats;
    die "Error: Expected 1 format, got $count\n" if $count > 1;

    # okay, got only one format, so check its validity
    my $format = $formats[0];
    my %valid  = map { $_ => $TRUE } qw (tid json);
    die "Error: Invalid format '$format'\n" if not $valid{$format};

    return $format;
  },
  ## no critic (ProhibitDuplicateLiteral)
  doc => q{Output plugin format ['tid' (default) or 'json']},
  ## use critic
);

# _json_processor    {{{1
has '_json_processor' => (
  is      => 'ro',
  doc     => 'JSON processor',
  default => sub {
    JSON::MaybeXS->new(
      utf8         => $TRUE,
      indent       => $TRUE,
      space_before => $FALSE,
      space_after  => $TRUE,
      canonical    => $TRUE,
    );
  },
);

# _plugin_directory    {{{1
has '_plugin_directory' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  lazy    => $TRUE,
  default => sub {
    my $self = shift;

    # get unique command line arguments
    my @args;
    for my $arg (@ARGV) { push @args, glob "$arg"; }

    # must have only one argument
    my $count = @args;
    die "No directory name provided\n"                   if $count == 0;
    die "Expected 1 command line argument, got $count\n" if $count > 1;

    # return value to be coerced
    return Path::Tiny::path($args[0]);
  },
  doc => 'Input plugin directory path',
);

# _plugin_title    {{{1
has '_plugin_title' => (
  is  => 'rw',
  isa => Types::Standard::Str,
  doc => 'Plugin title derived from plugin.info file',
);

# _extra_file, _extra_files, _set_extra_files    {{{1
has '_extra_files_hash' => (
  is       => 'rw',
  isa      => Types::Standard::HashRef [Types::Standard::Str],
  required => $TRUE,
  default  => sub {
    return {
      js   => 'plugintiddlerstext.js',
      text => 'plugintiddlerstext.tid',
      type => 'plugintiddlerstype.tid',
    };
  },
  handles_via => 'Hash',
  handles     => {
    _extra_file      => 'get',
    _extra_files     => 'values',
    _set_extra_files => 'set',
  },
  doc => 'Hash of extra file tokens and file names',
);

# _add_plugin_file, _plugin_files, _plugin_file_deserializer    {{{1
has '_plugin_files_hash' => (
  is          => 'rw',
  isa         => Types::Standard::HashRef [Types::Path::Tiny::AbsFile],
  required    => $FALSE,
  default     => sub { {} },
  handles_via => 'Hash',
  handles     => {
    _add_plugin_file          => 'set',
    _plugin_files             => 'keys',
    _plugin_file_deserializer => 'get',
  },
  doc => 'Hash of plugin file paths and deserializers',
);

# _add_plugin_tiddler, _plugin_tiddlers    {{{1
has '_plugin_tiddlers_array' => (
  is          => 'ro',
  isa         => Types::Standard::ArrayRef [Types::Standard::Str],
  default     => sub { [] },
  handles_via => 'Array',
  handles     => {
    _add_plugin_tiddler => 'push',
    _plugin_tiddlers    => 'elements',
  },
  doc => 'Tiddlers comprising plugin',
);

# _cwd    {{{1
has '_cwd' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  coerce  => Types::Path::Tiny::AbsDir->coercion,
  lazy    => $TRUE,
  default => sub { return Path::Tiny->cwd; },
  doc     => 'Current working directory',
);

# _dir_extra    {{{1
has '_dir_extra' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  coerce  => Types::Path::Tiny::AbsDir->coercion,
  lazy    => $TRUE,
  default => sub { return Path::Tiny->tempdir; },
  doc     => 'Directory for extra template and macro files',
);

# _dir_temp    {{{1
has '_dir_temp' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  coerce  => Types::Path::Tiny::AbsDir->coercion,
  lazy    => $TRUE,
  default => sub { return Path::Tiny->tempdir; },
  doc     => 'Temporary directory for intermediate wiki',
);

# _dir_final    {{{1
has '_dir_final' => (
  is      => 'ro',
  isa     => Types::Path::Tiny::AbsDir,
  coerce  => Types::Path::Tiny::AbsDir->coercion,
  lazy    => $TRUE,
  default => sub { return Path::Tiny->tempdir; },
  doc     => 'Directory for final wiki',
);    # }}}1

# methods

# run()    {{{1
#
# does:   main method
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub run ($self) {    ## no critic (RequireInterpolationOfMetachars)

  $self->_run_checks;

  # check tiddlywiki version (dies if not satisfied)
  $self->_check_tw_version;

  # process plugin input file
  $self->_process_plugin_files;

  # write output plugin file
  $self->_write_output_plugin_file;

  return;
}

# _check_tw_version()    {{{1
#
# does:   checks that tw meets minimum version requirement
# params: nil
# prints: feedback
# return: n/a, dies on failure
# note:   relies on presence of $TW_MIN_VERSION variable/constant
# note:   assumes semantic versioning, e.g., 'major.minor.patch'
sub _check_tw_version ($self) { ## no critic (RequireInterpolationOfMetachars)
  my $tw = $CMD_TIDDLYWIKI;
  File::Which::which $tw or die "Error: Missing executable '$tw'\n";
  my $cmd = [ $tw, '--version' ];
  my ($success, $err_msg, $full, $stdout, $stderr) =
      IPC::Cmd::run(command => $cmd);
  if (not $success) {
    warn "$err_msg\n";
    my $cmd_str = join $SPACE, @{$cmd};
    warn "Version command: '$cmd_str'\n";
    die "Error: Version command failed\n";
  }
  my @version        = split /[.]/xsm, (@{$stdout})[0];
  my $version_parts  = @version;
  my @minimum        = split /[.]/xsm, $TW_MIN_VERSION;
  my $minimum_parts  = @minimum;
  my $version_string = join $PERIOD, @version;
  chomp $version_string;
  my $minimum_string = join $PERIOD, @minimum;

  if ($version_parts != $minimum_parts) {
    my $err =
          "The $tw version ($version_string) does not have the\n"
        . "same number of elements as the minimum\n"
        . "specified version ($minimum_string)";
    croak $err;
  }
  my $index = 0;
  while ($index <= 2) {
    if (  $version[$index] =~ /\A\d+\Z/xsm
      and $minimum[$index] =~ /\A\d+\Z/xsm)
    {
      # do numerical comparison
      if ($version[$index] > $minimum[$index]) { return; }
      if ($version[$index] < $minimum[$index]) {
        die
            "tiddlywiki is v$version_string, need at least v$minimum_string\n";
      }
    }
    else {
      # do text comparison
      if ("$version[$index]" gt "$minimum[$index]") { return; }
      if ("$version[$index]" lt "$minimum[$index]") {
        die
            "tiddlywiki is v$version_string, need at least v$minimum_string\n";
      }
    }
    $index++;
  }
  return;
}

# _create_extra_files()    {{{1
#
# does:   writes template and macro files to output/temp directory
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _create_extra_files ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # need filter specifying plugin tiddlers
  my $filter = $self->_plugin_tiddlers_filter;

  # extract file data
  # - %files is { js => [...], text => [...], type => [...] }
  my @data = <DATA>;
  chomp @data;
  my %files = %{ $self->_extract_extra_file_data(\@data, $filter) };

  # get output file paths and update attribute
  my %fps = map {
    $_ => File::Spec->catfile($self->_dir_extra, $self->_extra_file($_))
  } qw(js text type);
  $self->_set_extra_files(%fps);

  # write files
  for my $type (qw(js text type)) {
    my @content = map {"$_\n"} @{ $files{$type} };
    $self->_write_file($fps{$type}, \@content);
  }

  return;
}

# _dir_files($dir)    {{{1
#
# does:   gets recursive list of files in a directory
# params: $dir - directory [scalar string]
# prints: feedback
# return: list of absolute filepaths, dies on failure
sub _dir_files ($self, $dir) {  ## no critic (RequireInterpolationOfMetachars)
  my $finder = File::Find::Rule->new;
  $finder->file;
  my @files = $finder->in($dir);
  return @files;
}

# _extract_extra_file_data($data, $filter)    {{{1
#
# does:   takes extra file data, rearranges it depending on
#         intended destination, and replaces the FILTER token
#         in the text-field template
# params: $data   - file contents [array reference]
#         $filter - filter expression [string]
# prints: feedback
# return: hashref data structure, dies on failure
# note:   data structure is { js => [...], text => [...], type => [...] }
sub _extract_extra_file_data ($self, $data, $filter)
{    ## no critic (RequireInterpolationOfMetachars)

  my %files = map { $_ => [] } qw(js type text);
  my $file;
  for my $line (@{$data}) {

    # handle file destination tokens
    if ($line =~ /\A===([^=]+)===\Z/xsm) {
      $file = $1;
      next;
    }
    croak "Error: No file marker found before processing '$line'"
        if not $file;

    # handle end of data
    last if $line =~ /\A__END__\Z/xsm;

    # process file content lines
    if ($file eq $FIELD_TEXT and $line =~ /FILTER/xsm) {
      $line =~ s/FILTER/$filter/xsm;
    }
    push @{ $files{$file} }, $line;
  }

  return \%files;
}

# _import_plugin_files()    {{{1
#
# does:   imports plugin and extra files
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _import_plugin_files ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # assemble import command    {{{2
  my @cmd = ($CMD_TIDDLYWIKI);
  for my $fp ($self->_plugin_files) {
    ##my $deserializer = $self->_plugin_file_deserializer($fp);
    my $file_name = (File::Basename::fileparse($fp))[0];
    ##push @cmd, '--import', $fp, $deserializer;
    if ($file_name eq $FILE_PLUGIN_INFO) {
      push @cmd, '--import', $fp, $MIMETYPE_APPLICATION_JSON;
    }
    else {
      push @cmd, $OPT_LOAD, $fp;
    }
  }
  for my $fp ($self->_extra_files) {
    push @cmd, $OPT_LOAD, $fp;
  }
  my $dir = $self->_dir_temp->canonpath;
  push @cmd, $OPT_SAVEWIKIFOLDER, $dir;

  # run import command    {{{2
  my ($success, $err_msg, $full, $stdout, $stderr) =
      IPC::Cmd::run(command => \@cmd);
  if (not $success) {
    warn "$err_msg\n";
    my $cmd_str = join $SPACE, @cmd;
    warn "Import command: '$cmd_str'\n";
    die "Error: Import command failed\n";
  }    # }}}2

  return;
}

# _json_decode($input)    {{{1
#
# does:   convert json input (string or string array) to data structure
# params: $input - json input [string or string array]
# prints: feedback
# return: hashref or arrayref, dies on failure
sub _json_decode ($self, $input_val)
{    ## no critic (RequireInterpolationOfMetachars)

  # input must be string or arrayref of strings    {{{2
  my $ref = ref $input_val;
  if (not($ref eq q{} or $ref eq $REF_TYPE_ARRAY)) {
    croak "Error: Expected string or arrayref, got $ref";
  }
  if ($ref eq $REF_TYPE_ARRAY) {
    my @items = @{$input_val};
    for my $item (@items) {
      my $item_ref = ref $item;
      croak "Error: Expected strings, got a $item_ref"
          if $item_ref ne q{};
    }
  }

  # convert input to single string    {{{2
  my $input;
  if ($ref eq $REF_TYPE_ARRAY) {
    $input = join "\n", @{$input_val};
  }
  else {
    $input = $input_val;
  }

  # perform conversion    {{{2
  my $data = $self->_json_processor->decode($input);    # }}}2

  return $data;

}

# _output_single_plugin_file()    {{{1
#
# does:   outputs single plugin file
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _output_single_plugin_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # assemble output command    {{{2
  my $plugin   = $self->_plugin_title;
  my $tiddler  = '[[' . $plugin . ']]';
  my $wiki_dir = $self->_dir_final->canonpath;
  my $format   = $self->_format;
  ## no critic (RequireInterpolationOfMetachars)
  my $template = '$:/core/templates/' . $format . '-tiddler';
  ## use critic
  my $out_file = $plugin =~ s/[\/:]/_/xsmgr;
  $out_file .= ".$format";
  my @cmd = ($CMD_TIDDLYWIKI, $wiki_dir);
  my @render =
      ('--render', $tiddler, $out_file, $MIMETYPE_TEXT_PLAIN, $template);
  push @cmd, @render;

  # run output command    {{{2
  my ($success, $err_msg, $full, $stdout, $stderr) =
      IPC::Cmd::run(command => \@cmd);
  if (not $success) {
    warn "$err_msg\n";
    my $cmd_str = join $SPACE, @cmd;
    warn "Output command: '$cmd_str'\n";
    die "Error: Output command failed\n";
  }

  # check for successful output    {{{2
  # - should have written one file to wiki's 'output' subdirectory
  my $out_dir = File::Spec->catdir($wiki_dir, 'output');
  croak "Error: Output directory '$out_dir' NOT created"
      if not -d $out_dir;
  my @fps = $self->_dir_files($out_dir);
  croak "Error: No output files created in '$out_dir'" if not @fps;
  my $count = @fps;
  croak "Error: Expected 1 output file in '$out_dir', found $count"
      if $count > 1;
  my $fp = $fps[0];

  # copy output file back to current directory    {{{2
  my $cwd  = $self->_cwd->canonpath;
  my $file = (File::Basename::fileparse($fp))[0];
  if (-e $file) {
    say "Warning: Output file '$file' already exists" or croak;
    my $prompt    = 'Overwrite existing file?';
    my $overwrite = Term::Clui::confirm($prompt);
    if (not $overwrite) {
      say 'Okay, aborting now...' or croak;
      return;
    }
  }
  File::Copy::copy($fp, $cwd)
      or croak "Error: Unable to copy '$fp' to '$cwd': $OS_ERROR";    # }}}2

  return;
}

# _pack_plugin_tiddler()    {{{1
#
# does:   packs plugin tiddler with subsidiary tiddlers
# params: nil
# prints: feedback
# return: n/a, dies on failure
# note:   this step requires writing a new wiki
sub _pack_plugin_tiddler ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # assemble pack command    {{{2
  my $source_dir = $self->_dir_temp->canonpath;
  my $target_dir = $self->_dir_final->canonpath;
  my $plugin     = $self->_plugin_title;
  my @cmd        = ($CMD_TIDDLYWIKI, $source_dir);
  ## no critic (RequireInterpolationOfMetachars)
  my @set_text = (
    $OPT_SETFIELD, "[[$plugin]]",
    $FIELD_TEXT,   '$:/.dtn/templates/plugin-tiddlers-text',
    $MIMETYPE_TEXT_PLAIN,
  );
  push @cmd, @set_text;
  my @set_type = (
    $OPT_SETFIELD, "[[$plugin]]",
    $FIELD_TYPE,   '$:/.dtn/templates/plugin-tiddlers-type',
    $MIMETYPE_TEXT_PLAIN,
  );
  ## use critic
  push @cmd, @set_type;
  push @cmd, $OPT_SAVEWIKIFOLDER, $target_dir;

  # run pack command    {{{2
  my ($success, $err_msg, $full, $stdout, $stderr) =
      IPC::Cmd::run(command => \@cmd);
  if (not $success) {
    warn "$err_msg\n";
    my $cmd_str = join $SPACE, @cmd;
    warn "Pack command: '$cmd_str'\n";
    die "Error: Pack command failed\n";
  }    # }}}2

  return;
}

# _plugin_tiddlers_filter()    {{{1
#
# does:   assemble filter specifying tiddlers for the output
#         plugin tiddler's 'text' field
# params: nil
# prints: feedback
# return: scalar string, dies on failure
sub _plugin_tiddlers_filter ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  my @filter_elements;
  my $stem = $self->_plugin_title;
  push @filter_elements, "[prefix[$stem]]";
  for my $tiddler ($self->_plugin_tiddlers) {

    # \Q..\E quotes non-'word' chars (see 'perldoc -f quotemeta')
    next if $tiddler =~ /\A\Q$stem\E/xsm;
    push @filter_elements, "[[$tiddler]]";
  }
  my $filter = join ' =', @filter_elements;

  return $filter;
}

# _process_plugin_files()    {{{1
#
# does:   determine deserializer and title for each plugin file
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _process_plugin_files ($self)
{    ## no critic (RequireInterpolationOfMetachars ProhibitExcessComplexity)

  # cycle through plugin files
  my @fps = $self->_dir_files($self->_plugin_directory);
  for my $fp (@fps) {
    next if -e "$fp.meta";    # skip if has an associated meta file

    # extract filename and extension    {{{2
    my $store_fp = $fp;
    my $re_ext   = qr/[.][^.]+\Z/xsm;
    my ($base, $dir, $ext) = File::Basename::fileparse($fp, $re_ext);
    my $file = $base . $ext;
    if ($ext eq '.meta') {
      my ($base2, $ext2) =
          (File::Basename::fileparse($base, $re_ext))[ 0, 2 ];
      $file     = $base2 . $ext2;
      $store_fp = File::Spec->catfile($dir, $file);
    }

    # process file content    {{{2
    my @content       = @{ $self->_read_file($fp) };
    my $re_empty      = qr/\A\s*\Z/xsm;
    my $re_json       = qr/\A\s*[{]\s*\Z/xsm;
    my $re_field      = qr/\A\s*([^:]+)\s*:\s*(.*)\Z/xsm;
    my $re_js_comment = qr/\A\/[*]/xsm;
    my %fields;
    my $index   = -1;
    my $is_js   = ($ext eq '.js');
    my $is_tid  = ($ext eq '.tid');
    my $is_json = $FALSE;
    my @json;

    for my $line (@content) {
      $index++;
      last if $line =~ $re_empty;       # means tid, and fields all read
      if ($line =~ $re_js_comment) {    # javascript comment
        next if $is_js;
        croak "Error: Found js comment in non-js file $fp";
      }
      if ($line =~ $re_field) {         # metadata field
        $fields{$1} = $2;
        if (not $is_tid) { $is_tid = $TRUE; }
        next;
      }
      if ($line =~ $re_json) {          # json starts
        last if $is_tid;                # ignore if json is in a text field
        $is_json = $TRUE;
        @json    = @content[ $index .. $#content ];
        my %json_data = %{ $self->_json_decode([@json]) };
        for my $field (keys %json_data) {
          my $value = $json_data{$field};
          $fields{$field} = $value;
        }
        last;
      }
      else {
        croak "Error: Unexpected content in $fp at line $index";
      }
    }

    # work out which deserializer to use for file    {{{2
    my $deserializer;
    if (exists $fields{$FIELD_TYPE}) {
      my $type      = $fields{$FIELD_TYPE};
      my %true_type = (
        'text/css'            => 'text/html',
        'text/vnd.tiddlywiki' => $MIMETYPE_APPLICATION_X_TIDDLER,
      );
      if (exists $true_type{$type}) {
        $deserializer = $true_type{$type};
      }
      else {
        $deserializer = $type;
      }
    }
    else {
      if    ($is_js)   { $deserializer = $MIMETYPE_APPLICATION_JAVASCRIPT; }
      elsif ($is_json) { $deserializer = $MIMETYPE_APPLICATION_JSON; }
      elsif ($is_tid)  { $deserializer = $MIMETYPE_APPLICATION_X_TIDDLER; }
      else { croak "Error: Unable to select deserializer for $fp"; }
    }
    $self->_add_plugin_file($store_fp, $deserializer);

    # save tiddler title    {{{2
    croak "Error: Unable to extract title from $fp"
        if not exists $fields{$FIELD_TITLE};
    my $title = $fields{$FIELD_TITLE};
    if ($file eq $FILE_PLUGIN_INFO) { $self->_plugin_title($title); }
    else { $self->_add_plugin_tiddler($title); }    # }}}2
  }
  return;
}

# _read_file($fp)    {{{1
#
# does:   read file
# params: $fp - file path [string]
# prints: feedback
# return: string arrayref, dies on failure
sub _read_file ($self, $fp) {   ## no critic (RequireInterpolationOfMetachars)

  croak "Error: Cannot read file '$fp'" if not -r $fp;

  # read output file (croaks on failure)
  my $fp_obj  = Path::Tiny::path($fp);
  my @content = $fp_obj->lines_utf8({ chomp => $TRUE });

  return [@content];
}

# _run_checks()    {{{1
#
# does:   run startup checks
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _run_checks ($self) {    ## no critic (RequireInterpolationOfMetachars)

  # force format checks
  $self->_format;

  return;
}

# _write_file($fp, $content)   {{{1
#
# does:   write output file
# params: $fp      - output file path [string]
#         $content - file lines [string arrayref]
# prints: feedback
# return: n/a, dies on failure
# note:   assumes file does not already exist
sub _write_file ($self, $fp, $content)
{    ## no critic (RequireInterpolationOfMetachars)

  croak "Error: Output file '$fp' already exists" if -r $fp;

  # write output file
  my $fp_obj = Path::Tiny::path($fp);
  $fp_obj->spew_utf8(@{$content});    # croaks on failure

  # check for existence of output file
  croak "Error: Unable to write '$fp'" if not -r $fp;

  return;
}

# _write_output_plugin_file()    {{{1
#
# does:   assembles and writes output plugin file
# params: nil
# prints: feedback
# return: n/a, dies on failure
sub _write_output_plugin_file ($self)
{    ## no critic (RequireInterpolationOfMetachars)

  # create template and macro files used in intermediate output
  $self->_create_extra_files;

  # import plugin and extra files into new, intermediate, wiki
  $self->_import_plugin_files;

  # pack plugin tiddler with subsidiary tiddlers
  $self->_pack_plugin_tiddler;

  # output single plugin files
  $self->_output_single_plugin_file;

  return;
}    # }}}1

1;

# DATA    {{{1

__DATA__
===js===
/*\
title: $:/.dtn/modules/macros/plugintiddlerstext.js
type: application/javascript
module-type: macro

Macro to output tiddlers matching a filter to JSON in a format
usable for plugin tiddler 'text' fields

\*/
(function(){

/*jslint node: true, browser: true */
/*global $tw: false */
"use strict";

/*
Information about this macro
*/

exports.name = "plugintiddlerstext";

exports.params = [
    {name: "filter"}
];

/*
Run the macro
*/
exports.run = function(filter) {
    var tiddlers = this.wiki.filterTiddlers(filter),
        tiddlers_data = new Object(),
        data = new Object();
    for(var t=0;t<tiddlers.length; t++) {
        var tiddler = this.wiki.getTiddler(tiddlers[t]);
        if(tiddler) {
            var fields = new Object();
            for(var field in tiddler.fields) {
                fields[field] = tiddler.getFieldString(field);
            }
            var title = tiddler.getFieldString('title');
            tiddlers_data[title] = fields;
        }
    }
    data['tiddlers'] = tiddlers_data;
    return JSON.stringify(data,null,$tw.config.preferences.jsonSpaces);
};

})();
===type===
title: $:/.dtn/templates/plugin-tiddlers-type

<!--

This template is for setting plugin field 'type' to 'application/json'

--><$text text='application/json'/>
===text===
title: $:/.dtn/templates/plugin-tiddlers-text

<!--

This template is for saving tiddlers for use in a plugin tiddler's text field

--><$text text=<<plugintiddlerstext "FILTER">>/>
__END__

# POD    {{{1

=head1 NAME

App::TW::Plugin::Join - compact server-type TiddlyWiki plugin to a single file

=head2 VERSION

This documentation is for C<App::TW::Plugin::Join> version 0.4.

=head1 SYNOPSIS

    use App::TW::Plugin::Join;

    App::TW::Plugin::Join->new_with_options->run;

=head1 DESCRIPTION

There are, broadly speaking, two type of L<TiddlyWiki5|https://tiddlywiki.com/>
wikis:

=over

=item *

Single-file html wikis which are directly opened in web browsers. This was the
first type of wiki developed and is still the most used type.

=item *

Client-server wikis in which wiki content is served from a node.js server while
the client uses a web-browser interface.

=back

There are also two types of tiddlywiki plugins:

=over

=item *

Single-file plugins in which a single file contains all tiddler for a plugin.
This file can either be in C<tid> or C<json> format.

This is the only plugin format compatible with single-file wikis, but they can
also be used in client wikis in a client-server installation.

=item *

Multiple-file wikis in which each tiddler in a plugin has its own file. Each
plugin has a dedicated directory, and may contain multiple levels of
subdirectories. In a client-server configuration this style of plugin can be
installed in a client wiki or in the server installation; in the latter case it
is available to all client wikis served by the server. There is a nominated
F<plugins> directory in each client wiki, and in the server installation, under
which these plugins are installed.

This plugin format is not compatible with single-file wikis.

=back

This script accepts a base directory for a multiple-file plugin. It joins these
files (and their contained tiddlers) into a single plugin tiddler which is
output as a single file.

The format of the outputted file can be C<tid> (default) or C<json>, and is
specified with the C<-f> (C<--format>) option.

The output file is written to the current directory. The file name is the
plugin name converted according to tiddlywiki conventions, i.e., slashes and
colons converted to underscores. For example, the F<$:/plugins/kookma/shiraz>
plugin would be output to the F<$__plugins_kookma_shiraz> file. If the file
already exists in the current directory, the user is asked whether or not to
overwrite it. The script aborts if the user elects not to overwrite the
existing file.

=head2 Conversion details

This section provides details of the conversion process to assist in
troubleshooting.

=head3 Extract tiddler titles from files

In addition to extracting tiddler titles from each file, an attempt is also
made to work out which deserializer is needed for each file. Unfortunately,
this was not entirely successful; for example, none of the available
deserializers work with F<css> files. So, instead of using the C<--import>
command, which requires a deserializer to be specified for each file, the
C<--load> command is used. The C<--load> command infers from a file's extension
which deserializer to use for it. (Presumably it has access to more
deserializers than C<--import>, since it is able to handle F<css> files.)

=head3 Create custom macro

The custom macro C<plugintiddlerstext> outputs a set of tiddlers in a format
suitable for use in a parent plugin file's text field. The macro is provided by
the file F<plugintiddlerstext.js>, which is created in a temporary directory.
Here is the content of the file which defines tiddler
F<$:/.dtn/modules/macros/plugintiddlerstext.js>:

    /*\
    title: $:/.dtn/modules/macros/plugintiddlerstext.js
    type: application/javascript
    module-type: macro

    Macro to output tiddlers matching a filter to JSON in a format
    usable for plugin tiddler 'text' fields

    \*/
    (function(){

    /*jslint node: true, browser: true */
    /*global $tw: false */
    "use strict";

    /*
    Information about this macro
    */

    exports.name = "plugintiddlerstext";

    exports.params = [
        {name: "filter"}
    ];

    /*
    Run the macro
    */
    exports.run = function(filter) {
        var tiddlers = this.wiki.filterTiddlers(filter),
            tiddlers_data = new Object(),
            data = new Object();
        for(var t=0;t<tiddlers.length; t++) {
            var tiddler = this.wiki.getTiddler(tiddlers[t]);
            if(tiddler) {
                var fields = new Object();
                for(var field in tiddler.fields) {
                    fields[field] = tiddler.getFieldString(field);
                }
                var title = tiddler.getFieldString('title');
                tiddlers_data[title] = fields;
            }
        }
        data['tiddlers'] = tiddlers_data;
        return JSON.stringify(data,null,$tw.config.preferences.jsonSpaces);
    };

    })();

=head3 Customised templates for setfield commands

These templates are used by the C<--setfield> command to create and populate
"type" and "text" fields in the plugin tiddler file.

One template is standard for all conversions: adding a "type" field set to
"application/json". This template is called
F<$:/.dtn/templates/plugin-tiddlers-type>. It is provided by the file
F<plugintiddlerstext.tid>, which is written to a temporary directory and has
the content:

    title: $:/core/templates/.dtn/plugin-tiddlers-type

    <!--

    This template is for setting plugin field 'type' to 'application/json'

    --><$text text='application/json'/>

Another template needs to be customised for each conversion project as it needs
to specify the tiddlers included in the plugin. It does this by calling the
macro F<$:/.dtn/modules/macros/plugintiddlerstext.js> discussed above. This
template is called F<$:/.dtn/templates/plugin-tiddlers-text>. It is provided by
the file F<plugintiddlerstext.tid> and has the content:

    title: $:/core/templates/.dtn/plugin-tiddlers-text

    <!--

    This template is for saving tiddlers for use in a plugin tiddler's text field

    --><$text text=<<plugintiddlerstext "[prefix[$:/plugins/.dtn/insert-table/]] =[[$:/config/plugin/.dtn/insert-table/style-sets]]">>/>

Plugin tiddlers are customarily prefixed with the plugin name. These plugin
tiddlers are specified using the C<prefix> filter operator. Any plugin tiddlers
not prefixed with the plugin name are added to the filter individually using
the C<=> filter prefix.

=head3 Import server plugin files

All server plugin files and custom files are imported into a new wiki with a
single C<tiddlywiki> command using multiple commands: the C<--load> command for
all import files except F<plugin.info>, for which an F<--import> command is
used with the "application/json" deserializer. The files defining the custom
macro F<plugintiddlerstext.js>, and custom templates F<plugin-tiddlers-type>
and F<plugin-tiddlers-text>, are also imported with C<--load> commands.

This C<tiddlywiki> command creates a new wiki in memory. It is not possible to
perform any more operations on this wiki in the same command that loads the
files, so the wiki is saved to a temporary directory. This saved version of the
wiki will be further altered with more C<tiddlywiki> commands.

Here is a sample C<tiddlywiki> command in which plugin files are located in
F<$PLUG_DIR>, custom files are located in F<$EXTRA>, and the wiki is saved to
the F<$TMP> directory:

    tiddlywiki \
        --load $PLUG_DIR/macros.tid \
        --load $PLUG_DIR/macros-helper.tid \
        --load $PLUG_DIR/style-sets.tid \
        --load $PLUG_DIR/plugin.info \
        --load $PLUG_DIR/doc/credits.tid \
        --load $PLUG_DIR/doc/dependencies.tid \
        --load $PLUG_DIR/doc/license.tid \
        --load $PLUG_DIR/doc/readme.tid \
        --load $PLUG_DIR/doc/usage.tid \
        --load $PLUG_DIR/js/enlist-operator.js \
        --load $PLUG_DIR/js/uuid-macro.js \
        --load $EXTRA/plugintiddlerstype.tid \
        --load $EXTRA/plugintiddlerstext.tid \
        --load $EXTRA/plugintiddlerstext.js \
        --savewikifolder $TMP

=head3 Add plugin tiddlers to parent plugin tiddler

When a plugin is created in tiddlywiki a "parent" plugin tiddler is created
having the same name as the plugin, e.g., F<$:/plugins/AUTHOR/PLUGIN>. In this
step the plugin files are added to the "text" field of the "parent" tiddler as
a stringified json object. This is done using the F<plugintiddlerstext> macro
and F<plugin-tiddlers-text> template imported earlier.

In addition, the "parent" plugin tiddler "type" is set to "application/json"
using the F<plugin-tiddlers-type> template imported earlier.

Here is an example command used in this step. Once again it is not possible to
performs any further operations on the wiki in this command other than the
C<--setfield> operations. There is no way to save the altered wiki in place, so
it is saved to another temporary directory, in this example the one specified
in F<$FINAL>.

    tiddlywiki $TMP \
        --setfield \
            "[[$:/plugins/.dtn/insert-table]]" \
            "text" \
            "$:/.dtn/templates/plugin-tiddlers-text" \
            "text/plain" \
        --setfield \
            "[[$:/plugins/.dtn/insert-table]]" \
            "type" \
            "$:/.dtn/templates/plugin-tiddlers-type" \
            "text/plain" \
        --savewikifolder \
            $FINAL

=head3 Write plugin file to disk

In this step the "parent" plugin tiddler, which now contains all the plugin
tiddlers in its "text" field, is exported to disk. It can be exported in "tid"
or "json" format. The name of the file is derived from the plugin tiddler title
using standard tiddlywiki conventions, i.e., any C</> and C<:> characters are
converted to C<_>.

This is an example command outputting to "tid" format:

    tiddlywiki $FINAL \
        --render \
            "[[$:/plugins/.dtn/insert-table]]" \
            "\$__plugins_.dtn_insert-table.tid" \
            "text/plain" \
            "$:/core/templates/tid-tiddler"

This is an example command outputting to "json" format:

    tiddlywiki $FINAL \
        --render \
            "[[$:/plugins/.dtn/insert-table]]" \
            '$__plugins_.dtn_insert-table.json' \
            "text/plain" \
            "$:/core/templates/json-tiddler"

Note the filename given as the second parameter to the C<--render> command. The
C<$> requires special care: if using double quotes it must be
backslash-escaped, but escaping is unnecessary if using single quotes.

The file is written to the F<output> subdirectory of the wiki. In the example
above, the output plugin file would be written to F<$FINAL/output>.

=head3 Copy the output file to the current directory

If the current directory already contains a file with the same name as the
output plugin file, the user is asked whether or not to overwrite it.

=head1 CONFIGURATION

=head2 Arguments

=head3 plugin_directory

Path of the plugin's root directory. Directory path. Required.

=head2 Options

=head3 -f | --format FORMAT

Format of output plugin file. String. Allowed values: 'tid' or 'json'.
Optional. Default: 'tid'.

=head3 -h | --help

Display help and exit. Flag. Optional. Default: false.

=head2 Attributes

None.

=head2 Configuration files

None used.

=head2 Environment variables

None used.

=head1 SUBROUTINES/METHODS

=head2 run()

The only public method. It compact a server-type TiddlyWiki plugin into a
single file as described in L</DESCRIPTION>.

=head1 DIAGNOSTICS

=head2 Fatal error messages

=head3 Cannot read file 'FILE'

This error occurs when a file's content cannot be read, most likely because the
user does not have permission to read it.

=head3 Expected 1 command line argument, got N

This occurs if multiple arguments are provided on the command line. Note that
this error may occur if a single directory contains unescaped spaces.

=head3 Expected 1 format, got N

This error occurs if the user provides multiple C<f> (C<--format>) options.

=head3 Expected 1 output file in 'DIR' found N

This error indicates that plugin file output went awry. Specifically, the
output directory contains too many files, i.e., more than one.

=head3 Expected string or arrayref, got REF

This error occurs when attempting to read a json plugin file to extract the
"title" field value. It indicates the data provided to the extraction method
was neither a string or an array reference. This is an internal script error
that should not occur in normal operation.

=head3 Expected strings, got a REF

This error occurs when attempting to read a json plugin file to extract the
"title" field value. It indicates that an array reference provided to the
extraction method contained content other than scalar strings. This is an
internal script error that should not occur in normal operation.

=head3 Found js comment in non-js file FILE

This error occurs when attempting to parse a plugin file to determine the title
of the contained tiddler, and select the appropriate deserializer.
Specifically, the parsing routine thought it was processing a non-javascript
file but encountered a javascript comment line.

=head3 Import command failed

This error occurs if the import command fails. The shell error message is
displayed before this error.

=head3 Invalid format 'FORMAT'

The only valid formats are "tid" and "json". This error occurs if any other
format is specified with the C<-f> (C<--format>) option.

=head3 Missing executable 'tiddlywiki'

This error occurs when the C<which> command (as implemented by the
C<File::Which> module) is unable to locate the C<tiddlywiki> executable.

=head3 No directory name provided

This occurs if no argument is supplied on the command line.

=head3 No file marker found before processing 'LINE'

This error should never occur in normal operation and indicates something has
altered the DATA section of the script. The DATA section consists of content
for macro and template files, with token lines indicating which file the
following DATA contents is intended for. It will be readily appreciated that
the first line of DATA has to be a token line. This error occurs if that is not
the case.

=head3 No output files created in 'DIR'

This error indicates that plugin file output failed. Specifically, the output
directory contains no files.

=head3 Output command failed

This error occurs if the plugin file output command fails. The shell error
message is displayed before this error.

=head3 Output directory 'DIR' NOT created

This error indicates that plugin file output failed. Specifically, the output
directory which is autocreated during successful output was not created.

=head3 Output file 'FILE' already exists

This error is theoretically impossible since a check is made for an existing
file just before writing, but I<in theory> another process could create a file
of the same name between the file name check and the file writing.

=head3 Pack command failed

This error occurs if the attempt to add the plugin's tiddler to the "parent"
plugin tiddler's "text" field fails. The shell error message is displayed
before this error.

=head3 The tiddlywiki version (VER) does not have the...

The full text of this multi-line error is:

    The tiddlywiki version (VER) does not have the
    same number of elements as the minimum
    specified version (MIN)

This is largely self-explanatory. Note that tiddlywiki uses standard
S<L<semantic versioning|https://semver.org/>> in which each version string has
three dot-separated elements: "major.minor.patch".

=head3 tiddlywiki is vVER, need at least vMIN

This error occurs if the C<tiddlywiki> executable does not meet the minimum
version requirement.

=head3 Unable to copy 'FILE' to 'DIR': ERROR

This error indicates that the plugin file was successfully output but an error
occurred when attempting copy it to the current directory. The shell's error
message is displayed at the end of this message.

=head3 Unable to extract title from FILE

This error occurs when attempting to parse a plugin file to determine the title
of the contained tiddler, and select the appropriate deserializer. It indicates
the routine has encountered a file whose content it is unable to successfully
analyse.

=head3 Unable to select deserializer for FILE

This error occurs when attempting to parse a plugin file to determine the title
of the contained tiddler, and select the appropriate deserializer. It indicates
the routine has encountered a file whose content it is unable to successfully
analyse.

=head3 Unable to write 'FILE'

This occurs when the file system is unable to write to the current directory.

=head3 Unexpected content in FILE at line NUM

This error occurs when attempting to parse a plugin file to determine the title
of the contained tiddler, and select the appropriate deserializer. It indicates
the parsing routine has encountered a line it has not been programmed to
process.

=head3 Version command failed

This error occurs if the command C<tiddlywiki --version> command fails. The
shell error message is displayed before this error.

=head2 Warning messages

=head3 Output file 'FILE' already exists

This warning is issued if the current directory already contains a file with
the same name as the plugin output file. The user is asked "Overwrite existing
file?". If the user answers in the affirmative, the file is overwritten. If the
user answers in the negative, the scripts exits with the message "Okay,
aborting now...".

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

Please report any bugs to the author.

=head1 DEPENDENCIES

=head2 Perl modules

Carp, Const::Fast, English, File::Basename, File::Copy, File::Find::Rule,
File::Spec, File::Which, IPC::Cmd, JSON::MaybeXS, Moo, MooX::HandlesVia,
MooX::Options, namespace::clean, Path::Tiny, strictures, Term::Clui,
Types::Path::Tiny, Types::Standard, version.

=head1 AUTHOR

David Nebauer S<< <david@nebauer.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2024 David Nebauer S<< <david@nebauer.org> >>

This script is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

# vim:foldmethod=marker:
