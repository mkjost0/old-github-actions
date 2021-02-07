# -*- mode:python -*-

# Copyright (c) 2013, 2015-2020 ARM Limited
# All rights reserved.
#
# The license below extends only to copyright in the software and shall
# not be construed as granting a license to any other intellectual
# property including but not limited to intellectual property relating
# to a hardware implementation of the functionality of the software
# licensed hereunder.  You may use the software subject to the license
# terms below provided that you ensure that this notice is replicated
# unmodified and in its entirety in all distributions of the software,
# modified or unmodified, in source code or in binary form.
#
# Copyright (c) 2011 Advanced Micro Devices, Inc.
# Copyright (c) 2009 The Hewlett-Packard Development Company
# Copyright (c) 2004-2005 The Regents of The University of Michigan
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met: redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer;
# redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution;
# neither the name of the copyright holders nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

###################################################
#
# SCons top-level build description (SConstruct) file.
#
# While in this directory ('gem5'), just type 'scons' to build the default
# configuration (see below), or type 'scons build/<CONFIG>/<binary>'
# to build some other configuration (e.g., 'build/X86/gem5.opt' for
# the optimized full-system version).
#
# You can build gem5 in a different directory as long as there is a
# 'build/<CONFIG>' somewhere along the target path.  The build system
# expects that all configs under the same build directory are being
# built for the same host system.
#
# Examples:
#
#   The following two commands are equivalent.  The '-u' option tells
#   scons to search up the directory tree for this SConstruct file.
#   % cd <path-to-src>/gem5 ; scons build/X86/gem5.debug
#   % cd <path-to-src>/gem5/build/X86; scons -u gem5.debug
#
#   The following two commands are equivalent and demonstrate building
#   in a directory outside of the source tree.  The '-C' option tells
#   scons to chdir to the specified directory to find this SConstruct
#   file.
#   % cd <path-to-src>/gem5 ; scons /local/foo/build/X86/gem5.debug
#   % cd /local/foo/build/X86; scons -C <path-to-src>/gem5 gem5.debug
#
# You can use 'scons -H' to print scons options.  If you're in this
# 'gem5' directory (or use -u or -C to tell scons where to find this
# file), you can use 'scons -h' to print all the gem5-specific build
# options as well.
#
###################################################

# Global Python includes
import atexit
import itertools
import os
import sys

from os import mkdir, environ
from os.path import abspath, basename, dirname, expanduser, normpath
from os.path import exists,  isdir, isfile
from os.path import join as joinpath, split as splitpath
from re import match

# SCons includes
import SCons
import SCons.Node
import SCons.Node.FS
import SCons.Tool

from m5.util import compareVersions, readCommand, readCommandWithReturn

AddOption('--colors', dest='use_colors', action='store_true',
          help="Add color to abbreviated scons output")
AddOption('--no-colors', dest='use_colors', action='store_false',
          help="Don't add color to abbreviated scons output")
AddOption('--with-cxx-config', action='store_true',
          help="Build with support for C++-based configuration")
AddOption('--default',
          help='Override which build_opts file to use for defaults')
AddOption('--ignore-style', action='store_true',
          help='Disable style checking hooks')
AddOption('--gold-linker', action='store_true', help='Use the gold linker')
AddOption('--no-compress-debug', action='store_true',
          help="Don't compress debug info in build files")
AddOption('--no-lto', action='store_true',
          help='Disable Link-Time Optimization for fast')
AddOption('--verbose', action='store_true',
          help='Print full tool command lines')
AddOption('--without-python', action='store_true',
          help='Build without Python configuration support')
AddOption('--without-tcmalloc', action='store_true',
          help='Disable linking against tcmalloc')
AddOption('--with-ubsan', action='store_true',
          help='Build with Undefined Behavior Sanitizer if available')
AddOption('--with-asan', action='store_true',
          help='Build with Address Sanitizer if available')
AddOption('--with-systemc-tests', action='store_true',
          help='Build systemc tests')

from gem5_scons import Transform, error, warning, summarize_warnings
from gem5_scons import TempFileSpawn, parse_build_path
import gem5_scons

########################################################################
#
# Set up the main build environment.
#
########################################################################

main = Environment(tools=['default', 'git', TempFileSpawn])

main.Tool(SCons.Tool.FindTool(['gcc', 'clang'], main))
main.Tool(SCons.Tool.FindTool(['g++', 'clang++'], main))

from gem5_scons.util import get_termcap
termcap = get_termcap()

# Check that we have a C/C++ compiler
if not ('CC' in main and 'CXX' in main):
    error("No C++ compiler installed (package g++ on Ubuntu and RedHat)")

###################################################
#
# Figure out which configurations to set up based on the path(s) of
# the target(s).
#
###################################################

# Find default configuration & binary.
Default(environ.get('M5_DEFAULT_BINARY', 'build/ARM/gem5.debug'))

# helper function: find last occurrence of element in list
def rfind(l, elt, offs = -1):
    for i in range(len(l)+offs, 0, -1):
        if l[i] == elt:
            return i
    raise ValueError("element not found")

