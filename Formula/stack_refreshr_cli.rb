class StackRefreshrCli < Formula
  desc "✨ Bash-powered stack refresher with domains, docs generation, and telemetry"
  homepage "https://github.com/raymonepping/homebrew-stack-refresher-cli"
  url "https://github.com/raymonepping/homebrew-stack-refresher-cli/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "4a3405f238e6d601c4cbcac86fa14090ee69b5259cf7f5d1648fd258dec22fe2"
  license "MIT"
  version "1.0.1"

  depends_on "bash"
  depends_on "jq"

  def install
    libexec.install Dir["*"]

    # Ensure all scripts in libexec/bin are executable
    Dir["#{libexec}/bin/*"].each { |f| chmod 0755, f }

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
