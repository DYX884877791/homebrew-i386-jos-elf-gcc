class GccAT45 < Formula
  def arch
    "x86_64"
  end

  def osmajor
    `uname -r`.chomp
  end

  desc "GNU compiler collection"
  homepage "https://gcc.gnu.org"
  url "http://ftpmirror.gnu.org/gcc/gcc-4.5.4/gcc-4.5.4.tar.bz2"
  mirror "https://ftp.gnu.org/gnu/gcc/gcc-4.5.4/gcc-4.5.4.tar.bz2"
  sha256 "eef3f0456db8c3d992cbb51d5d32558190bc14f3bc19383dd93acc27acc6befc"

  # with system ld on Tiger, build fails with countless messages of:
  # "relocation overflow for relocation entry"
  # depends_on :ld64
  depends_on "gmp@4-jos"
  depends_on "libmpc@0.8-jos"
  depends_on "mpfr@2-jos"
  depends_on "ppl@0.11-jos"
  depends_on "cloog@0.15-jos"

  patch :p0, :DATA

  # Fix libffi for ppc, from MacPorts
  patch :p0 do
    url "https://trac.macports.org/export/110576/trunk/dports/lang/gcc45/files/ppc_fde_encoding.diff"
    sha256 "9c5f6fd30d089e97e0364af322272bb06f3d107f357d2b621503ebfbbb4a5af7"
  end

  # Handle OS X deployment targets correctly (GCC PR target/63810 <https://gcc.gnu.org/bugzilla/show_bug.cgi?id=63810>).
  patch :p0 do
    url "https://trac.macports.org/export/129382/trunk/dports/lang/gcc45/files/macosx-version-min.patch"
    sha256 "9083143d2c60fbd89d33354710381590da770973746dd6849e18835f449510bc"
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
      "--enable-languages=#{languages.join(",")}",
      # Make most executables versioned to avoid conflicts.
      "--program-suffix=-#{version_suffix}",
      "--with-gmp=#{Formula["gmp@4-jos"].opt_prefix}",
      "--with-mpfr=#{Formula["mpfr@2-jos"].opt_prefix}",
      "--with-mpc=#{Formula["libmpc@0.8-jos"].opt_prefix}",
      "--with-ppl=#{Formula["ppl@0.11-jos"].opt_prefix}",
      "--with-cloog=#{Formula["cloog@0.15-jos"].opt_prefix}",
      "--with-system-zlib",
      # This ensures lib, libexec, include are sandboxed so that they
      # don't wander around telling little children there is no Santa
      # Claus.
      "--enable-version-specific-runtime-libs",
      "--enable-libstdcxx-time=yes",
      "--enable-stage1-checking",
      "--enable-checking=release",
      # GCC 4.5 does not properly support LTO on Darwin.
      "--disable-lto",
      # A no-op unless --HEAD is built because in head warnings will
      # raise errors. But still a good idea to include.
      "--disable-werror",
      "--with-pkgversion=Homebrew #{name} #{pkg_version} #{build.used_options*" "}".strip,
      "--with-bugurl=https://github.com/Homebrew/homebrew-versions/issues",
      # Even when suffixes are appended, the info pages conflict when
      # install-info is run.
      "MAKEINFO=missing"
    ]

    # "Building GCC with plugin support requires a host that supports
    # -fPIC, -shared, -ldl and -rdynamic."
    args << "--enable-plugin" if MacOS.version > :tiger

    # Otherwise make fails during comparison at stage 3
    # See: http://gcc.gnu.org/bugzilla/show_bug.cgi?id=45248
    args << "--with-dwarf2" if MacOS.version < :leopard

    args << "--disable-nls"

    args << "--enable-multilib"
    
    args << "--disable-libgomp"

    mkdir "build" do
      unless MacOS::CLT.installed?
        # For Xcode-only systems, we need to tell the sysroot path.
        # "native-system-headers" will be appended
        args << "--with-native-system-header-dir=/usr/include"
        args << "--with-sysroot=#{MacOS.sdk_path}"
      end

      system "../configure", *args

      system "make", "bootstrap"

      # At this point `make check` could be invoked to run the testsuite. The
      # deja-gnu formula must be installed in order to do this.
      system "make", "install"

      # `make install` neglects to transfer an essential plugin header file.
      Pathname.new(Dir[prefix.join "**", "plugin", "include", "config"].first).install "../gcc/config/darwin-sections.def" if MacOS.version > :tiger
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
    system bin/"gcc-4.5", "-o", "hello-c", "hello-c.c"
    assert_equal "Hello, world!\n", `./hello-c`
  end
end

