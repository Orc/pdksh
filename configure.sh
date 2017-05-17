#! /bin/sh

# local options:  ac_help is the help message that describes them
# and LOCAL_AC_OPTIONS is the script that interprets them.  LOCAL_AC_OPTIONS
# is a script that's processed with eval, so you need to be very careful to
# make certain that what you quote is what you want to quote.

# load in the configuration file
#
ac_help='
--disable-vi		Disable vi line editing
--disable-emacs		Disable emacs line editing
--disable-jobs		Disable job control
--disable-braces	Don'\''t compile in brace expansion (a{b,c} -> ab ac)
--path=PATH		Default path if not defined in <paths.h>
--{sh,ksh}		Specify whether to build a ksh or a bourne sh
--env=ENV		Default environment
--history={no,simple,complex}	History support
--posix			Posix behavior by default
--silly			[A silly option]
--swtch			Shell layer (shl(1)) support.  Obsolete?'

LOCAL_AC_OPTIONS='
set=`locals $*`;
if [ "$set" ]; then
    eval $set
    shift 1
else
    ac_error=T;
fi'

locals() {
    local history
    local K=`echo $1 | $AC_UPPERCASE`
    case "$K" in
    --DISABLE-*)disable=`echo $K | sed -e 's/--DISABLE-//' | tr '-' '_'`
		echo NO_${disable}=T ;;
    --HISTORY=*)history=`echo $K | sed -e '/^--HISTORY=//'`
		if [ "$history" = "NO" ]; then
		    echo HISTORY=$history
		elif [ "$history" = "SIMPLE" ]; then
		    echo HISTORY=$history
		elif [ "$history" = "COMPLEX" ]; then
		    echo HISTORY=$history
		fi ;;
    --PATH=*)   echo "$1" | sed -e's/^--..../DEFAULT_PATH/' ;;
    --ENV=*)	echo "$1" | sed -e's/^--.../DEFAULT_ENV/' ;;
    --SH)	echo SHELL=SH ;;
    --KSH)	echo SHELL=KSH ;;
    --POSIX)	echo POSIXLY_CORRECT=T ;;
    --SILLY)	echo SILLY=T ;;
    --SWTCH)	echo SWTCH=T ;;
    esac
}

VERSION=`grep -i VERSION: IAFA-PACKAGE | awk '{print $2}'`
TARGET=pdksh
SHELL=KSH
HISTORY=COMPLEX

. ./configure.inc

AC_INIT $TARGET
unset _MK_LIBRARIAN

AC_C_CONST
AC_C_VOLATILE
AC_CHECK_TYPE void\* || AC_DEFINE 'void' 'int'
AC_CHECK_TYPE pid_t sys/types.h || AC_DEFINE 'pid_t' 'int'
AC_CHECK_TYPE gid_t sys/types.h || AC_DEFINE 'gid_t' 'int'
AC_CHECK_TYPE uid_t sys/types.h || AC_DEFINE 'uid_t' 'int'
AC_CHECK_TYPE mode_t sys/types.h || AC_DEFINE 'mode_t' 'int'
AC_CHECK_TYPE off_t sys/types.h || AC_DEFINE 'off_t' 'long'

if AC_CHECK_FUNCS sigaction; then
    AC_DEFINE 'POSIX_SIGNALS' '1'
elif AC_CHECK_FUNCS sigset; then
    AC_DEFINE 'BSD41_SIGNALS' '1'
elif AC_CHECK_FUNCS signal; then
    # also need to check for reset-upon-receipt behavior
    AC_DEFINE 'V7_SIGNALS' '1'
else
    AC_DEFINE 'USA_FAKE_SIGACT' '1'
fi

AC_CHECK_HEADERS sys/wait.h unistd.h stdlib.h string.h paths.h
AC_CHECK_HEADERS sys/time.h sys/resource.h termios.h termio.h ulimit.h

# HAVE_PROTOTYPES is misnamed;  it actually is the flag for using <stdarg.h> varargs
# instead of the older varargs.h !
AC_CHECK_HEADERS stdarg.h && AC_DEFINE 'HAVE_PROTOTYPES' '1'

AC_CHECK_FIELD stat st_rdev sys/types.h sys/stat.h unistd.h

# check for __attribute__(noreturn), which means that __attribute__ works
AC_CHECK_NORETURN && AC_DEFINE 'HAVE_GCC_FUNC_ATTR' '1'

AC_CHECK_FUNCS strcasecmp
AC_CHECK_FUNCS 'mmap(0, 0, 0, 0, 0, 0)' sys/mman.h
AC_CHECK_FUNCS 'dup2'
AC_CHECK_FUNCS 'setrlimit'
AC_CHECK_FUNCS tcsetpgrp 
AC_CHECK_FUNCS getcwd
AC_CHECK_FUNCS memset
AC_CHECK_FUNCS nice
AC_CHECK_FUNCS ulimit
AC_CHECK_FUNCS waitpid
AC_CHECK_FUNCS wait3
AC_CHECK_FUNCS flock
AC_CHECK_FUNCS memmove
AC_CHECK_FUNCS memset
AC_CHECK_FUNCS bcopy
AC_CHECK_FUNCS lstat
AC_CHECK_FUNCS times

test -d /dev/fd/0 && AC_DEFINE 'HAVE_DEV_FD' '1'

# opendir;  need to see if it will open a non-directory

