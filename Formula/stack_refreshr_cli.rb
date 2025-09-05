class StackRefreshrCli < Formula
  desc "✨ Bash-powered stack refresher with domains, docs generation, and telemetry"
  homepage "https://github.com/raymonepping/homebrew-stack-refresher-cli"
  url "https://github.com/raymonepping/homebrew-stack-refresher-cli/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "c8891dbce241044fa40727cf777f62f9c86ef5de18540ffab0cbea598c96ff10"
  license "MIT"
  version "1.0.0"

  depends_on "bash"
  depends_on "jq"

  def install
    libexec.install Dir["*"]

    (bin/"stack_refreshr").write <<~SH
      #!/usr/bin/env bash
      exec "#{libexec}/bin/stack_refreshr" "$@"
    SH
    (bin/"stack_refreshr").chmod 0755

    bash_completion.install libexec/"completions/stack_refreshr.bash" => "stack_refreshr"
    zsh_completion.install  libexec/"completions/_stack_refreshr"
    fish_completion.install libexec/"completions/stack_refreshr.fish"
  end

  def caveats
    <<~EOS
      🚀 Quickstart:
        stack_refreshr

      🛠️ Useful commands:
        stack_refreshr --generate-table
        stack_refreshr --generate-readme
        stack_refreshr --refresh-docs
    EOS
  end

  test do
    assert_match "Usage: stack_refreshr", shell_output("#{bin}/stack_refreshr --help")
  end
end
