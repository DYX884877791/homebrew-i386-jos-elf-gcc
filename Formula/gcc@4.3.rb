# https://github.com/paulirish/homebrew-versions-1/blob/master/gcc43.rb
class GccAT43 < Formula
  def arch
    "x86_64"
    # if Hardware::CPU.type == :intel
    #   if MacOS.prefer_64_bit?
    #     "x86_64"
    #   else
    #     "i686"
    #   end
    # elsif Hardware::CPU.type == :ppc
    #   if MacOS.prefer_64_bit?
    #     "powerpc64"
    #   else
    #     "powerpc"
    #   end
    # end
  end

  def osmajor
    `uname -r`.chomp
  end

  desc "GNU compiler collection"
  homepage "https://gcc.gnu.org"
  url "http://ftpmirror.gnu.org/gcc/gcc-4.3.6/gcc-4.3.6.tar.bz2"
  mirror "https://ftp.gnu.org/gnu/gcc/gcc-4.3.6/gcc-4.3.6.tar.bz2"
  sha256 "f3765cd4dcceb4d42d46f0d53471d7cedbad50f2112f0312c1dcc9c41eea9810"

  # bottle do
  #   sha256 "8bf79083ea4ad049f9c11a0bb2b46de64e54e9ae064c280e9af4b1cfdf44c912" => :mavericks
  #   sha256 "99ea8382997d8c0d67a950d5fe26b79b18ec56dc359eb8ef3d0f16bbcb77d3d5" => :mountain_lion
  # end

  option "with-profiled-build", "Make use of profile guided optimization when bootstrapping GCC"

  deprecated_option "enable-profiled-build" => "with-profiled-build"

  # depends_on MaximumMacOSRequirement => :mavericks
  depends_on "gmp@4-jos"
  depends_on "mpfr@2-jos"

  # Fix building on darwin10
  patch :p0 do
    url "https://trac.macports.org/export/110576/trunk/dports/lang/gcc43/files/darwin10.diff"
    sha256 "df1019b634f4e1b28c8a62f98374a1acc67e4540c65372fb87e84914d56c6daf"
  end

  # Fix multilib
  patch :p0 do
    url "https://trac.macports.org/export/110576/trunk/dports/lang/gcc43/files/i386_multilib.diff"
    sha256 "e5e94df259db4cc5c14a61f2553fc1a496052cbd306d23ba95dccf9f01517795"
  end

  # Build fix for Snow Leopard
  patch :p0 do
    url "https://trac.macports.org/export/110576/trunk/dports/lang/gcc43/files/Make-lang.in.diff"
    sha256 "3e4e860b1a718fc43005681025448f7f6fd820f892a20419a723b887c588075e"
  end

  # Fix libffi fix for ppc
  patch :p0 do
    url "https://trac.macports.org/export/110576/trunk/dports/lang/gcc43/files/ppc_fde_encoding.diff"
    sha256 "9c5f6fd30d089e97e0364af322272bb06f3d107f357d2b621503ebfbbb4a5af7"
  end

  # Fix texinfo related issue
  patch :p0, :DATA

  fails_with :llvm

  # The bottles are built on systems with the CLT installed, and do not work
  # out of the box on Xcode-only systems due to an incorrect sysroot.
  def pour_bottle?
    MacOS::CLT.installed?
  end

  # GCC bootstraps itself, so it is OK to have an incompatible C++ stdlib
  cxxstdlib_check :skip

  def install
    # GCC will suffer build errors if forced to use a particular linker.
    ENV.delete "LD"

    # C, C++, ObjC compilers are always built
    languages = %w[c c++ objc obj-c++]

    version_suffix = version.to_s.slice(/\d\.\d/)

    args = [
      "--build=#{arch}-apple-darwin#{osmajor}",
      "--prefix=#{prefix}",
      "--mandir=#{man}",
      "--infodir=#{info}",
      "--enable-languages=#{languages.join(",")}",
      # Make most executables versioned to avoid conflicts.
      "--program-suffix=-#{version_suffix}",
      "--with-gmp=#{Formula["gmp@4-jos"].opt_prefix}",
      "--with-mpfr=#{Formula["mpfr@2-jos"].opt_prefix}",
      "--with-system-zlib",
      # This ensures lib, libexec, include are sandboxed so that they
      # don't wander around telling little children there is no Santa
      # Claus.
      "--enable-version-specific-runtime-libs",
      "--enable-stage1-checking",
      "--enable-checking=release",
      "--enable-multilib",
      # A no-op unless --HEAD is built because in head warnings will
      # raise errors. But still a good idea to include.
      "--disable-werror",
      "--with-pkgversion=Homebrew #{name} #{pkg_version} #{build.used_options*" "}".strip,
      "--with-bugurl=https://github.com/Homebrew/homebrew-versions/issues",
      # Even when suffixes are appended, the info pages conflict when
      # install-info is run.
      "MAKEINFO=missing"
    ]

    args << "--disable-nls"

    mkdir "build" do
      unless MacOS::CLT.installed?
        # For Xcode-only systems, we need to tell the sysroot path.
        # "native-system-headers" will be appended
        args << "--with-native-system-header-dir=/usr/include"
        args << "--with-sysroot=#{MacOS.sdk_path}"
      end

      system "../configure", *args

      # Flags for Clang compatibility
      make_flags = 'BOOT_CFLAGS="$BOOT_CFLAGS -D_FORTIFY_SOURCE=0" STAGE1_CFLAGS="$STAGE1_CFLAGS -std=gnu89 -D_FORTIFY_SOURCE=0 -fkeep-inline-functions"'

      if build.with? "profiled-build"
        # Takes longer to build, may bug out. Provided for those who want to
        # optimise all the way to 11.
        system "make V=1 #{make_flags} profiledbootstrap"
      else
        system "echo #{make_flags}"
        system "make V=1 #{make_flags} bootstrap"
      end

      # At this point `make check` could be invoked to run the testsuite. The
      # deja-gnu formula must be installed in order to do this.
      system "make", "install"
    end

    # Handle conflicts between GCC formulae.
    # Remove libffi stuff, which is not needed after GCC is built.
    Dir.glob(prefix/"**/libffi.*") { |file| File.delete file }
    # Rename libiberty.a.
    Dir.glob(prefix/"**/libiberty.*") { |file| add_suffix file, version_suffix }
    # Rename man7.
    Dir.glob(man7/"*.7") { |file| add_suffix file, version_suffix }

    # Even when suffixes are appended, the info pages conflict when
    # install-info is run. Fix this.
    info.rmtree

    # Rename java properties
    if build.with?("java") || build.with?("all-languages")
      config_files = [
        "#{lib}/logging.properties",
        "#{lib}/security/classpath.security",
        "#{lib}/i386/logging.properties",
        "#{lib}/i386/security/classpath.security",
      ]

      config_files.each do |file|
        add_suffix file, version_suffix if File.exist? file
      end
    end
  end

  def add_suffix(file, suffix)
    dir = File.dirname(file)
    ext = File.extname(file)
    base = File.basename(file, ext)
    File.rename file, "#{dir}/#{base}-#{suffix}#{ext}"
  end

  test do
    (testpath/"hello-c.c").write <<-EOS.undent
      #include <stdio.h>
      int main()
      {
        puts("Hello, world!");
        return 0;
      }
    EOS
    system bin/"gcc-4.3", "-o", "hello-c", "hello-c.c"
    assert_equal "Hello, world!\n", `./hello-c`
  end