# Take a list of paths (or SCons Nodes) and return a list with all
# paths made absolute and ~-expanded.  Paths will be interpreted
# relative to the launch directory unless a different root is provided
def makePathListAbsolute(path_list, root=GetLaunchDir()):
    return [abspath(joinpath(root, expanduser(str(p))))
            for p in path_list]

# Each target must have 'build' in the interior of the path; the
# directory below this will determine the build parameters.  For
# example, for target 'foo/bar/build/X86/arch/x86/blah.do' we
# recognize that X86 specifies the configuration because it
# follow 'build' in the build path.

# The funky assignment to "[:]" is needed to replace the list contents
# in place rather than reassign the symbol to a new list, which
# doesn't work (obviously!).
BUILD_TARGETS[:] = makePathListAbsolute(BUILD_TARGETS)

# Generate a list of the unique build roots and configs that the
# collected targets reference.
variant_paths = set()
build_root = None
for t in BUILD_TARGETS:
    this_build_root, variant = parse_build_path(t)

    # Make sure all targets use the same build root.
    if not build_root:
        build_root = this_build_root
    elif this_build_root != build_root:
        error("build targets not under same build root\n  %s\n  %s" %
            (build_root, this_build_root))

    # Collect all the variants into a set.
    variant_paths.add(os.path.join('/', build_root, variant))

# Make sure build_root exists (might not if this is the first build there)
if not isdir(build_root):
    mkdir(build_root)
main['BUILDROOT'] = build_root

Export('main')

main.SConsignFile(joinpath(build_root, "sconsign"))

# Default duplicate option is to use hard links, but this messes up
# when you use emacs to edit a file in the target dir, as emacs moves
# file to file~ then copies to file, breaking the link.  Symbolic
# (soft) links work better.
main.SetOption('duplicate', 'soft-copy')

#
# Set up global sticky variables... these are common to an entire build
# tree (not specific to a particular build like X86)
#

global_vars_file = joinpath(build_root, 'variables.global')

global_vars = Variables(global_vars_file, args=ARGUMENTS)

global_vars.AddVariables(
    ('CC', 'C compiler', environ.get('CC', main['CC'])),
    ('CXX', 'C++ compiler', environ.get('CXX', main['CXX'])),
    ('CCFLAGS_EXTRA', 'Extra C and C++ compiler flags', ''),
    ('LDFLAGS_EXTRA', 'Extra linker flags', ''),
    ('MARSHAL_CCFLAGS_EXTRA', 'Extra C and C++ marshal compiler flags', ''),
    ('MARSHAL_LDFLAGS_EXTRA', 'Extra marshal linker flags', ''),
    ('PYTHON_CONFIG', 'Python config binary to use',
     [ 'python3-config', 'python-config']
    ),
    ('PROTOC', 'protoc tool', environ.get('PROTOC', 'protoc')),
    ('BATCH', 'Use batch pool for build and tests', False),
    ('BATCH_CMD', 'Batch pool submission command name', 'qdo'),
    ('M5_BUILD_CACHE', 'Cache built objects in this directory', False),
    ('EXTRAS', 'Add extra directories to the compilation', '')
    )

# Update main environment with values from ARGUMENTS & global_vars_file
global_vars.Update(main)
Help('''
Global build variables:
{help}
'''.format(help=global_vars.GenerateHelpText(main)), append=True)

# Save sticky variable settings back to current variables file
global_vars.Save(global_vars_file, main)

# Parse EXTRAS variable to build list of all directories where we're
# look for sources etc.  This list is exported as extras_dir_list.
base_dir = Dir('#src').abspath
if main['EXTRAS']:
    extras_dir_list = makePathListAbsolute(main['EXTRAS'].split(':'))
else:
    extras_dir_list = []

Export('base_dir')
Export('extras_dir_list')

# the ext directory should be on the #includes path
main.Append(CPPPATH=[Dir('ext')])

# Add shared top-level headers
main.Prepend(CPPPATH=Dir('include'))

if GetOption('verbose'):
    def MakeAction(action, string, *args, **kwargs):
        return Action(action, *args, **kwargs)
else:
    MakeAction = Action
    main['CCCOMSTR']        = Transform("CC")
    main['CXXCOMSTR']       = Transform("CXX")
    main['ASCOMSTR']        = Transform("AS")
    main['ARCOMSTR']        = Transform("AR", 0)
    main['LINKCOMSTR']      = Transform("LINK", 0)
    main['SHLINKCOMSTR']    = Transform("SHLINK", 0)
    main['RANLIBCOMSTR']    = Transform("RANLIB", 0)
    main['M4COMSTR']        = Transform("M4")
    main['SHCCCOMSTR']      = Transform("SHCC")
    main['SHCXXCOMSTR']     = Transform("SHCXX")
Export('MakeAction')

# Initialize the Link-Time Optimization (LTO) flags
main['LTO_CCFLAGS'] = []
main['LTO_LDFLAGS'] = []

