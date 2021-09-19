#!/usr/bin/env bash

# File: BUILD.sh
# Author: David Nebauer (david at nebauer dot org)
# Purpose: Build deb package for navi
# Created: 2021-05-20


# ERROR HANDLING

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# Turn on traces, useful while debugging but commented out by default
# set -o xtrace

# VARIABLES

msg='Loading libraries' ; echo -ne "\\033[1;37;41m${msg}\\033[0m"
source '/usr/libexec/libdncommon-bash/liball'  # supplies functions
dnEraseText "${msg}"
# provided by libdncommon-bash: dn_self,dn_divider[_top|_bottom]
# shellcheck disable=SC2154
usage='Usage:'
parameters='[-v] [-d]'
required_tools=(
    cargo
    cut
    dn-qk-deb
    getopt
    head
)
urls=(
    http://www.googleapis.com:443
    http://accounts.youtube.com:443
    http://accounts.google.com:443
    http://play.google.com:443
)
build_root="$(dnTempDir)" || dnFailScript "Can't make temporary directory"
dnTempTrap "${build_root}"
build_exe="${build_root}/bin/navi"
unset msg


# PROCEDURES

# Show usage
#   params: nil
#   prints: nil
#   return: nil
displayUsage () {
cat << _USAGE
${dn_self}: Build debian package for navi

Downloads and builds the current navi executable into the
current directory and then builds the debian package using
dn-qk-deb.

${usage} ${dn_self} ${parameters}
       ${dn_self} -h

Options: -v | --verbose = set -o verbose
         -d | --debug   = set -o xtrace
_USAGE
}
# Process command line options
#   params: all command line parameters
#   prints: feedback
#   return: nil
#   note:   after execution variable ARGS contains
#           remaining command line args (after options removed)
processOptions () {
	# read the command line options
    local OPTIONS="$(                     \
        getopt                            \
            --options hvd                 \
            --long    help,verbose,debug  \
            --name    "${BASH_SOURCE[0]}" \
            -- "${@}"                     \
    )"
    [[ ${?} -eq 0 ]] || {
        echo 'Invalid command line options' 1>&2
        exit 1
    }
    eval set -- "${OPTIONS}"
	while true ; do
		case "${1}" in
        -h | --help    ) displayUsage   ; exit 0  ;;
        -v | --verbose ) set -o verbose ; shift 1 ;;
        -d | --debug   ) set -o xtrace  ; shift 1 ;;
        --             ) shift ; break ;;
        *              ) break ;;
		esac
	done
	ARGS="${@}"  # remaining arguments
}
# Join items
#   params: 1  - delimiter
#           2+ - items to be joined
#   prints: string containing joined items
#   return: nil
function joinBy () {
    local d=$1
    shift
    local f=$1
    shift
    printf %s "$f" "${@/#/$d}"
}
# Delete build directory
#   params: nil
#   prints: error message
#   return: nil
deleteBuildDir () {
    [[ -d "${build_root}" ]] && rm -fr "${build_root}"
}
# Abort script
#   params: 1 - error message
#   prints: error message
#   return: nil, but script exits with error code 1
abortScript () {
    err="${1}"
    deleteBuildDir \
        || dnFailScript "Unable to remove build directory: ${build_root}"
    dnFailScript "${err}"
}


# MAIN

# Check for required tools
missing=()
for tool in "${required_tools[@]}" ; do
    command -v "${tool}" &>/dev/null || missing+=("${tool}")
done
[[ ${#missing[@]} -eq 0 ]] \
    || abortScript "Can't run without: $(joinBy ', ' "${missing[@]}")"
unset missing tools required_tools

# Process command line options
# - results in $ARGS holding remaining non-option command line arguments
processOptions "${@}"

# Check for internet access
dnCheckInternet "${urls[@]}" \
    || abortScript 'Unable to access the internet'

# Download and build navi using cargo
dnInfo "Downloading and building navi..."
cargo install                  \
        --root "${build_root}" \
        --force                \
        navi                   \
    || abortScript "Failed to build navi"
dnInfo "Ignore any warning to modify PATH"

# Check that navi executable was built successfully
[[ -e "${build_exe}" ]] \
    || abortScript "Failed to build navi executable"

# Copy built executable to current directory
cp --force "${build_exe}" ./ \
    || abortScript "Unable to copy navi executable to current directory"

# Delete build directory
deleteBuildDir \
    || dnFailScript "Unable to remove build directory: ${build_root}"
dnTempKill "${build_root}"

# Show user the version of the new navi
version="$(./navi -h | head -n1 | cut -d' ' -f2)"
dnInfo "Building debian package..."
dnInfo "Version of navi: ${version}"

# Hand over control to dn-qk-deb
exec dn-qk-deb

# vim:foldmethod=marker:
