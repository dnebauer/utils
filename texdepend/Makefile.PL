use ExtUtils::MakeMaker;
#
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
#
# As well, if you wish to force a minimal perl version to run the
# script, insert a line, for example,
#
#   require 5.004;
#
# below.

WriteMakefile(
    'NAME'	=> 'texdepend',
    'VERSION_FROM' => 'texdepend', # finds $VERSION
    'dist'  => { COMPRESS => 'gzip', SUFFIX => 'gz' },
    'EXE_FILES' => [ 'texdepend' ], # scripts to install
);

