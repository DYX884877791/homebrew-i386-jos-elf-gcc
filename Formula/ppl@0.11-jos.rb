class PplAT011Jos < Formula
  desc "Numerical abstractions for analysis, verification"
  homepage "http://bugseng.com/products/ppl/"
  url "https://gcc.gnu.org/pub/gcc/infrastructure/ppl-0.11.tar.gz"
  sha256 "3453064ac192e095598576c5b59ecd81a26b268c597c53df05f18921a4f21c77"
  revision 1

  bottle do
    rebuild 1
    sha256 sierra:      "28b29ead285c5cab1a31957c685f81fd5d429fdd2d9f1c4209404f5c3dd34ce0"
    sha256 el_capitan:  "bd04cf76f1bf509a58ecc7f23032e75a943047889094363dab4a957dd8314281"
    sha256 yosemite:    "1ce289ae5568772a3f3153e2bc74dc29ab2e8f810ecca5c60813df45c66ed81e"
  end

  keg_only :versioned_formula

  depends_on "gmp@4-jos"

  patch :DATA

  # 第二个 patch
  patch :DATA

  # https://www.cs.unipr.it/mantis/view.php?id=596
  # https://github.com/Homebrew/homebrew/issues/27431
  # Using different patch from upstream bug report to avoid autoreconf.
  patch do
    url "https://gist.githubusercontent.com/manphiz/9507743/raw/45081e12c2f1faf81e8536f365af05173c6dab5c/patch-ppl-flexible-array-clang_v2.patch"
    sha256 "db8ced5366ec4c3efb6fd20d3b4e440de3f8b9ec1d930a33b6a23d006dc25944"
  end

  def install
    system "./configure", "--prefix=#{prefix}",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--disable-ppl_lpsol",
                          "--disable-ppl_lcdd",
                          "--disable-ppl_pips",
                          "--with-gmp-prefix=#{Formula["gmp@4-jos"].opt_prefix}"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <ppl_c.h>
      #ifndef PPL_VERSION_MAJOR
      #error "No PPL header"
      #endif
      int main() {
        ppl_initialize();
        return ppl_finalize();
      }
    EOS
    gmp = Formula["gmp@4"]
    system ENV.cc, "test.c", "-o", "test",
                   "-lgmp", "-I#{gmp.include}", "-L#{gmp.lib}",
                   "-lppl_c", "-lppl", "-I#{include}", "-L#{lib}"
    system "./test"
  end
end

__END__
--- ppl-0.11.orig/src/OR_Matrix.inlines.hh	2026-07-09 10:00:00.000000000 +0800
+++ ppl-0.11/src/OR_Matrix.inlines.hh	    2026-07-09 10:00:00.000000000 +0800
@@ -97,9 +97,9 @@

 template <typename T>
 template <typename U>
-inline OR_Matrix<T>::Pseudo_Row<U>&
-OR_Matrix<T>::Pseudo_Row<U>::operator=(const Pseudo_Row& y) {
+inline typename OR_Matrix<T>::template Pseudo_Row<U>&
+OR_Matrix<T>::Pseudo_Row<U>::operator=(const Pseudo_Row<U>& y) {
   first = y.first;
 #if PPL_OR_MATRIX_EXTRA_DEBUG
   size_ = y.size_;
 #endif

__END__
--- ppl-0.11.orig/src/Determinate.inlines.hh	2026-07-09 10:00:00.000000000 +0800
+++ ppl-0.11/src/Determinate.inlines.hh	        2026-07-09 10:00:00.000000000 +0800
@@ -285,10 +285,10 @@

 template <typename PSET>
 template <typename Binary_Operator_Assign>
 inline
-Determinate<PSET>::Binary_Operator_Assign_Lifter<Binary_Operator_Assign>
+typename Determinate<PSET>::template Binary_Operator_Assign_Lifter<Binary_Operator_Assign>
 Determinate<PSET>::lift_op_assign(Binary_Operator_Assign op_assign) {
   return Binary_Operator_Assign_Lifter<Binary_Operator_Assign>(op_assign);
 }

 } // namespace Parma_Polyhedra_Library