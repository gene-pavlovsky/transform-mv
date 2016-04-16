#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# tmv-strip: strip a string S from the beginning of S*.

while test $# -gt 0 && test "${1:0:1}" = '-' && test "$1" != '--'; do
  test -z "$options" && options="$1" || options="$options $1"
  shift
done
test "$1" = '--' && shift

if test $# -lt 1; then
  {
    echo "Usage: $(basename $0 .sh) [tmv options] string"
    echo
    echo "Strips string from files containing string in their pathname."
  } >&2
  exit 1
fi

pattern=$(echo "$1" | sed -e 's/\\/\\\\/g' -e 's/\[\|\./\\&/g')
find . -maxdepth 1 -mindepth 1 -name "*$pattern*" | tmv -e "s/$pattern//" $options
