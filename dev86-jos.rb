class Dev86Jos < Formula
  desc "C compiler, assembler and linker environment for the production of 8086 executables"
  homepage "v3.sk/~lkundrak/dev86/"
  license "GPL-2.0"
  # 使用 Git 仓库，指定分支（默认 main/master）
  head "https://github.com/elks-86/elks.git", branch: "master"

  def install
    system "make"
    system "make", "install"
  end
end