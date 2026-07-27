class Dev86Jos < Formula
  desc "C compiler, assembler and linker environment for the production of 8086 executables"
  homepage "v3.sk/~lkundrak/dev86/"
  license "GPL-2.0"
  # 使用 Git 仓库，指定分支（默认 main/master）
  head "https://github.com/lkundrak/dev86.git", branch: "master"
  # repackage from
  # https://codeload.github.com/lkundrak/dev86/tar.gz/refs/tags/v0.16.21
  url "https://raw.githubusercontent.com/DYX884877791/homebrew-i386-jos-elf-gcc/refs/heads/master/Tarballs/dev86-0.16.21.tar.bz2"
  sha256 "53f5ef56b280dd798ee4e660f3795a196434a2a23cb3b78ac5120fd1bfaf5407"

  depends_on "gcc@4.6" => :build

  patch :p1, :DATA
  
  def install
    # # 将编译器指向 Homebrew 安装的具体 GCC 版本
    ENV["CC"] = "gcc-4.6"
    ENV["cc"] = "gcc-4.6"
    system "make"
  end
end

__END__
# https://523096.bugs.gentoo.org/attachment.cgi?id=384988
diff -Nuar dev86-0.16.21.orig/unproto/tok_io.c dev86-0.16.21/unproto/tok_io.c
--- dev86-0.16.21.orig/unproto/tok_io.c	1997-08-09 16:49:58.000000000 +0200
+++ dev86-0.16.21/unproto/tok_io.c	2014-09-18 09:10:06.244984172 +0200
@@ -189,7 +189,7 @@
 
 /* do_control - parse control line */
 
-static int do_control()
+static void do_control()
 {
     struct token *t;
     int     line;