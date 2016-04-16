#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# tmv: move files/directories according to pathname transformation(s)

usage()
{
  {
    echo "Usage: $(basename $0 .sh) [options] pathname [pathname]*"
    echo
    echo "Moves files/directories according to pathname transformation(s)."
    echo
    echo "All non-option arguments are the files/directories to be moved."
    echo "If none are specified, then the standard input is read."
    echo
    echo "Options:"
    echo -e "      --help\t\t\tprint this help, then exit"
    echo -e "      --version\t\t\tprint version number, then exit"
    echo -e "  -e, --expression=SCRIPT\tadd the SCRIPT to sed script"
    echo -e "  -f, --file=FILE\t\tadd the contents of FILE to sed script"
    echo -e "  -r, --regexp-extended\t\tuse extended regexps in sed script"
    echo -e "  -l, --lcase\t\t\tconvert pathnames to lower case"
    echo -e "  -u, --ucase\t\t\tconvert pathnames to upper case"
    echo -e "      --iconv=FROM:TO\t\tconvert pathnames' charset"
    echo -e "      --iconv=FROM\t\tconvert pathnames to locale charset"
    echo -e "      --iconv=:TO\t\tconvert pathnames from locale charset"
    echo -e "      --pipe=COMMAND\t\tpipe pathnames through COMMAND"
    echo -e "  -h, --hand-edit\t\tedit pathnames in an editor"
    echo -e "  -b, --backup\t\t\tbackup files about to be overwritten"
    echo -e "  -q, --quiet\t\t\tdon't explain what's being done"
    echo -e "  -n, --dry-run\t\t\tdon't actually move anything"
  } >&2
  quit 2
}

quit()
{
  rm -f "$list_file" "$tmp_file" "$bs_file"
  test "$1" && exit $1
}

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

noun_form()
{
  if isint "$2"; then
    if test $2 -eq 1 -o $2 -eq -1; then
      echo "$1"
    else
      if echo "$1" | grep -e "o$" -e "s$" -e "z$" -e "x$" -e "sh$" -e "ch$" &>/dev/null; then
        echo "$1es"
      elif echo "$1" | grep -e "f$" &>/dev/null; then
        echo "${1:0:${#1}-1}ves"
      elif echo "$1" | grep -e "fe$" &>/dev/null; then
        echo "${1:0:${#1}-2}ves"
      elif echo "$1" | grep "[bcdfghjklmnpqrstvwxz]y$" &>/dev/null; then
        echo "${1:0:${#1}-1}ies"
      else
        echo "$1s"
      fi
    fi
  else
    echo "$1"
  fi
}

verb_have_form()
{
  if isint "$1"; then
    test $1 -eq 1 -o $1 -eq -1 && echo has || echo have
  else
    echo has
  fi
}

verbose=yes
file_count=0
moved_count=0
pipe_count=0
list_file=/tmp/tmv.$$
tmp_file=/tmp/tmv.tmp.$$
bs_file=/tmp/tmv.bs.$$
quit

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
    --help)
      usage
    ;;
    --version)
      echo "@project@ @version@" >&2
      quit 2
    ;;
    -q|--quiet)
      verbose=
    ;;
    -n|--dry-run)
      dry_run=yes
    ;;
    -e|--expression=*)
      if test "$1" = "-e"; then
        shift
        if test $# -eq 0; then
          echo "option '$option' requires an argument" >&2
          quit 1
        fi
        optarg="$1"
      fi
      sed_expr="$(echo "$optarg" | sed "s/'/'\\\\''/")"
      test -z "$sed_options" && sed_options="-e '$sed_expr'" || sed_options="$sed_options -e '$sed_expr'"
      script=yes
    ;;
    -f|--file=*)
      if test "$1" = "-f"; then
        shift
        if test $# -eq 0; then
          echo "option '$option' requires an argument" >&2
          quit 1
        fi
        optarg="$1"
      fi
      test -z "$sed_options" && sed_options="-f '$optarg'" || sed_options="$sed_options -f '$optarg'"
      script=yes
    ;;
    -r|--regexp-extended)
      test -z "$sed_options" && sed_options="-r" || sed_options="$sed_options -r"
    ;;
    -l|--lcase)
      dd_conv=lcase
    ;;
    -u|--ucase)
      dd_conv=ucase
    ;;
    --iconv=*)
      pos=$(strstr "$optarg" :)
      if test "$pos"; then
        iconv="-f '${optarg:0:$pos}' -t '${optarg:$((pos+1))}'"
      else
        iconv="-f '$optarg'"
      fi
    ;;
    --pipe=*)
      pipe[$pipe_count]="$optarg"
      let ++pipe_count
    ;;
    -h|--hand-edit|-m|--manual)
      hand_edit=yes
    ;;
    -b|--backup)
      mv_options='-b'
    ;;
    --)
      end_options=yes
    ;;
    -?*)
      echo "unrecognized option \"$1\"" >&2
      exit 1
    ;;
    *)
      if test "$1" = '-'; then
        read_stdin=yes
      else
        echo "$1" >>"$list_file"
        let ++file_count
      fi
    ;;
  esac

  shift
  test "$end_options" = yes && break
