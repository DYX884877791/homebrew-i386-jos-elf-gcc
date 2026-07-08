class LibmpcAT08Jos < Formula
  desc "C library for high precision complex numbers"
  homepage "http://multiprecision.org"
  # Track gcc infrastructure releases.
  url "http://multiprecision.org/mpc/download/mpc-0.8.1.tar.gz"
  mirror "ftp://gcc.gnu.org/pub/gcc/infrastructure/mpc-0.8.1.tar.gz"
  sha256 "e664603757251fd8a352848276497a4c79b7f8b21fd8aedd5cc0598a38fee3e4"

  bottle do
    rebuild 1
    sha256 cellar: :any,    sierra:      "d085ef6e78f5f69dedcdcc20920b11bba3882dbc15d9720d6dd58e9ee232197a"
    sha256 cellar: :any,    el_capitan:  "99bf66edb09b4bb9f8c9595c1c578b9cdc6d5db7b652fe7d2d2fe85128470e3e"
    sha256 cellar: :any,    yosemite:    "64bffe51a7eb97a8053cf6a9cf8e13c4f337c2ed85bc7aa8bf08e67c5dc88906"
  end

  keg_only :versioned_formula

  depends_on "gmp@4-jos"
  depends_on "mpfr@2-jos"

  def install
    args = [
      "--prefix=#{prefix}",
      "--disable-dependency-tracking",
      "--with-gmp=#{Formula["gmp@4-jos"].opt_prefix}",
      "--with-mpfr=#{Formula["mpfr@2-jos"].opt_prefix}",
    ]

    system "./configure", *args
    system "make"
    system "make", "check"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <mpc.h>

      int main()
      {
        mpc_t x;
        mpc_init2 (x, 256);
        mpc_clear (x);
        return 0;
      }
    EOS
    gmp = Formula["gmp@4"]
    mpfr = Formula["mpfr@2"]
    system ENV.cc, "test.c",
      "-I#{gmp.include}", "-L#{gmp.lib}", "-lgmp",
      "-I#{mpfr.include}", "-L#{mpfr.lib}", "-lmpfr",
      "-I#{include}", "-L#{lib}", "-lmpc",
      "-o", "test"
    system "./test"
  end
end