class Dev86Jos < Formula
  desc "C compiler, assembler and linker environment for the production of 8086 executables"
  homepage "v3.sk/~lkundrak/dev86/"
  license "GPL-2.0"
  # 使用 Git 仓库，指定分支（默认 main/master）
  head "https://github.com/lkundrak/dev86.git", branch: "master"
  url "https://github.com/DYX884877791/homebrew-i386-jos-elf-gcc/blob/master/Tarballs/dev86-0.16.21.tar.bz2"
  sha256 "867a745cbe48b5ef56be58800206e8c562ff3b67cd3e4dc6a9fac74c10b4c8e0"

  depends_on "gcc@4.6" => :build

  def install
    # 将编译器指向 Homebrew 安装的具体 GCC 版本
    ENV["CC"] = "gcc-4.6"
    system "make"
    system "make", "install"
  end
end