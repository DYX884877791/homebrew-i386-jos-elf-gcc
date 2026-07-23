class GccAT44 < Formula
  def arch
    "x86_64"
  end

  def osmajor
    `uname -r`.chomp
  end

  desc "GNU compiler collection"
  homepage "https://gcc.gnu.org"
  url "http://ftpmirror.gnu.org/gcc/gcc-4.4.7/gcc-4.4.7.tar.bz2"
  mirror "https://ftp.gnu.org/gnu/gcc/gcc-4.4.7/gcc-4.4.7.tar.bz2"
  sha256 "5ff75116b8f763fa0fb5621af80fc6fb3ea0f1b1a57520874982f03f26cd607f"
  
  depends_on "gmp@4-jos"
  depends_on "mpfr@2-jos"
  depends_on "ppl@0.11-jos"
  depends_on "cloog@0.15-jos"

  # Fix libffi for ppc, from MacPorts
  patch :p0 do
    url "https://trac.macports.org/export/110576/trunk/dports/lang/gcc44/files/ppc_fde_encoding.diff"
    sha256 "9c5f6fd30d089e97e0364af322272bb06f3d107f357d2b621503ebfbbb4a5af7"
  end

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

    languages = %w[c c++]

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
      "--with-ppl=#{Formula["ppl@0.11-jos"].opt_prefix}",
      "--disable-ppl-version-check",
      "--with-cloog=#{Formula["cloog@0.15-jos"].opt_prefix}",
      "--with-system-zlib",
      # This ensures lib, libexec, include are sandboxed so that they
      # don't wander around telling little children there is no Santa
      # Claus.
      "--enable-version-specific-runtime-libs",
      "--enable-libstdcxx-time=yes",
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

      system "make #{make_flags} bootstrap"

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
    system bin/"gcc-4.4", "-o", "hello-c", "hello-c.c"
    assert_equal "Hello, world!\n", `./hello-c`
  end
end

__END__
Index: gcc/config/darwin-c.c
===================================================================
--- gcc/config/darwin-c.c.orig
+++ gcc/config/darwin-c.c
@@ -565,29 +565,180 @@ find_subframework_header (cpp_reader *pf
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
 
@@ -606,7 +757,7 @@ darwin_cpp_builtins (cpp_reader *pfile)
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
--- gcc/doc/gcc.texi.old	2008-07-30 07:28:53.000000000 +0200
+++ gcc/doc/gcc.texi	2017-09-18 08:58:09.000000000 +0200
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
Index: gcc/doc/cppopts.texi
===================================================================
--- gcc/doc/cppopts.texi.orig
+++ gcc/doc/cppopts.texi
@@ -758,7 +758,7 @@ Replacement:      [    ]    @{    @}    
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
@@ -4645,11 +4645,11 @@ Dump after duplicating the computed goto
 @option{-fdump-rtl-ce3} enable dumping after the three
 if conversion passes. 
 
-@itemx -fdump-rtl-cprop_hardreg
+@item -fdump-rtl-cprop_hardreg
 @opindex fdump-rtl-cprop_hardreg
 Dump after hard register copy propagation.
 
-@itemx -fdump-rtl-csa
+@item -fdump-rtl-csa
 @opindex fdump-rtl-csa
 Dump after combining stack adjustments.
 
@@ -4660,11 +4660,11 @@ Dump after combining stack adjustments.
 @option{-fdump-rtl-cse1} and @option{-fdump-rtl-cse2} enable dumping after
 the two common sub-expression elimination passes.
 
-@itemx -fdump-rtl-dce
+@item -fdump-rtl-dce
 @opindex fdump-rtl-dce
 Dump after the standalone dead code elimination passes.
 
-@itemx -fdump-rtl-dbr
+@item -fdump-rtl-dbr
 @opindex fdump-rtl-dbr
 Dump after delayed branch scheduling.
 
@@ -4709,7 +4709,7 @@ Dump after the initialization of the reg
 @opindex fdump-rtl-initvals
 Dump after the computation of the initial value sets.
 
-@itemx -fdump-rtl-into_cfglayout
+@item -fdump-rtl-into_cfglayout
 @opindex fdump-rtl-into_cfglayout
 Dump after converting to cfglayout mode.
 
@@ -4739,7 +4739,7 @@ Dump after removing redundant mode switc
 @opindex fdump-rtl-rnreg
 Dump after register renumbering.
 
-@itemx -fdump-rtl-outof_cfglayout
+@item -fdump-rtl-outof_cfglayout
 @opindex fdump-rtl-outof_cfglayout
 Dump after converting from cfglayout mode.
 
@@ -4751,7 +4751,7 @@ Dump after the peephole pass.
 @opindex fdump-rtl-postreload
 Dump after post-reload optimizations.
 
-@itemx -fdump-rtl-pro_and_epilogue
+@item -fdump-rtl-pro_and_epilogue
 @opindex fdump-rtl-pro_and_epilogue
 Dump after generating the function pro and epilogues.
 
Index: gcc/doc/c-tree.texi
===================================================================
--- gcc/doc/c-tree.texi.orig
+++ gcc/doc/c-tree.texi
@@ -2338,13 +2338,13 @@ generate these expressions anyhow, if it
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
Index: boehm-gc/configure
===================================================================
--- boehm-gc/configure.orig
+++ boehm-gc/configure
@@ -6519,7 +6519,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: gcc/configure
===================================================================
--- gcc/configure.orig
+++ gcc/configure
@@ -16392,7 +16392,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: libffi/configure
===================================================================
--- libffi/configure.orig
+++ libffi/configure
@@ -5616,7 +5616,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: libgfortran/configure
===================================================================
--- libgfortran/configure.orig
+++ libgfortran/configure
@@ -6180,7 +6180,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: libgomp/configure
===================================================================
--- libgomp/configure.orig
+++ libgomp/configure
@@ -6040,7 +6040,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: libjava/classpath/configure
===================================================================
--- libjava/classpath/configure.orig
+++ libjava/classpath/configure
@@ -7635,7 +7635,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: libjava/configure
===================================================================
--- libjava/configure.orig
+++ libjava/configure
@@ -7887,7 +7887,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: libmudflap/configure
===================================================================
--- libmudflap/configure.orig
+++ libmudflap/configure
@@ -7648,7 +7648,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: libobjc/configure
===================================================================
--- libobjc/configure.orig
+++ libobjc/configure
@@ -5743,7 +5743,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: libssp/configure
===================================================================
--- libssp/configure.orig
+++ libssp/configure
@@ -6632,7 +6632,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: libstdc++-v3/configure
===================================================================
--- libstdc++-v3/configure.orig
+++ libstdc++-v3/configure
@@ -6460,7 +6460,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: zlib/configure
===================================================================
--- zlib/configure.orig
+++ zlib/configure
@@ -5595,7 +5595,7 @@ echo "${ECHO_T}$lt_cv_ld_exported_symbol
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;