# According to the readme, tcmalloc works best if the compiler doesn't
# assume that we're using the builtin malloc and friends. These flags
# are compiler-specific, so we need to set them after we detect which
# compiler we're using.
main['TCMALLOC_CCFLAGS'] = []

# Platform-specific configuration.  Note again that we assume that all
# builds under a given build root run on the same host platform.
conf = gem5_scons.Configure(main)

CXX_version = readCommand([main['CXX'], '--version'], exception=False)

main['GCC'] = CXX_version and CXX_version.find('g++') >= 0
main['CLANG'] = CXX_version and CXX_version.find('clang') >= 0
if main['GCC'] + main['CLANG'] > 1:
    error('Two compilers enabled at once?')

# Set up default C++ compiler flags
if main['GCC'] or main['CLANG']:
    # As gcc and clang share many flags, do the common parts here
    main.Append(CCFLAGS=['-pipe'])
    main.Append(CCFLAGS=['-fno-strict-aliasing'])
    # Enable -Wall and -Wextra and then disable the few warnings that
    # we consistently violate
    main.Append(CCFLAGS=['-Wall', '-Wundef', '-Wextra',
                         '-Wno-sign-compare', '-Wno-unused-parameter'])
    # We always compile using C++14
    main.Append(CXXFLAGS=['-std=c++14'])
    if sys.platform.startswith('freebsd'):
        main.Append(CCFLAGS=['-I/usr/local/include'])
        main.Append(CXXFLAGS=['-I/usr/local/include'])

    conf.CheckLinkFlag('-Wl,--as-needed')
    if GetOption('gold_linker'):
        main.Append(LINKFLAGS='-fuse-ld=gold')

    # Treat warnings as errors but white list some warnings that we
    # want to allow (e.g., deprecation warnings).
    main.Append(CCFLAGS=['-Werror',
                         '-Wno-error=deprecated-declarations',
                         '-Wno-error=deprecated',
                        ])
else:
    error('\n'.join((
          "Don't know what compiler options to use for your compiler.",
          "compiler: " + main['CXX'],
          "version: " + CXX_version.replace('\n', '<nl>') if
                CXX_version else 'COMMAND NOT FOUND!',
          "If you're trying to use a compiler other than GCC",
          "or clang, there appears to be something wrong with your",
          "environment.",
          "",
          "If you are trying to use a compiler other than those listed",
          "above you will need to ease fix SConstruct and ",
          "src/SConscript to support that compiler.")))

if main['GCC']:
    if compareVersions(main['CXXVERSION'], "5") < 0:
        error('gcc version 5 or newer required.\n'
              'Installed version:', main['CXXVERSION'])

    # Add the appropriate Link-Time Optimization (LTO) flags
    # unless LTO is explicitly turned off.
    if not GetOption('no_lto'):
        # g++ uses "make" to parallelize LTO. The program can be overriden with
        # the environment variable "MAKE", but we currently make no attempt to
        # plumb that variable through.
        parallelism = ''
        if main.Detect('make'):
            parallelism = '=%d' % GetOption('num_jobs')
        else:
            warning('"make" not found, link time optimization will be '
                    'single threaded.')

        # Pass the LTO flag when compiling to produce GIMPLE
        # output, we merely create the flags here and only append
        # them later
        main['LTO_CCFLAGS'] = ['-flto%s' % parallelism]

        # Use the same amount of jobs for LTO as we are running
        # scons with
        main['LTO_LDFLAGS'] = ['-flto%s' % parallelism]

    main.Append(TCMALLOC_CCFLAGS=['-fno-builtin-malloc', '-fno-builtin-calloc',
                                  '-fno-builtin-realloc', '-fno-builtin-free'])

elif main['CLANG']:
    if compareVersions(main['CXXVERSION'], "3.9") < 0:
        error('clang version 3.9 or newer required.\n'
              'Installed version:', main['CXXVERSION'])

    # clang has a few additional warnings that we disable, extraneous
    # parantheses are allowed due to Ruby's printing of the AST,
    # finally self assignments are allowed as the generated CPU code
    # is relying on this
    main.Append(CCFLAGS=['-Wno-parentheses', '-Wno-self-assign'])
    conf.CheckCxxFlag('-Wno-c99-designator')
    conf.CheckCxxFlag('-Wno-defaulted-function-deleted')

    main.Append(TCMALLOC_CCFLAGS=['-fno-builtin'])

    # On Mac OS X/Darwin we need to also use libc++ (part of XCode) as
    # opposed to libstdc++, as the later is dated.
    if sys.platform == "darwin":
        main.Append(CXXFLAGS=['-stdlib=libc++'])
        main.Append(LIBS=['c++'])

    # On FreeBSD we need libthr.
    if sys.platform.startswith('freebsd'):
        main.Append(LIBS=['thr'])

# Add sanitizers flags
sanitizers=[]
if GetOption('with_ubsan'):
    sanitizers.append('undefined')
