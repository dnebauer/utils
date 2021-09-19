#!/bin/bash

# File: dn-html2ebooks
# Author: David Nebauer (david at nebauer dot org)
# Purpose: Convert an html file to mobi, epub and azw3 formats
# Created: 2017-07-02

# VARIABLES

self='dn-html2ebooks'
parameters='-b basename -t title -a author'
divider='-----------------------'
basename=''
title=''
author=''

# PROCEDURES

# Show usage
#   params: nil
#   prints: nil
#   return: nil
displayUsage () {
cat << _USAGE
${self} converts an html file to ebook formats

Converts html file named "\${basename}.html" in the current
directory to mobi ("\${basename}.mobi"), epub
(\${basename}.epub) and azw3 (\${basename}.azw3) formats.

Output files are written to the current directory and
silently overwrite any existing output files of the same
name.

Requires cover image named "\${basename}.png" in the
current directory.

Usage: ${self} ${parameters}
       ${self} -h

Options: -b basename = basename of input and output files
         -t title    = title of book
         -a author   = author(s) of book
_USAGE
}
# Process command line
#   params: all command line parameters
#   prints: feedback
#   return: nil
processCommandLine () {
	# Read the command line options
	#   - if optstring starts with ':' then error reporting is suppressed
	#     leave ':' at start as '\?' and '\:' error capturing require it
	#   - if option is followed by ':' then it is expected to have an argument
	while getopts ":hb:t:a:" opt ; do
		case ${opt} in
			'h' ) displayUsage && exit 0;;
			'b' ) basename="${OPTARG}";;
			't' ) title="${OPTARG}";;
			'a' ) author="${OPTARG}";;
			'?' ) echo -e "Error: Invalid flag '${OPTARG}' detected"
				  echo -e "Usage: ${self} ${parameters}"
				  echo -e "Try '${self} -h' for help"
				  echo -ne "\a"
				  exit 1;;
			':' ) echo -e "Error: No argument supplied for flag '${OPTARG}'"
				  echo -e "Usage: ${self} ${parameters}"
				  echo -e "Try '${self} -h' for help"
				  echo -ne "\a"
				  exit 1;;
		esac
	done
	shift $((OPTIND-1))
	unset parameters
}


# MAIN

# Process command line
processCommandLine "${@}"

# Need ebook-convert
if ! which ebook-convert &>/dev/null ; then
    echo "${self}: Cannot find 'ebook-convert' program" > /dev/stderr
    echo "${self}: Script aborted" > /dev/stderr
    exit
fi

# Check arguments
proceed=true
# - basename
if test -n "${basename}" ; then
    if ! test -r "${basename}.html" ; then
        msg="${self}: Cannot read file '${basename}.html' in current directory"
        echo "${msg}" > /dev/stderr
        proceed=false
    fi
    if ! test -r "${basename}.png" ; then
        msg="${self}: Cannot read file '${basename}.png' in current directory"
        echo "${msg}" > /dev/stderr
        proceed=false
    fi
else
    echo "${self}: No basename provided" > /dev/stderr
    proceed=false
fi
# - title
if test -z "${title}" ; then
    echo "${self}: No book title provided" > /dev/stderr
    proceed=false
fi
# - author
if test -z "${author}" ; then
    echo "${self}: No book author(s) provided" > /dev/stderr
    proceed=false
fi
if test "${proceed}" = false ; then
    echo "${self}: Script aborted" > /dev/stderr
    exit
fi

# generate output files
# - mobi
echo "${divider}"
echo 'Converting to MOBI'
echo "${divider}"
ebook-convert \
    "${basename}.html" \
    "${basename}.mobi" \
    --no-inline-toc \
    --pretty-print \
    --smarten-punctuation \
    --insert-blank-line \
    --keep-ligatures \
    --title="${title}" \
    --authors="${author}" \
    --language='en_AU' \
    --pubdate="$(date -I)" \
    --cover="${basename}.png"
if test "${?}" = false ; then
    echo "Conversion to mobi format exited with error status" > dev/stderr
    echo "Script aborted" > /std/stderr
    exit
fi

# - epub
echo "${divider}"
echo 'Converting to EPUB'
echo "${divider}"
ebook-convert \
    "${basename}.html" \
    "${basename}.epub" \
    --pretty-print \
    --smarten-punctuation \
    --insert-blank-line \
    --keep-ligatures \
    --title="${title}" \
    --authors="${author}" \
    --language='en_AU' \
    --pubdate="$(date -I)" \
    --cover="${basename}.png"
if test "${?}" = false ; then
    echo "Conversion to epub format exited with error status" > dev/stderr
    echo "Script aborted" > /std/stderr
    exit
fi

# - azw3
echo "${divider}"
echo 'Converting to AZW3'
echo "${divider}"
ebook-convert \
    "${basename}.html" \
    "${basename}.azw3" \
    --no-inline-toc \
    --pretty-print \
    --smarten-punctuation \
    --insert-blank-line \
    --keep-ligatures \
    --title="${title}" \
    --authors="${author}" \
    --language='en_AU' \
    --pubdate="$(date -I)" \
    --cover="${basename}.png"
if test "${?}" = false ; then
    echo "Conversion to azw3 format exited with error status" > dev/stderr
    echo "Script aborted" > /std/stderr
    exit
fi

echo "${divider}"
echo 'Conversions complete'
