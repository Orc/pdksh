#!/bin/sh

#
# Script to generate a sorted, complete list of signals, suitable
# for inclusion in trap.c as array initializer.
#

set -e

in=tmpi$$.c
out=tmpi$$
ecode=1
trapsigs='0 1 2 13 15'
trap 'rm -f $in $out; trap 0; exit $ecode' $trapsigs

_POSIX2_VERSION=199209; export _POSIX2_VERSION

CC="${1-cc}"

# The trap here to make up for a bug in bash (1.14.3(1)) that calls the trap
(trap $trapsigs;
 echo '#include "sh.h"';
 echo 'main() {';
 sed -e '/^[	 ]*#/d' -e 's/^[	 ]*\([^ 	][^ 	]*\)[	 ][	 ]*\(.*[^ 	]\)[ 	]*$/#ifdef SIG\1\
	printf("%d,`%s`,`%s`\\n", SIG\1 , "\1", "\2" );\
#endif/'
  echo '}') > $in
cp $in iglist.src
$CC $in  -o $out
./$out | sort -n | tr '`' '"' |
    awk -F, 'BEGIN { last=0; nsigs=0; }
	{    n = $1;
	    if (n > 0 && n != last) {
		while (++last < n) {
		    printf "\t{ %d , (char *) 0, \"Signal %d\" } ,\n", last, last;
		}
		printf "\t{ %s },\n", $0;
	    }
	}'
ecode=0