if GetOption('with_asan'):
    # Available for gcc >= 5 or llvm >= 3.1 both a requirement
    # by the build system
    sanitizers.append('address')
    suppressions_file = Dir('util').File('lsan-suppressions').get_abspath()
    suppressions_opt = 'suppressions=%s' % suppressions_file
    main['ENV']['LSAN_OPTIONS'] = ':'.join([suppressions_opt,
                                            'print_suppressions=0'])
    print()
    warning('To suppress false positive leaks, set the LSAN_OPTIONS '
            'environment variable to "%s" when running gem5' %
            suppressions_opt)
    warning('LSAN_OPTIONS=suppressions=%s' % suppressions_opt)
    print()
if sanitizers:
    sanitizers = ','.join(sanitizers)
    if main['GCC'] or main['CLANG']:
        main.Append(CCFLAGS=['-fsanitize=%s' % sanitizers,
                             '-fno-omit-frame-pointer'],
                    LINKFLAGS='-fsanitize=%s' % sanitizers)
    else:
        warning("Don't know how to enable %s sanitizer(s) for your "
                "compiler." % sanitizers)

# Do this after we save setting back, or else we'll tack on an
# extra 'qdo' every time we run scons.
if main['BATCH']:
    main['CC']     = main['BATCH_CMD'] + ' ' + main['CC']
    main['CXX']    = main['BATCH_CMD'] + ' ' + main['CXX']
    main['AS']     = main['BATCH_CMD'] + ' ' + main['AS']
    main['AR']     = main['BATCH_CMD'] + ' ' + main['AR']
    main['RANLIB'] = main['BATCH_CMD'] + ' ' + main['RANLIB']

if sys.platform == 'cygwin':
    # cygwin has some header file issues...
    main.Append(CCFLAGS=["-Wno-uninitialized"])


have_pkg_config = main.Detect('pkg-config')

# Check for the protobuf compiler
main['HAVE_PROTOC'] = False
protoc_version = []
try:
    protoc_version = readCommand([main['PROTOC'], '--version']).split()
except Exception as e:
    warning('While checking protoc version:', str(e))

# Based on the availability of the compress stream wrappers, require 2.1.0.
min_protoc_version = '2.1.0'

# First two words should be "libprotoc x.y.z"
if len(protoc_version) < 2 or protoc_version[0] != 'libprotoc':
    warning('Protocol buffer compiler (protoc) not found.\n'
            'Please install protobuf-compiler for tracing support.')
elif compareVersions(protoc_version[1], min_protoc_version) < 0:
    warning('protoc version', min_protoc_version, 'or newer required.\n'
            'Installed version:', protoc_version[1])
else:
    # Attempt to determine the appropriate include path and
    # library path using pkg-config, that means we also need to
    # check for pkg-config. Note that it is possible to use
    # protobuf without the involvement of pkg-config. Later on we
    # check go a library config check and at that point the test
    # will fail if libprotobuf cannot be found.
    if have_pkg_config:
        conf.CheckPkgConfig('protobuf', '--cflags', '--libs-only-L')
    main['HAVE_PROTOC'] = True



# Cache build files in the supplied directory.
if main['M5_BUILD_CACHE']:
    print('Using build cache located at', main['M5_BUILD_CACHE'])
    CacheDir(main['M5_BUILD_CACHE'])

if not GetOption('no_compress_debug'):
    if not conf.CheckCxxFlag('-gz'):
        warning("Can't enable object file debug section compression")
    if not conf.CheckLinkFlag('-gz'):
        warning("Can't enable executable debug section compression")

