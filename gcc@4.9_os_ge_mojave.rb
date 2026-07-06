class GccAT49OsGeMojave < Formula
  def osmajor
    `uname -r`.chomp
  end

  desc "The GNU Compiler Collection"
  homepage "https://gcc.gnu.org/"
  url "https://ftp.gnu.org/gnu/gcc/gcc-4.9.4/gcc-4.9.4.tar.bz2"
  mirror "https://ftpmirror.gnu.org/gcc/gcc-4.9.4/gcc-4.9.4.tar.bz2"
  sha256 "6c11d292cd01b294f9f84c9a59c230d80e9e4a47e5c6355f046bb36d4f358092"
  revision 2

  # The bottles are built on systems with the CLT installed, and do not work
  # out of the box on Xcode-only systems due to an incorrect sysroot.
  pour_bottle? do
    reason "The bottle needs the Xcode CLT to be installed."
    satisfy { MacOS::CLT.installed? }
  end

  depends_on :maximum_macos => [:catalina, :build]

  # GCC bootstraps itself, so it is OK to have an incompatible C++ stdlib
  # cxxstdlib_check :skip

  resource "gmp" do
    url "https://ftp.gnu.org/gnu/gmp/gmp-4.3.2.tar.bz2"
    mirror "https://ftpmirror.gnu.org/gmp/gmp-4.3.2.tar.bz2"
    sha256 "936162c0312886c21581002b79932829aa048cfaf9937c6265aeaa14f1cd1775"

    # Upstream patch to fix gmp.h header use in C++ compilation with libc++
    # https://gmplib.org/repo/gmp/rev/6cd3658f5621
    patch do
      url "https://raw.githubusercontent.com/Homebrew/formula-patches/010a4dc3/gmp%404/4.3.2.patch"
      sha256 "7865e09e154d4696e850779403e6c75be323f069356dedb7751cf1575db3a148"
    end
  end

  resource "mpfr" do
    url "https://gcc.gnu.org/pub/gcc/infrastructure/mpfr-2.4.2.tar.bz2"
    mirror "https://mirrorservice.org/sites/sourceware.org/pub/gcc/infrastructure/mpfr-2.4.2.tar.bz2"
    sha256 "c7e75a08a8d49d2082e4caee1591a05d11b9d5627514e678f02d66a124bcf2ba"
  end

  resource "mpc" do
    url "https://gcc.gnu.org/pub/gcc/infrastructure/mpc-0.8.1.tar.gz"
    sha256 "e664603757251fd8a352848276497a4c79b7f8b21fd8aedd5cc0598a38fee3e4"
  end

  resource "isl" do
    url "https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.12.2.tar.bz2"
    mirror "https://mirrorservice.org/sites/distfiles.macports.org/isl/isl-0.12.2.tar.bz2"
    sha256 "f4b3dbee9712850006e44f0db2103441ab3d13b406f77996d1df19ee89d11fb4"
  end

  resource "cloog" do
    url "https://www.bastoul.net/cloog/pages/download/count.php3?url=./cloog-0.18.4.tar.gz"
    mirror "https://mirrorservice.org/sites/archive.ubuntu.com/ubuntu/pool/main/c/cloog/cloog_0.18.4.orig.tar.gz"
    sha256 "325adf3710ce2229b7eeb9e84d3b539556d093ae860027185e7af8a8b00a750e"
  end

  # Fix build with Xcode 9
  # https://gcc.gnu.org/bugzilla/show_bug.cgi?id=82091
  if DevelopmentTools.clang_build_version >= 900
    patch do
      url "https://raw.githubusercontent.com/Homebrew/formula-patches/c2dae73416/gcc%404.9/xcode9.patch"
      sha256 "92c13867afe18ccb813526c3b3c19d95a2dd00973f9939cf56ab7698bdd38108"
    end
  end

  # Fix issues with macOS 10.13 or higher headers and parallel build on APFS
  if MacOS.version >= :mojave
    patch do
      url "https://raw.githubusercontent.com/Homebrew/formula-patches/b7c7883d/gcc%404.9/high_sierra_2.patch"
      sha256 "c7bcad4657292f6939b7322eb5e821c4a110c4f326fd5844890f0e9a85da8cae"
    end
    if DevelopmentTools.clang_build_version >= 1000
      patch do
        url "https://raw.githubusercontent.com/sofair/gcc49mojave_brew/master/gcc_49_os_ge_mojave_fix3.patch"
        sha256 "ab297141f9d4387935c2e3bb7519fac83133efdb6b81216e8764cbe406655a5a"
      end
    end
  end

  def install
    # GCC will suffer build errors if forced to use a particular linker.
    ENV.delete "LD"

    # Build dependencies in-tree, to avoid having versioned formulas
    resources.each { |r| r.stage(buildpath/r.name) }

    version_suffix = version.to_s.slice(/\d\.\d/)

    args = [
      "--build=x86_64-apple-darwin#{osmajor}",
      "--prefix=#{prefix}",
      "--libdir=#{lib}/gcc/#{version_suffix}",
      "--enable-languages=c,c++",
      # Make most executables versioned to avoid conflicts.
      "--program-suffix=-#{version_suffix}",
      "--with-system-zlib",
      "--enable-libstdcxx-time=yes",
      "--enable-stage1-checking",
      "--enable-checking=release",
      "--enable-lto",
      "--enable-plugin",
      # Use 'bootstrap-debug' build configuration to force stripping of object
      # files prior to comparison during bootstrap (broken by Xcode 6.3).
      "--with-build-config=bootstrap-debug",
      # A no-op unless --HEAD is built because in head warnings will
      # raise errors. But still a good idea to include.
      "--disable-werror",
      "--with-pkgversion=Homebrew GCC #{pkg_version} #{build.used_options*" "}".strip,
      "--with-bugurl=https://github.com/Homebrew/homebrew-core/issues",
      # Even when suffixes are appended, the info pages conflict when
      # install-info is run.
      "MAKEINFO=missing",
      "--disable-nls",
      "--enable-multilib",
    ]

    # Ensure correct install names when linking against libgcc_s;
    # see discussion in https://github.com/Homebrew/homebrew/pull/34303
    inreplace "libgcc/config/t-slibgcc-darwin", "@shlib_slibdir@", "#{HOMEBREW_PREFIX}/lib/gcc/#{version_suffix}"

    mkdir "build" do
      #unless MacOS::CLT.installed?
        # For Xcode-only systems, we need to tell the sysroot path.
        # "native-system-headers" will be appended
        args << "--with-native-system-header-dir=/usr/include"
        args << "--with-sysroot=#{MacOS.sdk_path}"
      #end

      # 一、配置
      # 先选择要把 GCC 构建在哪个目录，构建之前需要先进行 configure, 不要选在源文件所 在目录或其子目录，GCC 并不支持这样做。
      #
      # GCC 的配置选项很多，初次接触的话可以尽量简单配置，比如：
      #
      # 选项	描述
      # --enable-languages	指定要构建哪些语言对应的编译器及运行时库
      # --prefix	指定安装目录，不要与源码或构建目录相同
      # --disable-bootstrap	禁止 bootstrap
      # GCC 在构建时，默认会构建 3 次：
      # 1. 用本地 gcc 作为编译器构建出 stage1-gcc
      # 2. 用 stage1-gcc 作为编译器构建出 stage2-gcc
      # 3. 用 stage2-gcc 作为编译器构建出 stage3-gcc
      #
      # 这个过程叫做 bootstrap 。
      #
      # 对比 Stage 2 和 Stage 3 的输出：
      #   如果两者编译结果一致，说明编译器生成的是“自我一致”的（self-hosting）。
      #   如果不一致，说明中间某个阶段的编译器可能有 Bug。
      #
      # stage3-gcc 被认为是最好或最符合源码的一个构建，但比较费时，可以使用 --disable-bootstrap 来禁止。
      # 但需要注意，在修改过源码后，如果没有 bootstrap 可以编译通过，并不代表 bootstrap 一定会过。（要不然 bootstrap 也没有存在的意义 了。）
      #
      # 二、为什么启用 Bootstrap？
      # 启用 --enable-bootstrap 的优点：
      #
      # ✅ 确保可靠性：通过多次自编译验证最终生成的编译器稳定无误。
      # ✅ 捕捉错误：可以捕捉某些编译器 bug 或平台特有的问题。
      # ✅ 适用于生产版本编译器：官方发布的 GCC 编译器都是使用 bootstrap 构建的。
      #
      # 三、何时禁用 Bootstrap？
      # 你可能会想禁用它（使用 --disable-bootstrap）的场景：
      #
      # 🧱 在资源受限的系统上（时间或 CPU 不足）。
      # 🛠️ 仅用于构建测试版本，时间优先。
      # 🧪 开发者调试编译器，而不是用来发布。
      #
      #
      # 还有就是 GCC 默认是构建 release 版本，不利于调试，如果要构建 debug 版，需要在 configure 时就进行配置，构建 debug 版的命令为(假设 GCC 源码位于 ${GCC_SRC})：
      #
      # CFLAGS="-O0 -g3 -fno-inline"              \
      # CXXFLAGS="-O0 -g3 -fno-inline"            \
      # CFLAGS_FOR_BUILD="-O0 -g3 -fno-inline"    \
      # CFLAGS_FOR_TARGET="-O0 -g3 -fno-inline"   \
      # CXXFLAGS_FOR_BUILD="-O0 -g3 -fno-inline"  \
      # CXXFLAGS_FOR_TARGET="-O0 -g3 -fno-inline" \
      # ${GCC_SRC}/configure --enable-languages=c,c++ --disable-bootstrap --prefix=/tmp/gcc-tmpi
      # 构建 release 版的命令为（如果不需要 bootstrap，可以自己加上参数）：
      #
      # ${GCC_SRC}/configure --enable-languages=c,c++ --prefix=/tmp/gcc-tmpi
      # 如果 configure 失败，可能是缺少依赖的库，根据提示安装上即可。比如 Ubuntu 可 以尝试用下面这条命令安装部分依赖：
      #
      # sudo apt install -y libgmp-dev libmpfr-dev libmpc-dev
      # 构建
      # configure 之后只需在 build 目录中运行 make 即可。根据计算机配置可以加上合 适的 -j 参数。
      #
      # 安装
      # 如果只是想试用一下新编译的 GCC，你并不需要安装它。假设构建目录为 ${BUILD}, 找到 ${BUILD}/gcc 目录下的 xgcc 或 xg++, 它们就是相 应的 c/c++ 编译器。可以使用下面的方法使用它：
      #
      # ${BUILD}/gcc/xgcc -B${BUILD}/gcc demo.c
      # 如果你确实想要安装， make install 就可以了。
      system "../configure", *args
      system "make", "V=1"

      # At this point `make check` could be invoked to run the testsuite. The
      # deja-gnu and autogen formulae must be installed in order to do this.
      system "make", "V=1", "install"
    end

    # Handle conflicts between GCC formulae.
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
    (testpath/"hello-c.c").write <<~EOS
      #include <stdio.h>
      int main()
      {
        puts("Hello, world!");
        return 0;
      }
    EOS
    system bin/"gcc-4.9", "-o", "hello-c", "hello-c.c"
    assert_equal "Hello, world!\n", `./hello-c`
  end
end