__END__
Index: boehm-gc/configure
===================================================================
--- boehm-gc/configure.orig
+++ boehm-gc/configure
@@ -7581,7 +7581,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
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
@@ -13588,7 +13588,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
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
@@ -6985,7 +6985,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
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
@@ -7492,7 +7492,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
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
@@ -7293,7 +7293,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
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
@@ -8286,7 +8286,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
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
@@ -9524,7 +9524,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
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
@@ -7072,7 +7072,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
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
@@ -6752,7 +6752,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
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
@@ -7043,7 +7043,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
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
@@ -7764,7 +7764,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
Index: lto-plugin/configure
===================================================================
--- lto-plugin/configure.orig
+++ lto-plugin/configure
@@ -6608,7 +6608,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
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
@@ -6578,7 +6578,7 @@ $as_echo "$lt_cv_ld_force_load" >&6; }
       case ${MACOSX_DEPLOYMENT_TARGET-10.0},$host in
 	10.0,*86*-darwin8*|10.0,*-darwin[91]*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
-	10.[012]*)
+	10.[012][,.]*)
 	  _lt_dar_allow_undefined='${wl}-flat_namespace ${wl}-undefined ${wl}suppress' ;;
 	10.*)
 	  _lt_dar_allow_undefined='${wl}-undefined ${wl}dynamic_lookup' ;;
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
--- gcc/doc/gcc.texi.old	2009-07-16 22:36:10.000000000 +0200
+++ gcc/doc/gcc.texi	2017-09-18 01:46:47.000000000 +0200
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
@@ -760,7 +760,7 @@ Replacement:      [    ]    @{    @}
 Enable special code to work around file systems which only permit very
 short file names, such as MS-DOS@.

-@itemx --help
+@item --help
 @itemx --target-help
 @opindex help
 @opindex target-help
Index: gcc/doc/generic.texi
===================================================================
--- gcc/doc/generic.texi.orig
+++ gcc/doc/generic.texi
@@ -1407,13 +1407,13 @@ generate these expressions anyhow, if it
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
Index: gcc/doc/invoke.texi
===================================================================
--- gcc/doc/invoke.texi.orig
+++ gcc/doc/invoke.texi
@@ -4875,11 +4875,11 @@ Dump after duplicating the computed goto
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

@@ -4890,11 +4890,11 @@ Dump after combining stack adjustments.
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

@@ -4939,7 +4939,7 @@ Dump after the initialization of the reg
 @opindex fdump-rtl-initvals
 Dump after the computation of the initial value sets.

-@itemx -fdump-rtl-into_cfglayout
+@item -fdump-rtl-into_cfglayout
 @opindex fdump-rtl-into_cfglayout
 Dump after converting to cfglayout mode.

@@ -4969,7 +4969,7 @@ Dump after removing redundant mode switc
 @opindex fdump-rtl-rnreg
 Dump after register renumbering.

-@itemx -fdump-rtl-outof_cfglayout
+@item -fdump-rtl-outof_cfglayout
 @opindex fdump-rtl-outof_cfglayout
 Dump after converting from cfglayout mode.

@@ -4981,7 +4981,7 @@ Dump after the peephole pass.
 @opindex fdump-rtl-postreload
 Dump after post-reload optimizations.

-@itemx -fdump-rtl-pro_and_epilogue
+@item -fdump-rtl-pro_and_epilogue
 @opindex fdump-rtl-pro_and_epilogue
 Dump after generating the function pro and epilogues.

diff --git libgomp/configure.tgt.orig libgomp/configure.tgt
--- libgomp/configure.tgt.orig	(revision a9afcd142ab200fd7f3f7bb30c472a1409ffefb3)
+++ libgomp/configure.tgt	(revision ae5b43c1f6001b9c0c1e78852b4d55663b7ce3d0)
@@ -48,14 +48,14 @@
 	;;

     # Note that bare i386 is not included here.  We need cmpxchg.
-    i[456]86-*-linux*)
+    i[3456]86-*-linux*)
 	config_path="linux/x86 linux posix"
 	case " ${CC} ${CFLAGS} " in
 	  *" -m64 "*)
 	    ;;
 	  *)
 	    if test -z "$with_arch"; then
-	      XCFLAGS="${XCFLAGS} -march=i486 -mtune=${target_cpu}"
+	      XCFLAGS="${XCFLAGS} -march=i486 -mtune=generic"
 	    fi
 	esac
 	;;
@@ -67,7 +67,7 @@ if test $enable_linux_futex = yes; then
 	config_path="linux/x86 linux posix"
 	case " ${CC} ${CFLAGS} " in
 	  *" -m32 "*)
-	    XCFLAGS="${XCFLAGS} -march=i486 -mtune=i686"
+	    XCFLAGS="${XCFLAGS} -march=i486 -mtune=generic"
 	    ;;
 	esac
 	;;
--- libgomp/omp.h.in.jj	2008-06-09 13:34:05.000000000 +0200
+++ libgomp/omp.h.in	2008-06-09 13:34:48.000000000 +0200
@@ -39,8 +39,8 @@ typedef struct
 
 typedef struct
 {
-  unsigned char _x[@OMP_NEST_LOCK_SIZE@] 
-    __attribute__((__aligned__(@OMP_NEST_LOCK_ALIGN@)));
+  unsigned char _x[8 + sizeof (void *)] 
+    __attribute__((__aligned__(sizeof (void *))));
 } omp_nest_lock_t;
 #endif
 
