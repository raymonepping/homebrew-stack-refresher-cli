class StackRefrehsrCli < Formula
  desc "Bash-powered stack refresher with domains, docs generation, and telemetry"
  homepage "https://github.com/raymonepping/stack-refresher-cli"
  url "https://github.com/raymonepping/homebrew-stack-refresher-cli/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "c8891dbce241044fa40727cf777f62f9c86ef5de18540ffab0cbea598c96ff10"
  license "MIT"
  version "1.0.0" # keep in sync with your tag

  depends_on "bash" # requires Bash 5+
  depends_on "jq"   # used in multiple scripts

  def install
    # Install the full tree so relative paths in the scripts still work
    libexec.install Dir["*"]

    # Wrapper ensures the real script runs from libexec, so BASH_SOURCE resolves correctly
    (bin/"stack_refreshr").write <<~SH
      #!/usr/bin/env bash
      exec "#{libexec}/bin/stack_refreshr" "$@"
    SH
    (bin/"stack_refreshr").chmod 0755

    # Shell completions (project provides these)
    bash_completion.install libexec/"completions/stack_refreshr.bash" => "stack_refreshr"
    zsh_completion.install  libexec/"completions/_stack_refreshr"
    fish_completion.install libexec/"completions/stack_refreshr.fish"
  end

  def caveats
    <<~EOS
      Quickstart:
        stack_refreshr

      Useful commands:
        stack_refreshr --generate-table
        stack_refreshr --generate-readme
        stack_refreshr --refresh-docs

      Completions are installed for Bash, Zsh, and Fish.
    EOS
  end

  test do
    help = shell_output("#{bin}/stack_refreshr --help")
    assert_match "Usage: stack_refreshr", help
  end
end
