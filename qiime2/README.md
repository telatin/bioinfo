# NAME

**qzoom.pl** - a helper utility to extract data from Qiime2 artifact

# AUTHOR

Andrea Telatin <andrea@telatin.com>

# SYNOPSIS

qzoom.pl \[options\] &lt;artifact\_file.qza/v>

# OPTIONS

> **-c, --cite** \[_PATH_\]
>
> Print artifact citation to STDOUT or to file, is a filepath is provided
>
> **-x, --extract** \[_OUTDIR_\]
>
> Print the list of files in the 'data' directory. 
> If a OUTDIR is provided, extract the content of the 'data' directory (i.e. the actual output of the artifact).
> Will create the directory if not found. Will overwrite files in the directory.
>
> **-i, --info**
>
> Will print informations on the artifact.

# BUGS

Please report them to <andrea@telatin.com>

# COPYRIGHT

Copyright (C) 2019 Andrea Telatin 

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see &lt;http://www.gnu.org/licenses/>.
