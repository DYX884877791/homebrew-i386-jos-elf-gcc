class GccAT48 < Formula
  desc "GNU compiler collection"
  def arch
    "x86_64"
  end

  def osmajor
    `uname -r`.chomp
  end

  homepage "https://gcc.gnu.org"
  url "http://ftpmirror.gnu.org/gcc/gcc-4.8.5/gcc-4.8.5.tar.bz2"
  mirror "https://ftp.gnu.org/gnu/gcc/gcc-4.8.5/gcc-4.8.5.tar.bz2"
  sha256 "22fb1e7e0f68a63cee631d85b20461d1ea6bda162f03096350e38c8d427ecf23"

  head "svn://gcc.gnu.org/svn/gcc/branches/gcc-4_8-branch"

  if MacOS.version >= :yosemite
    # Fixes build on El Capitan
    # https://trac.macports.org/ticket/48471
    patch :p0 do
      url "https://raw.githubusercontent.com/Homebrew/formula-patches/dcfc5a2e6/gcc48/define_non_standard_clang_macros.patch"
      sha256 "e727383c9186fdc36f804c69ad550f5cfd2b996e37083be94c0c9aa8fde226ee"
    end
    # Fixes build with Xcode 7.
    # https://gcc.gnu.org/bugzilla/show_bug.cgi?id=66523
    # patch do
    #   url "https://gcc.gnu.org/bugzilla/attachment.cgi?id=35773"
    #   sha256 "db4966ade190fff4ed39976be8d13e84839098711713eff1d08920d37a58f5ec"
    # end
    #
    # use DATA PATCH instead
    patch :p1, :DATA

  end

  depends_on "gmp@4-jos"
  depends_on "libmpc@0.8-jos"
  depends_on "mpfr@2-jos"
  depends_on "isl@0.12-jos"
  depends_on "cloog@0.18-jos"

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
      "--libdir=#{lib}/gcc/#{version_suffix}",
      "--enable-languages=#{languages.join(",")}",
      # Make most executables versioned to avoid conflicts.
      "--program-suffix=-#{version_suffix}",
      "--with-gmp=#{Formula["gmp@4-jos"].opt_prefix}",
      "--with-mpfr=#{Formula["mpfr@2-jos"].opt_prefix}",
      "--with-mpc=#{Formula["libmpc@0.8-jos"].opt_prefix}",
      "--with-cloog=#{Formula["cloog@0.15-jos"].opt_prefix}",
      "--with-isl=#{Formula["isl@0.12-jos"].opt_prefix}",
      "--with-system-zlib",
      "--enable-libstdcxx-time=yes",
      "--enable-stage1-checking",
      "--enable-checking=release",
      "--enable-lto",
      # A no-op unless --HEAD is built because in head warnings will
      # raise errors. But still a good idea to include.
      "--disable-werror",
      "--with-pkgversion=Homebrew #{name} #{pkg_version} #{build.used_options*" "}".strip,
      "--with-bugurl=https://github.com/Homebrew/homebrew-versions/issues",
      # Even when suffixes are appended, the info pages conflict when
      # install-info is run.
      "MAKEINFO=missing"
    ]

    # Use 'bootstrap-debug' build configuration to force stripping of object
    # files prior to comparison during bootstrap (broken by Xcode 6.3).
    # This causes bottle errors for gcc48 on Mountain Lion, so scope it to 10.10.
    args << "--with-build-config=bootstrap-debug" if MacOS.version >= :yosemite

    # "Building GCC with plugin support requires a host that supports
    # -fPIC, -shared, -ldl and -rdynamic."
    args << "--enable-plugin" if MacOS.version > :tiger

    args << "--disable-nls" if build.without? "nls"

    args << "--enable-multilib"

    # Ensure correct install names when linking against libgcc_s;
    # see discussion in https://github.com/Homebrew/homebrew/pull/34303
    inreplace "libgcc/config/t-slibgcc-darwin", "@shlib_slibdir@", "#{HOMEBREW_PREFIX}/lib/gcc/#{version_suffix}"

    mkdir "build" do
      unless MacOS::CLT.installed?
        # For Xcode-only systems, we need to tell the sysroot path.
        # "native-system-header"s will be appended
        args << "--with-native-system-header-dir=/usr/include"
        args << "--with-sysroot=#{MacOS.sdk_path}"
      end

      system "../configure", *args

      if build.with? "profiled-build"
        # Takes longer to build, may bug out. Provided for those who want to
        # optimise all the way to 11.
        system "make", "profiledbootstrap"
      else
        system "make", "bootstrap"
      end

      # At this point `make check` could be invoked to run the testsuite. The
      # deja-gnu and autogen formulae must be installed in order to do this.

      system "make", "install"
    end

    # Handle conflicts between GCC formulae
    # Since GCC 4.8 libffi stuff are no longer shipped.
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
    system bin/"gcc-4.8", "-o", "hello-c", "hello-c.c"
    assert_equal "Hello, world!\n", `./hello-c`
  end
end

__END__
From 82f81877458ea372176eabb5de36329431dce99b Mon Sep 17 00:00:00 2001
From: Iain Sandoe <iain@codesourcery.com>
Date: Sat, 21 Dec 2013 00:30:18 +0000
Subject: [PATCH] don't try to mark local symbols as no-dead-strip

---
 gcc/config/darwin.c | 5 +++++
 1 file changed, 5 insertions(+)

diff --git a/gcc/config/darwin.c b/gcc/config/darwin.c
index 40804b8..0080299 100644
--- a/gcc/config/darwin.c
+++ b/gcc/config/darwin.c
@@ -1259,6 +1259,11 @@ darwin_encode_section_info (tree decl, rtx rtl, int first ATTRIBUTE_UNUSED)
 void
 darwin_mark_decl_preserved (const char *name)
 {
+  /* Actually we shouldn't mark any local symbol this way, but for now
+     this only happens with ObjC meta-data.  */
+  if (darwin_label_is_anonymous_local_objc_name (name))
+    return;
+
   fprintf (asm_out_file, "\t.no_dead_strip ");
   assemble_name (asm_out_file, name);
   fputc ('\n', asm_out_file);
--
2.2.1