main['USE_PYTHON'] = not GetOption('without_python')
if main['USE_PYTHON']:
    # Find Python include and library directories for embedding the
    # interpreter. We rely on python-config to resolve the appropriate
    # includes and linker flags. ParseConfig does not seem to understand
    # the more exotic linker flags such as -Xlinker and -export-dynamic so
    # we add them explicitly below. If you want to link in an alternate
    # version of python, see above for instructions on how to invoke
    # scons with the appropriate PATH set.

    python_config = main.Detect(main['PYTHON_CONFIG'])
    if python_config is None:
        error("Can't find a suitable python-config, tried %s" % \
              main['PYTHON_CONFIG'])

    print("Info: Using Python config: %s" % (python_config, ))

    py_includes = readCommand([python_config, '--includes'],
                              exception='').split()
    py_includes = list(filter(
        lambda s: match(r'.*\/include\/.*',s), py_includes))
    # Strip the -I from the include folders before adding them to the
    # CPPPATH
    py_includes = list(map(
        lambda s: s[2:] if s.startswith('-I') else s, py_includes))
    main.Append(CPPPATH=py_includes)

    # Read the linker flags and split them into libraries and other link
    # flags. The libraries are added later through the call the CheckLib.
    # Note: starting in Python 3.8 the --embed flag is required to get the
    # -lpython3.8 linker flag
    retcode, cmd_stdout = readCommandWithReturn(
        [python_config, '--ldflags', '--embed'], exception='')
    if retcode != 0:
        # If --embed isn't detected then we're running python <3.8
        retcode, cmd_stdout = readCommandWithReturn(
            [python_config, '--ldflags'], exception='')

    # Checking retcode again
    if retcode != 0:
        error("Failing on python-config --ldflags command")

    py_ld_flags = cmd_stdout.split()

    py_libs = []
    for lib in py_ld_flags:
         if not lib.startswith('-l'):
             main.Append(LINKFLAGS=[lib])
         else:
             lib = lib[2:]
             if lib not in py_libs:
                 py_libs.append(lib)

    # verify that this stuff works
    if not conf.CheckHeader('Python.h', '<>'):
        error("Check failed for Python.h header in",
                ' '.join(py_includes), "\n"
              "Two possible reasons:\n"
              "1. Python headers are not installed (You can install the "
              "package python-dev on Ubuntu and RedHat)\n"
              "2. SCons is using a wrong C compiler. This can happen if "
              "CC has the wrong value.\n"
              "CC = %s" % main['CC'])

    for lib in py_libs:
        if not conf.CheckLib(lib):
            error("Can't find library %s required by python." % lib)

    main.Prepend(CPPPATH=Dir('ext/pybind11/include/'))

    marshal_env = main.Clone()

    # Bare minimum environment that only includes python
    marshal_env.Append(CCFLAGS='$MARSHAL_CCFLAGS_EXTRA')
    marshal_env.Append(LINKFLAGS='$MARSHAL_LDFLAGS_EXTRA')

    py_version = conf.CheckPythonLib()
    if not py_version:
        error("Can't find a working Python installation")

    # Found a working Python installation. Check if it meets minimum
    # requirements.
    if py_version[0] < 3 or \
    (py_version[0] == 3 and py_version[1] < 6):
        error('Python version too old. Version 3.6 or newer is required.')
    elif py_version[0] > 3:
        warning('Python version too new. Python 3 expected.')

# On Solaris you need to use libsocket for socket ops
if not conf.CheckLibWithHeader(
        [None, 'socket'], 'sys/socket.h', 'C++', 'accept(0,0,0);'):
   error("Can't find library with socket calls (e.g. accept()).")

# Check for zlib.  If the check passes, libz will be automatically
# added to the LIBS environment variable.
if not conf.CheckLibWithHeader('z', 'zlib.h', 'C++','zlibVersion();'):
    error('Did not find needed zlib compression library '
          'and/or zlib.h header file.\n'
          'Please install zlib and try again.')

# If we have the protobuf compiler, also make sure we have the
# development libraries. If the check passes, libprotobuf will be
# automatically added to the LIBS environment variable. After
# this, we can use the HAVE_PROTOBUF flag to determine if we have
# got both protoc and libprotobuf available.
main['HAVE_PROTOBUF'] = main['HAVE_PROTOC'] and \
    conf.CheckLibWithHeader('protobuf', 'google/protobuf/message.h',
                            'C++', 'GOOGLE_PROTOBUF_VERIFY_VERSION;')

# Valgrind gets much less confused if you tell it when you're using
# alternative stacks.
main['HAVE_VALGRIND'] = conf.CheckCHeader('valgrind/valgrind.h')

# If we have the compiler but not the library, print another warning.
if main['HAVE_PROTOC'] and not main['HAVE_PROTOBUF']:
    warning('Did not find protocol buffer library and/or headers.\n'
            'Please install libprotobuf-dev for tracing support.')

# Check for librt.
have_posix_clock = \
    conf.CheckLibWithHeader([None, 'rt'], 'time.h', 'C',
                            'clock_nanosleep(0,0,NULL,NULL);')
if not have_posix_clock:
    warning("Can't find library for POSIX clocks.")

have_posix_timers = \
    conf.CheckLibWithHeader([None, 'rt'], [ 'time.h', 'signal.h' ], 'C',
                            'timer_create(CLOCK_MONOTONIC, NULL, NULL);')

if not GetOption('without_tcmalloc'):
    if conf.CheckLib('tcmalloc'):
        main.Append(CCFLAGS=main['TCMALLOC_CCFLAGS'])
    elif conf.CheckLib('tcmalloc_minimal'):
        main.Append(CCFLAGS=main['TCMALLOC_CCFLAGS'])
    else:
        warning("You can get a 12% performance improvement by "
                "installing tcmalloc (libgoogle-perftools-dev package "
                "on Ubuntu or RedHat).")


if conf.CheckLibWithHeader([None, 'execinfo'], 'execinfo.h', 'C',
        'char temp; backtrace_symbols_fd((void *)&temp, 0, 0);'):
    main['BACKTRACE_IMPL'] = 'glibc'
else:
    main['BACKTRACE_IMPL'] = 'none'
    warning("No suitable back trace implementation found.")

# Check for <fenv.h> (C99 FP environment control)
have_fenv = conf.CheckHeader('fenv.h', '<>')
if not have_fenv:
    warning("Header file <fenv.h> not found.\n"
            "This host has no IEEE FP rounding mode control.")

# Check for <png.h> (libpng library needed if wanting to dump
# frame buffer image in png format)
have_png = conf.CheckHeader('png.h', '<>')
if not have_png:
    warning("Header file <png.h> not found.\n"
            "This host has no libpng library.\n"
            "Disabling support for PNG framebuffers.")

