class Latinum < Formula
  desc "Formally-verified Solana smart contracts in Lean 4 (Lean to SBF compiler)"
  homepage "https://github.com/dennj/solana-lean"
  url "https://github.com/MohammedImaad/latinum/releases/download/v0.1/latinum-lean-arm64-macos.tar.gz"
  sha256 "75d7ed95aae972634ceeb2e587fa93033f70354999ab2ecc26d5ac3ea54a9c0e"
  version "0.1"
  license "Apache-2.0"

  # Prebuilt binary: Apple Silicon, macOS 13+ only.
  depends_on arch: :arm64
  depends_on macos: :ventura
  depends_on "gmp"
  depends_on "libuv"
  depends_on "openssl@3"

  # Solana SBF linker — pulled from anza-xyz so we don't host its 932 MB ourselves.
  resource "platform-tools" do
    url "https://github.com/anza-xyz/platform-tools/releases/download/v1.41/platform-tools-osx-aarch64.tar.bz2"
    sha256 "52e66ad46156933b5811b817c8d3b9bfce7ad388d35119b117dbfbcdc747a566"
  end

  def install
    # Toolchain lives in libexec so the binaries' relative @rpath (../lib) resolves.
    libexec.install Dir["*"]

    # Bundle the SBF linker alongside it — nothing to download on first build.
    resource("platform-tools").stage do
      (libexec/"platform-tools").install Dir["*"]
    end

    # PATH wrappers that point the SBF backend at the bundled linker. The env var
    # is inherited by lake's child lean/leanc processes, so the whole build sees it.
    %w[lean lake leanc leanmake leanir leanchecker leantar cadical].each do |tool|
      (bin/tool).write <<~SH
        #!/bin/bash
        export LEAN_SOLANA_TOOLS="#{libexec}/platform-tools"
        exec "#{libexec}/bin/#{tool}" "$@"
      SH
    end
  end

  def caveats
    <<~EOS
      Latinum installs the Lean -> Solana SBF toolchain (lean, lake).

      To deploy a contract you also need the Solana CLI and a funded wallet:
        sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"

      Example project: the Colosseum/ directory in this repo.
    EOS
  end

  test do
    assert_match "Lean", shell_output("#{bin}/lean --version")
  end
end
