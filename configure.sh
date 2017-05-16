#! /bin/sh

# local options:  ac_help is the help message that describes them
# and LOCAL_AC_OPTIONS is the script that interprets them.  LOCAL_AC_OPTIONS
# is a script that's processed with eval, so you need to be very careful to
# make certain that what you quote is what you want to quote.

# load in the configuration file
#
ac_help='--disable-vi	Disable vi line editing
--disable-emacs	Disable emacs line editing'

LOCAL_AC_OPTIONS='
set=`locals $*`;
if [ "$set" ]; then
    eval $set
    shift 1
else
    ac_error=T;
fi'

locals() {
    K=`echo $1 | $AC_UPPERCASE`
    case "$K" in
    --DISABLE-*)disable=`echo $K | sed -e 's/--DISABLE-//' | tr '-' '_'`
		echo NO_${disable}=T ;;
    esac
}

VERSION=`grep -i VERSION: IAFA-PACKAGE | awk '{print $2}'`
TARGET=pdksh
unset _MK_LIBRARIAN
. ./configure.inc

AC_INIT $TARGET

AC_C_CONST
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

AC_CHECK_HEADERS sys/wait.h unistd.h string.h stdlib.h
AC_CHECK_HEADERS sys/time.h sys/resource.h

AC_CHECK_FUNCS strcasecmp

AC_CHECK_HEADERS stdarg.h && AC_DEFINE 'HAVE_PROTOTYPES' '1'

AC_CHECK_FUNCS 'mmap(0, 0, 0, 0, 0, 0)' sys/mman.h
AC_CHECK_FUNCS 'dup2'
AC_CHECK_FUNCS 'setrlimit'

AC_CHECK_FIELD stat st_rdev sys/types.h sys/stat.h unistd.h

# check for __attribute__(noreturn), which means that __attribute__ works
AC_CHECK_NORETURN && AC_DEFINE 'HAVE_GCC_FUNC_ATTR' '1'

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



AC_CHECK_HEADERS termios.h termio.h

AC_CHECK_FUNCS tcsetpgrp 
AC_CHECK_FUNCS getcwd
AC_CHECK_FUNCS memset
	    

AC_DEFINE 'RETSIGTYPE' 'void'
AC_DEFINE 'RETSIGVAL' '/**/'

AC_DEFINE 'DEFAULT_PATH' '"/bin:/usr/bin:/usr/local/bin"'
AC_SUB 'SHELL_PROG' 'ksh'

unset edit
if [ ! "$NO_VI" ]; then
    edit=1
    AC_DEFINE 'VI' '1'
fi
if [ ! "$NO_EMACS" ]; then
    edit=1
    AC_DEFINE 'EMACS' '1'
fi

AC_DEFINE 'KSH' '1'

AC_SUB 'ac_exe_suffix' ''

AC_TEXT '#include "conf-end.h"'

AC_OUTPUT Makefile