if AC_CHECK_HEADERS dirent.h && AC_CHECK_FUNCS opendir; then
    LOGN "can opendir() open a non-directory "
    cat > ngc$$.c << EOF
#include <sys/types.h>
#include <dirent.h>
int
main()
{
    DIR *foo = opendir("ngc$$");
    return foo ? 0 : 1;
}
EOF
    if $AC_CC -o ngc$$ ngc$$.c && ./ngc$$; then
	AC_DEFINE 'OPENDIR_DOES_NONDIR' '1'
	LOG "(yes)"
    else
	LOG "(no)"
    fi
    rm -f ngc$$ ngc$$.c
fi

LOGN "checking process group type "
if AC_QUIET AC_CHECK_FUNCS 'setpgrp\(0,0\)' unistd.h; then
    LOG "(bsd)"
    AC_DEFINE 'BSD_PGRP' '1'
elif AC_QUIET AC_CHECK_FUNCS 'setpgid\(0,0\)' unistd.h; then
    LOG "(posix)"
    AC_DEFINE 'POSIX_PGRP' '1'
elif AC_QUIET AC_CHECK_FUNCS 'setpgrp\(\)' unistd.h; then
    LOG "(sysV)"
    AC_DEFINE 'SYSV_PGRP' '1'
else
    LOG "(none)"
    AC_DEFINE 'NO_PGRP' '1'
fi

LOGN "checking whether #! script headers work "
PGM_FALSE=`acLookFor false`

if [ ! "$PGM_FALSE" ] ;then
    echo "int main() { return 1; }" >> ngc$$.c
    if $AC_CC -o ngc$$ ngc$$.c; then
	PGM_FALSE=`pwd`/ngc$$
    else
	rm -f ngc$$ ngc$$.c
	AC_FAIL "can't compile a falsifier?"
    fi
fi
cat > ngc$$.sh << EOF
#! $PGM_FALSE
exit 0
EOF
chmod +x ngc$$.sh

if ./ngc$$.sh; then
    LOG "(no)"
else
    AC_DEFINE 'SHARPBANG' '1'
    LOG "(yes)"
fi
rm -f ngc$$ ngc$$.sh ngc$$.c

# define SIZEOF_INT/SIZEOF_LONG
cat > ngc$$.c << EOF
#include <stdio.h>
int
main()
{
    printf("SIZEOF_INT %d\n", sizeof(int));
    printf("SIZEOF_LONG %d\n", sizeof(int));
    return 0;
}
EOF

if $AC_CC -o ngc$$ ngc$$.c; then
    ./ngc$$ | while read def value; do
	LOG "define $def as $value"
	AC_DEFINE $def $value
    done
    rm -f ngc$$ ngc$$.c
else
    rm -f ngc$$ ngc$$.c
    AC_FAIL "cannot define SIZEOF_INT or SIZEOF_LONG"
fi

LOGN "Do signals interrupt a read? "
cat > ngc$$.c << EOF
main()
{
    char bfr[8];

    alarm(1);
    return (read(0, bfr, sizeof bfr) == sizeof bfr) ? 0 : 1;
}
EOF

$AC_CC -o ngc$$ ngc$$.c

(sleep 2; echo "LONG INPUT") | ./ngc$$

if [ "$?" -ne 0 ]; then
    LOG "(yes)";
else
    AC_DEFINE 'SIGNALS_DONT_INTERRUPT' '1'
    LOG "(no)"
fi
rm -f ngc$$ ngc$$.c


# add in the various flags that can be passed on in

AC_DEFINE 'RETSIGTYPE' 'void'
AC_DEFINE 'RETSIGVAL' '/**/'

AC_SUB 'ac_exe_suffix' ''

test "$SILLY" && AC_DEFINE 'SILLY' '1'
test "$NO_JOBS" || AC_DEFINE 'JOBS' '1'
test "$POSIX" && AC_DEFINE 'POSIXLY_CORRECT' '1'
test "$NO_BRACES" || AC_DEFINE 'BRACE_EXPAND' '1'

if [ "$SHELL" = "SH" ]; then
    AC_DEFINE 'SH' '1'
    AC_SUB 'SHELL_PROG' 'sh'
else
    AC_DEFINE 'KSH' '1'
    AC_SUB 'SHELL_PROG' 'ksh'
    test "$NO_VI" || AC_DEFINE 'VI' '1'
    test "$NO_EMACS" || AC_DEFINE 'EMACS' '1'
fi

case "$DEFAULT_ENV" in
"")	;;
0|NULL)	AC_DEFINE 'DEFAULT_ENV' $DEFAULT_ENV ;;
*)	AC_DEFINE 'DEFAULT_ENV' \""${DEFAULT_ENV}"\" ;;
esac

test "$DEFAULT_PATH" || DEFAULT_PATH="/bin:/usr/bin:/usr/local/bin"
AC_DEFINE 'DEFAULT_PATH' '"'${DEFAULT_PATH}'"'


if [ "$HISTORY" != "NO" ]; then
    AC_DEFINE 'HISTORY' '1'
    if [ "$HISTORY" = "COMPLEX" ] ;then
	AC_DEFINE 'COMPLEX_HISTORY' '1'
    else
	AC_DEFINE 'EASY_HISTORY' '1'
    fi
fi

AC_TEXT '#include "conf-end.h"'

AC_OUTPUT Makefile
