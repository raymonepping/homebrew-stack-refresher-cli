class StackRefreshr < Formula
  desc "Bash-powered stack refresher with domains, docs generation, and telemetry"
  homepage "https://github.com/raymonepping/stack_refresher" # update if different
  url "https://github.com/raymonepping/stack_refresher/archive/refs/tags/v1.2.1.tar.gz" # update tag
  sha256 "REPLACE_WITH_REAL_SHA256" # update
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