# Check if we should enable KVM-based hardware virtualization. The API
# we rely on exists since version 2.6.36 of the kernel, but somehow
# the KVM_API_VERSION does not reflect the change. We test for one of
# the types as a fall back.
have_kvm = conf.CheckHeader('linux/kvm.h', '<>')
if not have_kvm:
    print("Info: Compatible header file <linux/kvm.h> not found, "
          "disabling KVM support.")

# Check if the TUN/TAP driver is available.
have_tuntap = conf.CheckHeader('linux/if_tun.h', '<>')
if not have_tuntap:
    print("Info: Compatible header file <linux/if_tun.h> not found.")

# Determine what ISA KVM can support on this host.
kvm_isa = None
host_isa = None
try:
    import platform
    host_isa = platform.machine()
except:
    pass

if not host_isa:
    warning("Failed to determine host ISA.")
elif not have_posix_timers:
    warning("Cannot enable KVM, host seems to lack support for POSIX timers")
elif host_isa in ('armv7l', 'aarch64'):
    kvm_isa = 'arm'
elif host_isa == 'x86_64':
    if conf.CheckTypeSize('struct kvm_xsave', '#include <linux/kvm.h>') != 0:
        kvm_isa = 'x86'
    else:
        warning("KVM on x86 requires xsave support in kernel headers.")


# Check if the exclude_host attribute is available. We want this to
# get accurate instruction counts in KVM.
main['HAVE_PERF_ATTR_EXCLUDE_HOST'] = conf.CheckMember(
    'linux/perf_event.h', 'struct perf_event_attr', 'exclude_host')

# Check if there is a pkg-config configuration for hdf5. If we find
# it, setup the environment to enable linking and header inclusion. We
# don't actually try to include any headers or link with hdf5 at this
# stage.
if have_pkg_config:
    conf.CheckPkgConfig(['hdf5-serial', 'hdf5'],
            '--cflags-only-I', '--libs-only-L')

# Check if the HDF5 libraries can be found. This check respects the
# include path and library path provided by pkg-config. We perform
# this check even if there isn't a pkg-config configuration for hdf5
# since some installations don't use pkg-config.
have_hdf5 = \
        conf.CheckLibWithHeader('hdf5', 'hdf5.h', 'C',
                                'H5Fcreate("", 0, 0, 0);') and \
        conf.CheckLibWithHeader('hdf5_cpp', 'H5Cpp.h', 'C++',
                                'H5::H5File("", 0);')
if not have_hdf5:
    warning("Couldn't find any HDF5 C++ libraries. Disabling HDF5 support.")

######################################################################
#
# Finish the configuration
#
main = conf.Finish()

######################################################################
#
# Collect all non-global variables
#

# Define the universe of supported ISAs
all_isa_list = [ ]
all_gpu_isa_list = [ ]
Export('all_isa_list')
Export('all_gpu_isa_list')

class CpuModel(object):
    '''The CpuModel class encapsulates everything the ISA parser needs to
    know about a particular CPU model.'''

    # Dict of available CPU model objects.  Accessible as CpuModel.dict.
    dict = {}

    # Constructor.  Automatically adds models to CpuModel.dict.
    def __init__(self, name, default=False):
        self.name = name           # name of model

        # This cpu is enabled by default
        self.default = default

        # Add self to dict
        if name in CpuModel.dict:
            raise AttributeError("CpuModel '%s' already registered" % name)
        CpuModel.dict[name] = self

Export('CpuModel')

# Sticky variables get saved in the variables file so they persist from
# one invocation to the next (unless overridden, in which case the new
# value becomes sticky).
sticky_vars = Variables(args=ARGUMENTS)
Export('sticky_vars')

# Sticky variables that should be exported
export_vars = []
Export('export_vars')

# For Ruby
all_protocols = []
Export('all_protocols')
protocol_dirs = []
Export('protocol_dirs')
slicc_includes = []
Export('slicc_includes')

# Walk the tree and execute all SConsopts scripts that wil add to the
# above variables
if GetOption('verbose'):
    print("Reading SConsopts")
for bdir in [ base_dir ] + extras_dir_list:
    if not isdir(bdir):
        error("Directory '%s' does not exist." % bdir)
    for root, dirs, files in os.walk(bdir):
        if 'SConsopts' in files:
            if GetOption('verbose'):
                print("Reading", joinpath(root, 'SConsopts'))
            SConscript(joinpath(root, 'SConsopts'))

all_isa_list.sort()
all_gpu_isa_list.sort()

