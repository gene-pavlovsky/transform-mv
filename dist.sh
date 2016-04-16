#!/bin/sh
#
# copyright 2003-2005 Gene Pavlovsky <gene.pavlovsky@gmail.com>
#
# this is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# dist: tmv distribution generation script.

# This function can perform any processing on the project's temporary mirror.
# It's run in the temporary mirror's directory, so use relative paths for
# accessing project's directories/files.
project_local_process()
{
  :
}

project_dir="$(dirname "$0")"
project=$(grep '^project=' "$project_dir/install" | sed 's/^project=//')
version=$(grep '^version=' "$project_dir/install" | sed 's/^version=//')
rm -rf "/tmp/$project-$version"
cp -a "$project_dir" "/tmp/$project-$version"
(cd "/tmp/$project-$version"; project_local_process)
tar -C /tmp -c "$project-$version" | gzip >"$project-$version.tar.gz"
rm -rf "/tmp/$project-$version"
md5sum "$project-$version.tar.gz" >"$project-$version.tar.gz.md5"
gpg --output "$project-$version.tar.gz.sig" --detach-sign "$project-$version.tar.gz"