end

__END__
Index: gcc/doc/cppopts.texi
===================================================================
--- gcc/doc/cppopts.texi.orig
+++ gcc/doc/cppopts.texi
@@ -754,7 +754,7 @@ Replacement:      [    ]    @{    @}
 Enable special code to work around file systems which only permit very
 short file names, such as MS-DOS@.

-@itemx --help
+@item --help
 @itemx --target-help
 @opindex help
 @opindex target-help
Index: gcc/doc/invoke.texi
===================================================================
--- gcc/doc/invoke.texi.orig
+++ gcc/doc/invoke.texi
@@ -958,7 +958,7 @@ instantiation), or a library unit renami
 generic, or subprogram renaming declaration).  Such files are also
 called @dfn{specs}.

-@itemx @var{file}.adb
+@item @var{file}.adb
 Ada source code file containing a library unit body (a subprogram or
 package body).  Such files are also called @dfn{bodies}.

@@ -8571,7 +8571,7 @@ assembly code.  Permissible names are: @
 @samp{cortex-a8}, @samp{cortex-r4}, @samp{cortex-m3},
 @samp{xscale}, @samp{iwmmxt}, @samp{ep9312}.

-@itemx -mtune=@var{name}
+@item -mtune=@var{name}
 @opindex mtune
 This option is very similar to the @option{-mcpu=} option, except that
 instead of specifying the actual target processor type, and hence
