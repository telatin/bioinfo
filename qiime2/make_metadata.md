## NAME

**make\_metadata.pl** - a script to draft a metadata table for Qiime 2 or Lotus

## AUTHOR

Andrea Telatin <andrea.telatin@quadram.ac.uk>

## SYNOPSIS

make\_metadata.pl \[options\] -i INPUT\_DIR 

## PARAMETERS

- **-i**, **--reads** DIR

    Path to the directory containing the FASTQ files

- **-s**, **--single-end**

    Input directory contains unpaired files (default is Paired-End mode)

- **-l**, **--lotus**

    Print metadata in LOTUS format (default: Qiime2)

- **-1**, **--for-tag** STRING

    Tag to detect that a file is forward (default: \_R1)

- **-2**, **--rev-tag** STRING

    Tag to detect that a file is forward (default: \_R2)

- **-d**, **--delim** STRING

    The sample ID is the filename up to the delimiter (default: \_)

## BUGS

Please report them to <andrea@telatin.com>

## COPYRIGHT

Copyright (C) 2013-2020 Andrea Telatin 

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