done

if test -z "$script" -a -z "$dd_conv" -a -z "$iconv" -a $pipe_count -eq 0 -a "$hand_edit" != yes; then
  echo "no sed script(s) or other transformations have been specified" >&2
  quit 1
fi

if test "$end_options" = yes; then
  while test $# -gt 0; do
    echo "$1" >>"$list_file"
    let ++file_count
    shift
  done
fi
if test $file_count -eq 0 -o "$read_stdin" = yes; then
  test "$verbose" = yes && echo -n "reading filenames from stdin... " >&2
  sed 's/\\/\\\\/g' >"$bs_file"
  while read src; do
    echo "$src" >>"$list_file"
    let ++file_count
  done <"$bs_file"
  rm -f "$bs_file"
  test "$verbose" = yes && echo done >&2
fi

if test $file_count -eq 0; then
  echo "no files have been specified" >&2
  quit 1
fi
# strip trailing slashes from pathnames
mv "$list_file" "$tmp_file"
sed -e 's|/*$||' "$tmp_file" >"$list_file"
rm -f "$tmp_file"

test "$verbose" = yes && echo -n "creating filelist... " >&2
i=0
sed 's/\\/\\\\/g' "$list_file" >"$bs_file"
while read src; do
  src_files[$i]="$src"
  let ++i
done <"$bs_file"
rm -f "$bs_file"
test "$verbose" = yes && echo done >&2

transform()
{
  declare name
  test $# -gt 1 && name="$2" || name="$1"
  test "$verbose" = yes && echo -n "transforming: $name " >&2
  if ! cat "$list_file" | eval "$1" >"$tmp_file"; then
    test "$verbose" = yes && echo >&2
    echo "$name has failed, exiting" >&2
    quit 1
  fi
  mv "$tmp_file" "$list_file"
  test "$verbose" = yes && echo >&2
}
transform "sed 's/.*\/\([^/]\{1,\}\)\/\?/\1/'" "basename"
test "$script" && transform "sed $sed_options"
test "$dd_conv" && transform "dd conv=$dd_conv 2>/dev/null" "dd conv=$dd_conv"
test "$iconv" && transform "iconv $iconv"
if test $pipe_count -gt 0; then
  for ((i=0; i<pipe_count; ++i)); do
    transform "${pipe[$i]}"
  done
fi
if test "$hand_edit" = yes; then
  if test "$EDITOR"; then
    rm -f "$tmp_file"
    i=0
    sed 's/\\/\\\\/g' "$list_file" >"$bs_file"
    while test $i -lt $file_count && read dest; do
      echo "# ${src_files[$i]}" >>"$tmp_file"
      echo "  $dest" >>"$tmp_file"
      let ++i
    done <"$bs_file"
    rm -f "$bs_file"
    "$EDITOR" "$tmp_file" && cat "$tmp_file" | grep -v '^# ' | cut -c3- >"$list_file"
  else
    echo "set the EDITOR environment variable to your editor of choice first" >&2
    quit 1
  fi
fi

test "$verbose" = yes && echo >&2
i=0
sed 's/\\/\\\\/g' "$list_file" >"$bs_file"
while test $i -lt $file_count && read dest; do
  src="${src_files[$i]}"
  dest="$(dirname -- "$src")/$dest"
  test "${src:0:2}" = "./" && src="${src:2}"
  test "${dest:0:2}" = "./" && dest="${dest:2}"
  if test "$src" != "$dest" -a "$src" != "$dest/"; then
    test "$verbose" = yes && echo -e "$(echo $src | sed 's/\\/\\\\/g')\n  \033[36m$(echo $dest | sed 's/\\/\\\\/g')\033[0m"
    if test "$dry_run" != yes; then
      mv -f $mv_options -- "$src" "$dest" </dev/null || let --moved_count
    fi
    let ++moved_count
  fi
  let ++i
done <"$bs_file"
rm -f "$bs_file"

if test "$verbose" = yes; then
  test $moved_count -gt 0 && echo >&2
  test "$dry_run" = yes &&
    echo -e "\033[37m$moved_count\033[0m/\033[37m$file_count\033[0m $(noun_form file $file_count) would have been moved" >&2 ||
    echo -e "\033[37m$moved_count\033[0m/\033[37m$file_count\033[0m $(noun_form file $file_count) $(verb_have_form $moved_count) been moved" >&2
fi

quit