sticky_vars.AddVariables(
    EnumVariable('TARGET_ISA', 'Target ISA', 'null', all_isa_list),
    EnumVariable('TARGET_GPU_ISA', 'Target GPU ISA', 'gcn3', all_gpu_isa_list),
    ListVariable('CPU_MODELS', 'CPU models',
                 sorted(n for n,m in CpuModel.dict.items() if m.default),
                 sorted(CpuModel.dict.keys())),
    BoolVariable('EFENCE', 'Link with Electric Fence malloc debugger',
                 False),
    BoolVariable('USE_SSE2',
                 'Compile for SSE2 (-msse2) to get IEEE FP on x86 hosts',
                 False),
    BoolVariable('USE_POSIX_CLOCK', 'Use POSIX Clocks', have_posix_clock),
    BoolVariable('USE_FENV', 'Use <fenv.h> IEEE mode control', have_fenv),
    BoolVariable('USE_PNG',  'Enable support for PNG images', have_png),
    BoolVariable('USE_KVM', 'Enable hardware virtualized (KVM) CPU models',
                 have_kvm),
    BoolVariable('USE_TUNTAP',
                 'Enable using a tap device to bridge to the host network',
                 have_tuntap),
    BoolVariable('BUILD_GPU', 'Build the compute-GPU model', False),
    EnumVariable('PROTOCOL', 'Coherence protocol for Ruby', 'None',
                  all_protocols),
    ('NUMBER_BITS_PER_SET', 'Max elements in set (default 64)',
                 64),
    BoolVariable('USE_HDF5', 'Enable the HDF5 support', have_hdf5),
    )

# These variables get exported to #defines in config/*.hh (see src/SConscript).
export_vars += ['USE_FENV', 'TARGET_ISA', 'TARGET_GPU_ISA',
                'USE_POSIX_CLOCK', 'USE_KVM', 'USE_TUNTAP', 'PROTOCOL',
                'HAVE_PROTOBUF', 'HAVE_VALGRIND',
                'HAVE_PERF_ATTR_EXCLUDE_HOST', 'USE_PNG',
                'NUMBER_BITS_PER_SET', 'USE_HDF5']

###################################################
#
# Define a SCons builder for configuration flag headers.
#
###################################################

# This function generates a config header file that #defines the
# variable symbol to the current variable setting (0 or 1).  The source
# operands are the name of the variable and a Value node containing the
# value of the variable.
def build_config_file(target, source, env):
    (variable, value) = [s.get_contents().decode('utf-8') for s in source]
    with open(str(target[0].abspath), 'w') as f:
        print('#define', variable, value, file=f)
    return None

# Combine the two functions into a scons Action object.
config_action = MakeAction(build_config_file, Transform("CONFIG H", 2))

# The emitter munges the source & target node lists to reflect what
# we're really doing.
def config_emitter(target, source, env):
    # extract variable name from Builder arg
    variable = str(target[0])
    # True target is config header file
    target = Dir('config').File(variable.lower() + '.hh')
    val = env[variable]
    if isinstance(val, bool):
        # Force value to 0/1
        val = int(val)
    elif isinstance(val, str):
        val = '"' + val + '"'

    # Sources are variable name & value (packaged in SCons Value nodes)
    return [target], [Value(variable), Value(val)]

config_builder = Builder(emitter=config_emitter, action=config_action)

main.Append(BUILDERS = { 'ConfigFile' : config_builder })

def add_local_rpath(env, *targets):
    '''Set up an RPATH for a library which lives in the build directory.

    The construction environment variable BIN_RPATH_PREFIX should be set to
    the relative path of the build directory starting from the location of the
    binary.'''
    for target in targets:
        target = env.Entry(target)
        if not isinstance(target, SCons.Node.FS.Dir):
            target = target.dir
        relpath = os.path.relpath(target.abspath, env['BUILDDIR'])
        components = [
            '\\$$ORIGIN',
            '${BIN_RPATH_PREFIX}',
            relpath
        ]
        env.Append(RPATH=[env.Literal(os.path.join(*components))])

if sys.platform != "darwin":
    main.Append(LINKFLAGS=Split('-z origin'))

main.AddMethod(add_local_rpath, 'AddLocalRPATH')

# builds in ext are shared across all configs in the build root.
ext_dir = Dir('#ext').abspath
ext_build_dirs = []
for root, dirs, files in os.walk(ext_dir):
    if 'SConscript' in files:
        build_dir = os.path.relpath(root, ext_dir)
        ext_build_dirs.append(build_dir)
        main.SConscript(joinpath(root, 'SConscript'),
                        variant_dir=joinpath(build_root, build_dir))

gdb_xml_dir = joinpath(ext_dir, 'gdb-xml')
Export('gdb_xml_dir')

###################################################
#
# This builder and wrapper method are used to set up a directory with
# switching headers. Those are headers which are in a generic location and
# that include more specific headers from a directory chosen at build time
# based on the current build settings.
#
###################################################

def build_switching_header(target, source, env):
    path = str(target[0])
    subdir = str(source[0])
    dp, fp = os.path.split(path)
    dp = os.path.relpath(os.path.realpath(dp),
                         os.path.realpath(env['BUILDDIR']))
    with open(path, 'w') as hdr:
        print('#include "%s/%s/%s"' % (dp, subdir, fp), file=hdr)

switching_header_action = MakeAction(build_switching_header,
                                     Transform('GENERATE'))

switching_header_builder = Builder(action=switching_header_action,
                                   source_factory=Value,
                                   single_source=True)

