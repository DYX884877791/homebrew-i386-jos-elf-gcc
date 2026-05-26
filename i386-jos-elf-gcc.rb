class I386JosElfGcc < Formula
  homepage "http://pdos.csail.mit.edu/6.828/2014/tools.html"
  url "http://ftpmirror.gnu.org/gcc/gcc-4.9.2/gcc-4.9.2.tar.bz2"
  sha256 "2020c98295856aa13fda0f2f3a4794490757fc24bcca918d52cc8b4917b972dd"

  depends_on 'gmp'
  depends_on 'libmpc'
  depends_on 'mpfr'
  depends_on 'i386-jos-elf-binutils'

  patch :DATA

  def install
    mkdir 'build' do
      system "../configure", "--prefix=#{prefix}",
                             "--target=i386-jos-elf",
                             "--disable-werror",
                             "--disable-libssp",
                             "--disable-libmudflap",
                             "--disable-nls",
                             "--with-newlib",
                             "--with-as=#{Formula["i386-jos-elf-binutils"].opt_prefix}/bin/i386-jos-elf-as",
                             "--with-ld=#{Formula["i386-jos-elf-binutils"].opt_prefix}/bin/i386-jos-elf-ld",
                             "--without-headers",
                             "--enable-languages=c,c++"
      system "make", "all-gcc"
      system "make", "install-gcc"
      system "make", "all-target-libgcc"
      system "make", "install-target-libgcc"

      # GCC needs this folder in #{prefix} in order to see the binutils.
      # It doesn't look for i386-jos-elf-as on $PREFIX/bin. Rather, it looks
      # for as on $PREFIX/$TARGET/bin/ ($PREFIX/i386-jos-elf/bin/as).
      binutils = Formula["i386-jos-elf-binutils"].prefix
      ln_sf "#{binutils}/i386-jos-elf", "#{prefix}/i386-jos-elf"
    end
  end

  test do
    system "#{bin}/i386-jos-elf-gcc -v"
  end
end

__END__
diff --git a/gcc/gengtype.c b/gcc/gengtype.c
index abf17f8..550d3bb 100644
--- a/gcc/gengtype.c
+++ b/gcc/gengtype.c
@@ -3594,13 +3594,13 @@ write_field_root (outf_p f, pair_p v, type_p type, const char *name,
                  int has_length, struct fileloc *line, const char *if_marked,
                  bool emit_pch, type_p field_type, const char *field_name)
 {
+  struct pair newv;
   /* If the field reference is relative to V, rather than to some
      subcomponent of V, we can mark any subarrays with a single stride.
      We're effectively treating the field as a global variable in its
      own right.  */
   if (v && type == v->type)
     {
-      struct pair newv;
 
       newv = *v;
       newv.type = field_type;
