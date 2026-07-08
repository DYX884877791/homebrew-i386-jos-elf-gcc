class GccAT46 < Formula
  def arch
    "x86_64"
  end

  def osmajor
    `uname -r`.chomp
  end

  desc "GNU compiler collection"
  homepage "https://gcc.gnu.org/"
  url "https://ftp.gnu.org/gnu/gcc/gcc-4.6.4/gcc-4.6.4.tar.bz2"
  mirror "https://ftpmirror.gnu.org/gcc/gcc-4.6.4/gcc-4.6.4.tar.bz2"
  sha256 "35af16afa0b67af9b8eb15cafb76d2bc5f568540552522f5dc2c88dd45d977e8"
  revision 2

  bottle do
    sha256 sierra:      "08fa2595627a85927e6cfd3eeb89af93e4f41598cda83ee28b5b213afa72b0c5"
    sha256 el_capitan:  "f423fb652caf588aee4e9b4b9936cd7fa203d4cc3e61175a5b5e93163d0f80bc"
    sha256 yosemite:    "f60768524f18e5d070469a736ce439f965eebbf76089913fd6881b4c1d779e78"
  end

  # Fixes build with Xcode 7.
  # https://gcc.gnu.org/bugzilla/show_bug.cgi?id=66523
  patch do
    url "https://gcc.gnu.org/bugzilla/attachment.cgi?id=35773"
    sha256 "db4966ade190fff4ed39976be8d13e84839098711713eff1d08920d37a58f5ec"
  end

  depends_on "gmp@4-jos"
  depends_on "libmpc@0.8-jos"
  depends_on "mpfr@2-jos"
  depends_on "ppl@0.11-jos"
  depends_on "cloog@0.15-jos"

  # The bottles are built on systems with the CLT installed, and do not work
  # out of the box on Xcode-only systems due to an incorrect sysroot.
  def pour_bottle?
    MacOS::CLT.installed?
  end

  # GCC bootstraps itself, so it is OK to have an incompatible C++ stdlib
  cxxstdlib_check :skip

  patch :p0 do
    url "https://raw.githubusercontent.com/macports/macports-ports/05dab25ebcba1614370b589a8cdb7b7d0e341007/lang/gcc46/files/gcc-4.6-cloog_lang_c.patch"
    sha256 "51e1c5981784b99ac65aed0fc2c50be5a3e023b45cea4e20b308a70f2a0661b4"
  end

  patch :p0 do
    url "https://raw.githubusercontent.com/macports/macports-ports/580a803587c463c9d5a68bcaa91fa75f384fa268/lang/gcc46/files/enable_libstdcxx_time_yes.patch"
    sha256 "e9e34c10db7849cc2f72e8e8d4d5e9cd1b3a2fe92fe317183fc575286999179f"
  end

  # Don't check Darwin kernel version (GCC PR target/61407
  # <https://gcc.gnu.org/bugzilla/show_bug.cgi?id=61407>).
  patch :p0 do
    url "https://raw.githubusercontent.com/macports/macports-ports/70b8c296e68e90d13e589c9d1ffae73f52484a3a/lang/gcc46/files/remove-kernel-version-check.patch"
    sha256 "7f23c4e98b3a673a9d0fbbe1636e72e210d4739f6f0df9ffe45f59df8ef578eb"
  end

  # Handle OS X deployment targets correctly (GCC PR target/63810
  # <https://gcc.gnu.org/bugzilla/show_bug.cgi?id=63810>).
  patch :p0 do
    url "https://raw.githubusercontent.com/macports/macports-ports/70b8c296e68e90d13e589c9d1ffae73f52484a3a/lang/gcc46/files/macosx-version-min.patch"
    sha256 "d8ad7c90e9de6a6288310ffe12498747da8db4c703317362e06c8298af7066ef"
  end

  # Don't link with "-flat_namespace -undefined suppress" on Yosemite and
  # later (#45483).
  patch :p0 do
    url "https://raw.githubusercontent.com/macports/macports-ports/77a7df3e41b6fac5c94934329cedb2fee8830344/lang/gcc46/files/yosemite-libtool.patch"
    sha256 "9fdcc58d6303e6c649e745f9dece182244874d40cbaf743cd8b5f8ecb0e72b5c"
  end

  def install
    # GCC will suffer build errors if forced to use a particular linker.
    ENV.delete "LD"

    # C, C++, ObjC compilers are always built
    languages = %w[c c++ objc obj-c++]

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
      "--enable-lto",
      "--enable-plugin",
      # A no-op unless --HEAD is built because in head warnings will
      # raise errors. But still a good idea to include.
      "--disable-werror",
      "--with-pkgversion=Homebrew GCC #{pkg_version} #{build.used_options*" "}".strip,
      "--with-bugurl=https://github.com/Homebrew/homebrew-core/issues",
      # Even when suffixes are appended, the info pages conflict when
      # install-info is run.
      "MAKEINFO=missing",
    ]

    args << "--enable-multilib"

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
      # deja-gnu and autogen formulae must be installed in order to do this.
      system "make", "install"
    end

    # Handle conflicts between GCC formulae.
    # Remove libffi stuff, which is not needed after GCC is built.
    Dir.glob(prefix/"**/libffi.*") { |file| File.delete file }
    # Rename libiberty.a.
    Dir.glob(prefix/"**/libiberty.*") { |file| add_suffix file, version_suffix }
    # Rename man7.
    Dir.glob(man7/"*.7") { |file| add_suffix file, version_suffix }
    # Even when we disable building info pages some are still installed.
    info.rmtree

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
    system bin/"gcc-4.6", "-o", "hello-c", "hello-c.c"
    assert_equal "Hello, world!\n", `./hello-c`
  end
end