class Dev86Jos < Formula
  desc "C compiler, assembler and linker environment for the production of 8086 executables"
  homepage "v3.sk/~lkundrak/dev86/"
  license "GPL-2.0"
  # 使用 Git 仓库，指定分支（默认 main/master）
  head "https://github.com/lkundrak/dev86.git", branch: "master"

  depends_on "gcc@4.6" => :build

  def install
    # 将编译器指向 Homebrew 安装的具体 GCC 版本
    ENV["CC"] = "gcc-4.6"
    system "make"
    system "make", "install"
  end
end