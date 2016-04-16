#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# install/uninstall: tmv install/uninstall script.

command -v ginstall &>/dev/null && install=${INSTALL:-ginstall} || install=${INSTALL:-install}

project=tmv
version=1.1.3
prefix=/usr/local
bindir=$prefix/bin

bin_scripts='
        tmv
        tmv-strip
        tmv-ul
        tmv-l'

if ! cd "$(dirname "$0")"; then
  echo "Failed to cd to '$(dirname "$0")'." >&4
  exit 1
fi

mode=$(basename "$0" .sh)
if test "$mode" != install -a "$mode" != uninstall; then
  echo "Must be called either as install or as uninstall."
  exit 1
fi

usage()
{
	{
		echo "Usage: $(basename $0) [options]"
		echo
		echo "${mode}s $project $version."
		echo
		echo "Options:"
		echo -e "      --help\t\t\tprint this help, then exit"
		echo -e "      --version\t\t\tprint version number, then exit"
		echo -e "      --prefix=DIR\t\tinstallation prefix       [$prefix]"
		echo -e "      --bindir=DIR\t\tuser executables          [$prefix/bin]"
		echo -e "  -n, --dry-run\t\t\tdon't run any commands, just print them"
	} >&2
  exit 2
}

while test $# -gt 0; do
  case $1 in
    --*=*)
      optarg=$(echo "$1" | sed 's/[-_a-zA-Z0-9]*=//')
    ;;
    *)
      optarg=
    ;;
  esac

  case $1 in
    --prefix=*)
      prefix="$optarg"
      bindir="$prefix/bin"
    ;;
    --bindir=*)
      bindir="$optarg"
    ;;
    -n|--dry-run)
      dry_run=yes
    ;;
    --help)
			usage
    ;;
    --version)
      echo "$project $version" >&2
      exit 2
    ;;
    *)
      echo "unrecognized option \"$1\"" >&2
      exit 1
    ;;
  esac

  shift
done

test "$mode" = install &&
  echo "installing $project $version to:" ||
  echo "uninstalling $project $version from:"
echo
echo "  prefix=$prefix"
echo "  bindir=$bindir"
echo
echo -n "press enter to continue... "
read
echo

isint()
{
  test $# -eq 0 && return 1
  while test $# -gt 0; do
    test "$1" -eq 0 2>/dev/null
    test $? -eq 2 && return 1
    shift
  done
  return 0
}

strstr()
{
  declare i=0 skip
  isint "$3" && skip=$3 || skip=0
  while test $i -le $((${#1}-${#2})); do
    if test "${1:i:${#2}}" = "$2"; then
      if test $skip -gt 0; then
        let --skip
        let ++i
        continue
      fi
      echo $i
      return 0
    fi
    let ++i
  done
  return 1
}

run()
{
  test "${1:0:3}" != "sed" && eval echo "$1"
  test "$dry_run" = yes || eval $1 || { echo -e '\nFailed.' >&2; exit 1; }
}

symlink_do()
{
  pos=$(strstr "$2" '->') || return 0
  symlink_dest="$bindir/${2:0:$pos}"
  if test "$1" = install; then
    symlink_src="${2:$((pos+2))}"
    run 'ln -sf $symlink_src $symlink_dest'
  elif test "$1" = uninstall; then
    run 'rm -f $symlink_dest'
  fi
  continue
}

if test "$mode" = install; then
  run '$install -d -m 755 "$bindir"'
  for i in $bin_scripts; do
    symlink_do install $i
    run '$install -m 755 bin/$i.sh "$bindir/$i"'
    run 'sed -i -e "s/@project@/$project/g" -e "s/@version@/$version/g" "$bindir/$i"'
  done
else
  for i in $bin_scripts; do
    symlink_do uninstall $i
    run 'rm -f "$bindir/$i"'
  done
  run 'rmdir "$bindir" 2>/dev/null'
fi

test "$mode" = uninstall && run 'rmdir "$prefix" 2>/dev/null'