Index: gcc/doc/c-tree.texi
===================================================================
--- gcc/doc/c-tree.texi.orig
+++ gcc/doc/c-tree.texi
@@ -2325,13 +2325,13 @@ generate these expressions anyhow, if it
 not matter.  The type of the operands and that of the result are
 always of @code{BOOLEAN_TYPE} or @code{INTEGER_TYPE}.

-@itemx POINTER_PLUS_EXPR
+@item POINTER_PLUS_EXPR
 This node represents pointer arithmetic.  The first operand is always
 a pointer/reference type.  The second operand is always an unsigned
 integer type compatible with sizetype.  This is the only binary
 arithmetic operand that can operate on pointer types.

-@itemx PLUS_EXPR
+@item PLUS_EXPR
 @itemx MINUS_EXPR
 @itemx MULT_EXPR
 These nodes represent various binary arithmetic operations.
Index: gcc/doc/extend.texi
===================================================================
--- gcc/doc/extend.texi.orig
+++ gcc/doc/extend.texi
@@ -4231,6 +4231,8 @@ and caught in another, the class must ha
 Otherwise the two shared objects will be unable to use the same
 typeinfo node and exception handling will break.

+@end table
+
 @subsection ARM Type Attributes

 On those ARM targets that support @code{dllimport} (such as Symbian
@@ -4260,6 +4262,8 @@ most Symbian OS code uses @code{__declsp
 Two attributes are currently defined for i386 configurations:
 @code{ms_struct} and @code{gcc_struct}

+@table @code
+
 @item ms_struct
 @itemx gcc_struct
 @cindex @code{ms_struct}
Index: gcc/doc/gcc.texi
===================================================================
--- gcc/doc/gcc.texi.old	2008-04-01 20:49:36.000000000 +0200
+++ gcc/doc/gcc.texi	2017-09-18 08:52:36.000000000 +0200
@@ -84,11 +84,11 @@ This file documents the use of the GNU c
 Published by:
 @multitable @columnfractions 0.5 0.5
 @item GNU Press
-@tab Website: www.gnupress.org
+@tab Website: @uref{http://www.gnupress.org}
 @item a division of the
-@tab General: @tex press@@gnu.org @end tex
+@tab General: @email{press@@gnu.org}
 @item Free Software Foundation
-@tab Orders:  @tex sales@@gnu.org @end tex
+@tab Orders:  @email{sales@@gnu.org}
 @item 51 Franklin Street, Fifth Floor
 @tab Tel 617-542-5942
 @item Boston, MA 02110-1301 USA
Index: gcc/config/darwin-c.c
===================================================================
--- gcc/config/darwin-c.c.orig
+++ gcc/config/darwin-c.c
@@ -564,29 +564,180 @@ find_subframework_header (cpp_reader *pf
   return 0;
 }

-/* Return the value of darwin_macosx_version_min suitable for the
-   __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ macro,
-   so '10.4.2' becomes 1040.  The lowest digit is always zero.
-   Print a warning if the version number can't be understood.  */
+/*  Given a version string, return the version as a statically-allocated
+    array of three non-negative integers.  If the version string is
+    invalid, return null.
+
+    Version strings must consist of one, two, or three tokens, each
+    separated by a single period.  Each token must contain only the
+    characters '0' through '9' and is converted to an equivalent
+    integer.  Omitted tokens are treated as zeros.  For example:
+
+        "10"              becomes   {10,0,0}
+        "10.10"           becomes   {10,10,0}
+        "10.10.1"         becomes   {10,10,1}
+        "10.000010.1"     becomes   {10,10,1}
+        "10.010.001"      becomes   {10,10,1}
+        "000010.10.00001" becomes   {10,10,1}  */
+
+enum version_components { MAJOR, MINOR, TINY };
+
+static const unsigned long *
+parse_version (const char *version_str)
+{
+  size_t version_len;
+  char *end;
+  static unsigned long version_array[3];
+
+  if (! version_str)
+    return NULL;
+
+  version_len = strlen (version_str);
+  if (version_len < 1)
+    return NULL;
+
+  /* Version string must consist of digits and periods only.  */
+  if (strspn (version_str, "0123456789.") != version_len)
+    return NULL;
+
+  if (! ISDIGIT (version_str[0]) || ! ISDIGIT (version_str[version_len - 1]))
+    return NULL;
+
+  version_array[MAJOR] = strtoul (version_str, &end, 10);
+  version_str = end + ((*end == '.') ? 1 : 0);
+
+  /* Version string must not contain adjacent periods.  */
+  if (*version_str == '.')
+    return NULL;
+
+  version_array[MINOR] = strtoul (version_str, &end, 10);
+  version_str = end + ((*end == '.') ? 1 : 0);
+
+  version_array[TINY] = strtoul (version_str, &end, 10);
+
+  /* Version string must contain no more than three tokens.  */
+  if (*end != '\0')
+    return NULL;
+
+  return version_array;
+}
+
+/*  Given a three-component version represented as an array of
+    non-negative integers, return a statically-allocated string suitable
+    for the legacy __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ macro.
+    If the version is invalid and cannot be coerced into a valid form,
+    return null.
+
+    The legacy format is a four-character string -- two chars for the
+    major number and one each for the minor and tiny numbers.  Major
+    numbers are zero-padded if necessary.  Minor and tiny numbers from
+    10 through 99 are permitted but are clamped to 9 (for example,
+    {10,9,10} produces "1099").  Versions containing numbers greater
+    than 99 are rejected.  */
+
+static const char *
+version_as_legacy_macro (const unsigned long *version)
+{
+  unsigned long major, minor, tiny;
+  static char result[sizeof "9999"];
+
+  if (! version)
+    return NULL;
+
+  major = version[MAJOR];
+  minor = version[MINOR];
+  tiny = version[TINY];
+
+  if (major > 99 || minor > 99 || tiny > 99)
+    return NULL;
+
+  minor = ((minor > 9) ? 9 : minor);
+  tiny = ((tiny > 9) ? 9 : tiny);
+
+  /* NOTE: Cast result of sizeof so that result of sprintf is not
+     converted to an unsigned type.  */
+  if (sprintf (result, "%02lu%lu%lu", major, minor, tiny)
+      != (int) sizeof "9999" - 1)
+    return NULL;
+
+  return result;
+}
+
+/*  Given a three-component version represented as an array of
+    non-negative integers, return a statically-allocated string suitable
+    for the modern __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ macro
+    or the __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ macro.  If the
+    version is invalid, return null.
+
+    The modern format is a five- or six-character string -- one or two
+    chars for the major number and two each for the minor and tiny
+    numbers, which are zero-padded if necessary (for example, {8,1,0}
+    produces "80100", and {10,10,1} produces "101001").  Versions
+    containing numbers greater than 99 are rejected.  */
+
 static const char *
-version_as_macro (void)
+version_as_modern_macro (const unsigned long *version)
 {
-  static char result[] = "1000";
+  unsigned long major, minor, tiny;
+  static char result[sizeof "999999"];
+
+  if (! version)
+    return NULL;
+
+  major = version[MAJOR];
+  minor = version[MINOR];
+  tiny = version[TINY];
+
+  if (major > 99 || minor > 99 || tiny > 99)
+    return NULL;
+
+  /* NOTE: 'sizeof ((x > y) ? "foo" : "bar")' returns size of char
+     pointer instead of char array, so use
+     '(x > y) ? sizeof "foo" : sizeof "bar"' instead.  */
+  /* NOTE: Cast result of sizeof so that result of sprintf is not
+     converted to an unsigned type.  */
+  if (sprintf (result, "%lu%02lu%02lu", major, minor, tiny)
+      != (int) ((major > 9) ? sizeof "999999" : sizeof "99999") - 1)
+    return NULL;

-  if (strncmp (darwin_macosx_version_min, "10.", 3) != 0)
+  return result;
+}
+
+/*  Return the value of darwin_macosx_version_min, suitably formatted
+    for the __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ macro.  Values
+    representing OS X 10.9 and earlier are encoded using the legacy
+    four-character format, while 10.10 and later use a modern
+    six-character format.  (For example, "10.9" produces "1090", and
+    "10.10.1" produces "101001".)  If the value is invalid and cannot be
+    coerced into a valid form, print a warning and return "1000".  */
+
+static const char *
+macosx_version_as_macro (void)
+{
+  const unsigned long *version_array;
+  const char *version_macro;
+
+  version_array = parse_version (darwin_macosx_version_min);
+  if (! version_array)
     goto fail;
-  if (! ISDIGIT (darwin_macosx_version_min[3]))
+
+  /* Do not assume that the major number will always be exactly 10.  */
+  if (version_array[MAJOR] < 10 || version_array[MAJOR] > 10)
     goto fail;
-  result[2] = darwin_macosx_version_min[3];
-  if (darwin_macosx_version_min[4] != '\0'
-      && darwin_macosx_version_min[4] != '.')
+
+  if (version_array[MAJOR] == 10 && version_array[MINOR] < 10)
+    version_macro = version_as_legacy_macro (version_array);
+  else
+    version_macro = version_as_modern_macro (version_array);
+
+  if (! version_macro)
     goto fail;

-  return result;
+  return version_macro;

  fail:
-  error ("Unknown value %qs of -mmacosx-version-min",
-	 darwin_macosx_version_min);
+  error ("unknown value %qs of -mmacosx-version-min",
+         darwin_macosx_version_min);
   return "1000";
 }

@@ -605,7 +756,7 @@ darwin_cpp_builtins (cpp_reader *pfile)
   builtin_define_with_value ("__APPLE_CC__", "1", false);

   builtin_define_with_value ("__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__",
-			     version_as_macro(), false);
+			     macosx_version_as_macro(), false);
 }

 /* Handle C family front-end options.  */
Index: gcc/config/darwin-driver.c
===================================================================
--- gcc/config/darwin-driver.c.orig
+++ gcc/config/darwin-driver.c
@@ -120,8 +120,6 @@ darwin_default_min_version (int * argc_p
   version_p = osversion + 1;
   if (ISDIGIT (*version_p))
     major_vers = major_vers * 10 + (*version_p++ - '0');
-  if (major_vers > 4 + 9)
-    goto parse_failed;
   if (*version_p++ != '.')
     goto parse_failed;
   version_pend = strchr(version_p, '.');
--- Makefile.in.orig	2021-07-05 21:24:36.000000000 -0700
+++ Makefile.in	2021-07-05 21:25:45.000000000 -0700
@@ -575,6 +575,12 @@
 @host_makefile_frag@
 ###

+# override MacPorts cctools modifications to allow standard gas assembler  to be used
+HOST_EXPORTS            += export DISABLE_MACPORTS_AS_CLANG_SEARCH=1;
+HOST_EXPORTS            += export DISABLE_XCODE_AS_CLANG_SEARCH=1;
+POSTSTAGE1_HOST_EXPORTS += export DISABLE_MACPORTS_AS_CLANG_SEARCH=1;
+POSTSTAGE1_HOST_EXPORTS += export DISABLE_XCODE_AS_CLANG_SEARCH=1;
+
 # This is the list of directories that may be needed in RPATH_ENVVAR
 # so that programs built for the target machine work.
 TARGET_LIB_PATH = $(TARGET_LIB_PATH_libstdc++-v3)$(TARGET_LIB_PATH_libsanitizer)$(TARGET_LIB_PATH_libmpx)$(TARGET_LIB_PATH_libvtv)$(TARGET_LIB_PATH_libcilkrts)$(TARGET_LIB_PATH_liboffloadmic)$(TARGET_LIB_PATH_libssp)$(TARGET_LIB_PATH_libgomp)$(TARGET_LIB_PATH_libitm)$(TARGET_LIB_PATH_libatomic)$(HOST_LIB_PATH_gcc)