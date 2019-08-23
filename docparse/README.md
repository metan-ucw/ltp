Motivation for metadata exctraction
===================================

Exporting documentation
-----------------------

This will allow us to build a browseable documentation for the testcases, e.g.
catalogue of tests that would be searchable etc. At this point there is a
single page generated from the extracted data that tries to outline the intend.


Propagating test requirements
-----------------------------

Some subtest require differnt hardware resources/software versions/etc. the
test execution framework needs to consume these so that it could locate proper
hardware, install proper software, etc.

Some examples of requriments are for example:

* Test needs at least 1GB or RAM.

* Test needs a block device at least 512MB in size

* Test needs a numa machine with two memory nodes and at least 300 free pages on each node

* Test needs i2c eeprom connected on a i2c bus

* Test needs two serial ports connected via null-modem cable


With this information extracted from the tests the testrunner can then map the
requiremnts on the available machines in a lab and select proper machine for
the particular (sub)set of testcases as well as supply particular test with
additional information needed for the test, such as address of the i2c device,
paths to the serial devices, etc. In a case of virtual machines the test could
also dynamically prepare correct environment for the test on demand.


Parallel test execution
-----------------------

An LTP testrun on a modern hardware wastes most of the machine resources
because the testcases are running sequentially. However in order to execute
tests in parallel we need to know which system resources are utilized by a
given test as obviously we cannot run two tests that monopolize the same
resource.

Examples of such tests are:

* Tests that mess with global system state
   - system time (e.g. settimeofday() test and leap second test)
   - SysV SHM
   - ...

* Tests that use block device

* Tests that work with a particular hardware resource
  - i2c eeprom test
  - serial port tests
  - ...


Getting rid of runtest files
----------------------------

This would also allow us to get rid of the unflexible and hard to maintain
runtest files. Once this system is in place we will have a list of all test
along with the metadata which means that we will be able to generate subsets of
the test easily on the fly.

In order to achieve this we need two things:

Each test will escribe which syscall/functionality it tests in the metadata
then we could define groups of tests based on that. I.e. instead of having
syscall runtest file we would ask the testrunner to run all test that have a
defined which syscall they test, or whose filename match syscall name.

Secondly we will have to store the test variants in the test metadata instead
of putting them in a file that is unrelated to the test.

For example:

* To run CVE related test we would select testcases with CVE tag

* To run IPC test we will define a list of IPC syscalls and run all syscall
  test that are in the list

* And many more...

Implementation
==============

The docparser is implemented as a minimal C tokenizer that can parse and
extract code comments and C structures. The docparser then runs over all C
sources in the testcases directory and if tst\_test structure is present in the
source it's parsed and the result is included in the resulting metadata.

During parsing the metadata is stored in a simple key value storage that more
or less follows C structure layout, i.e. can include hash, array, and string.
Once the parsing is finished the result is filtered so that only intereting
fields of the tst\_test structure are included and then converted into a JSON.

This process produces one big JSON file that with metadata for all tests that
is then installed along with the testcases which then would be used by the
testrunner.

The test requirements are stored in the tst\_test structure either as a
bitflags, integers or arrays of strings:

```c
struct tst_test test = {
	...
	/* tests needs to run with UID=1 */
	.needs_root = 1,

	/*
	 * Tests needs a block device at least 1024MB in size and also
	 * mkfs.ext4 installed.
	 */
	.needs_device = 1,
	.dev_min_size = 1024,
	.dev_fs_type = ext4,

	/* Indicates that the test is messing with system wall clock */
	.restore_wallclock = 1,

	/* Tests needs uinput either compiled in or loaded as a module */
	.needs_drivers = (const char *[]) {
		"uinput",
		NULL
	},

	/* Tests needs enabled kernel config flags */
	.needs_kconfigs = (const char *[]) {
		"CONFIG_X86_INTEL_UMIP=y",
		NULL
	},

	/* Additional array of key value pairs */
	.tags = (const struct tst_tag[]) {
                {"linux-git", "43a6684519ab"},
                {"CVE", "2017-2671"},
                {NULL, NULL}
        }
};
```

The test documentation is stored in a special comment such as:

```
/*\
 * Test description
 *
 * This is a test description.
 * Consisting of several lines.
\*/
```

Which will yield following json output:

```json
 "testcaseXY.c": {
  "needs_root": "1",
  "needs_device": "1",
  "dev_min_size": "1024",
  "dev_fs_type": "ext4",
  "restore_wallclock": "1",
  "needs_drivers": [
    "uinput",
    "NULL"
  ],
  "needs_kconfigs": [
    "CONFIG_X86_INTEL_UMIP=y",
    "NULL"
  ],
  "tags": [
    [
     "linux-git",
     "43a6684519ab"
    ],
    [
     "CVE",
     "2017-2671"
    ],
    [
     "NULL",
     "NULL"
    ]
   ],
  "doc": [
    " Test description",
    "",
    " This is a test description.",
    " Consisting of several lines."
  ],
  "fname": "testcases/kernel/syscalls/foo/testcaseXY.c"
 },
```

The final JSON file is an array of test descriptions such as this one.

Open Points
===========

There are stil some loose ends, mostly it's not well defined where to put
things and how to format them.

* Some of the hardware requirements are already listed in the tst\_test should
  we put all of them there?

* What would be the format for test documentation and how to store things such
  as test variants there?

So far this proof of concept generates a metadata file, I guess that we need
actual consumers which will help to settle things down, I will try to look into
making use of this in the runltp-ng at least as reference implementation.
