// spell-checker: ignore customisation customisations distrooptions ddropbear
// spell-checker: ignore randomised reexec

/*
                     > > > Read This < < <

default_options.h documents compile-time options, and provides default values.

Local customisation should be added to localoptions.h which is
used if it exists in the build directory. Options defined there will override
any options in this file.

Customisations will also be taken from src/distrooptions.h if it exists.

Options can also be defined with -DDROPBEAR_XXX=[0,1] in Makefile CFLAGS

IMPORTANT: Some options will require "make clean" after changes */

/* By default Dropbear will re-execute itself for each incoming connection so
   that memory layout may be re-randomised (ASLR) - exploiting
   vulnerabilities becomes harder. Re-exec causes slightly more memory use
   per connection.
   This option is ignored on non-Linux platforms at present */
#define DROPBEAR_REEXEC 0

/* Include verbose debug output, enabled with -v at runtime (repeat to
 * increase). define which level of debug output you compile in Level 0 =
 * disabled Level 1-3 = approx 4 Kb (connection, remote identity, algos, auth
 * type info) Level 4 = approx 17 Kb (detailed before connection) Level 5 =
 * approx 8 Kb (detailed after connection) */
#define DEBUG_TRACE 0

/* Whether to print the message of the day (MOTD). */
#define DO_MOTD 0

/* Whether to log commands executed by a client. This only logs the
 * (single) command sent to the server, not what a user did in a
 * shell/sftp session etc. */
#define LOG_COMMANDS 0

/* The default path. This will often get replaced by the shell */
#define DEFAULT_PATH "/usr/sbin:/usr/bin:/sbin:/bin"
#define DEFAULT_ROOT_PATH "/usr/sbin:/usr/bin:/sbin:/bin"