main.Append(BUILDERS = { 'SwitchingHeader': switching_header_builder })

def switching_headers(self, headers, source):
    for header in headers:
        self.SwitchingHeader(header, source)

main.AddMethod(switching_headers, 'SwitchingHeaders')

###################################################
#
# Define build environments for selected configurations.
#
###################################################

for variant_path in variant_paths:
    if not GetOption('silent'):
        print("Building in", variant_path)

    # Make a copy of the build-root environment to use for this config.
    env = main.Clone()
    env['BUILDDIR'] = variant_path

    # variant_dir is the tail component of build path, and is used to
    # determine the build parameters (e.g., 'X86')
    (build_root, variant_dir) = splitpath(variant_path)

    # Set env variables according to the build directory config.
    sticky_vars.files = []
    # Variables for $BUILD_ROOT/$VARIANT_DIR are stored in
    # $BUILD_ROOT/variables/$VARIANT_DIR so you can nuke
    # $BUILD_ROOT/$VARIANT_DIR without losing your variables settings.
    current_vars_file = joinpath(build_root, 'variables', variant_dir)
    if isfile(current_vars_file):
        sticky_vars.files.append(current_vars_file)
        if not GetOption('silent'):
            print("Using saved variables file %s" % current_vars_file)
    elif variant_dir in ext_build_dirs:
        # Things in ext are built without a variant directory.
        continue
    else:
        # Build dir-specific variables file doesn't exist.

        # Make sure the directory is there so we can create it later
        opt_dir = dirname(current_vars_file)
        if not isdir(opt_dir):
            mkdir(opt_dir)

        # Get default build variables from source tree.  Variables are
        # normally determined by name of $VARIANT_DIR, but can be
        # overridden by '--default=' arg on command line.
        default = GetOption('default')
        opts_dir = Dir('#build_opts').abspath
        if default:
            default_vars_files = [joinpath(build_root, 'variables', default),
                                  joinpath(opts_dir, default)]
        else:
            default_vars_files = [joinpath(opts_dir, variant_dir)]
        existing_files = list(filter(isfile, default_vars_files))
        if existing_files:
            default_vars_file = existing_files[0]
            sticky_vars.files.append(default_vars_file)
            print("Variables file %s not found,\n  using defaults in %s"
                  % (current_vars_file, default_vars_file))
        else:
            error("Cannot find variables file %s or default file(s) %s"
                  % (current_vars_file, ' or '.join(default_vars_files)))
            Exit(1)

    # Apply current variable settings to env
    sticky_vars.Update(env)

    Help('''
Build variables for {dir}:
{help}
'''.format(dir=variant_dir, help=sticky_vars.GenerateHelpText(env)),
         append=True)

    # Process variable settings.

    if not have_fenv and env['USE_FENV']:
        warning("<fenv.h> not available; forcing USE_FENV to False in",
                variant_dir + ".")
        env['USE_FENV'] = False

    if not env['USE_FENV']:
        warning("No IEEE FP rounding mode control in", variant_dir + ".\n"
                "FP results may deviate slightly from other platforms.")

    if not have_png and env['USE_PNG']:
        warning("<png.h> not available; forcing USE_PNG to False in",
                variant_dir + ".")
        env['USE_PNG'] = False

    if env['USE_PNG']:
        env.Append(LIBS=['png'])

    if env['EFENCE']:
        env.Append(LIBS=['efence'])

    if env['USE_KVM']:
        if not have_kvm:
            warning("Can not enable KVM, host seems to lack KVM support")
            env['USE_KVM'] = False
        elif kvm_isa != env['TARGET_ISA']:
            print("Info: KVM for %s not supported on %s host." %
                  (env['TARGET_ISA'], kvm_isa))
            env['USE_KVM'] = False

    if env['USE_TUNTAP']:
        if not have_tuntap:
            warning("Can't connect EtherTap with a tap device.")
            env['USE_TUNTAP'] = False

    if env['BUILD_GPU']:
        env.Append(CPPDEFINES=['BUILD_GPU'])

    # Warn about missing optional functionality
    if env['USE_KVM']:
        if not main['HAVE_PERF_ATTR_EXCLUDE_HOST']:
            warning("perf_event headers lack support for the exclude_host "
                    "attribute. KVM instruction counts will be inaccurate.")

    # Save sticky variable settings back to current variables file
    sticky_vars.Save(current_vars_file, env)

    if env['USE_SSE2']:
        env.Append(CCFLAGS=['-msse2'])

    env.Append(CCFLAGS='$CCFLAGS_EXTRA')
    env.Append(LINKFLAGS='$LDFLAGS_EXTRA')

    exports=['env']
    if main['USE_PYTHON']:
        exports.append('marshal_env')

    # The src/SConscript file sets up the build rules in 'env' according
    # to the configured variables.  It returns a list of environments,
    # one for each variant build (debug, opt, etc.)
    SConscript('src/SConscript', variant_dir=variant_path, exports=exports)

atexit.register(summarize_warnings)
