# https://www.cnblogs.com/sky-heaven/p/13508495.html#_label13
class CrosstoolNgAT1210Jos < Formula
  desc "Tool for building toolchains"
  homepage "http://crosstool-ng.org"
  url "http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.21.0.tar.bz2"
  sha256 "67122ba42657da258f23de4a639bc49c6ca7fe2173b5efba60ce729c6cce7a41"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "coreutils-jos" => :build
  depends_on "wget"
  depends_on "gnu-sed"
  depends_on "gawk"
  depends_on "gettext"
  depends_on "binutils-jos"
  depends_on "libelf"
  depends_on "grep" => :optional
  depends_on "make" => :optional

  # Avoid superenv to prevent https://github.com/mxcl/homebrew/pull/10552#issuecomment-9736248
  env :std

  patch :p0, :DATA

  def install
    args = ["--prefix=#{prefix}",
            "--exec-prefix=#{prefix}",
            "--with-objcopy=gobjcopy",
            "--with-objdump=gobjdump",
            "--with-readelf=greadelf",
            "--with-libtool=glibtool",
            "--with-libtoolize=glibtoolize",
            "--with-install=ginstall",
            "--with-sed=gsed",
            "--with-awk=gawk",
    ]

    args << "--with-grep=ggrep" if build.with? "grep"

    args << "--with-make=#{Formula["make"].opt_bin}/gmake" if build.with? "make"

    args << "CFLAGS=-std=gnu89"

    ENV.append "CPPFLAGS", "-I#{Formula["gettext"].opt_include}" if OS.mac?
    ENV.append "LDFLAGS", "-L#{Formula["gettext"].opt_lib} -lintl" if OS.mac?

    system "./configure", *args

    # Must be done in two steps
    system "make"
    system "make", "install"
  end

  test do
    system "#{bin}/ct-ng", "version"
  end
end

__END__
diff -r kconfig/Makefile.org kconfig/Makefile
37a38
> conf: LDFLAGS += -lintl
44c45,46
< mconf: LDFLAGS += $(NCURSES_LDFLAGS)
---
> # mconf: LDFLAGS += $(NCURSES_LDFLAGS)
> mconf: LDFLAGS += -lintl $(NCURSES_LDFLAGS)
50,51c52,55
< $(nconf_OBJ) $(nconf_DEP): CFLAGS += $(INTL_CFLAGS) -I/usr/include/ncurses
< nconf: LDFLAGS += -lmenu -lpanel -lncurses
---
> # $(nconf_OBJ) $(nconf_DEP): CFLAGS += $(INTL_CFLAGS) -I/usr/include/ncurses
> # nconf: LDFLAGS += -lmenu -lpanel -lncurses
> $(nconf_OBJ) $(nconf_DEP): CFLAGS += -I/usr/include/ncurses/ $(INTL_CFLAGS)
> nconf: LDFLAGS += -lintl -lmenu -lpanel -lncurses