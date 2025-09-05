class SlimContainerCli < Formula
  desc "Slim, scan, and ship Docker images with security checks and multi-arch support"
  homepage "https://github.com/raymonepping/slim-container-cli"
  url "https://github.com/raymonepping/homebrew-slim-container-cli/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "d60e5ac5bbba3a13a949a1d510ae282b6d2b0832d209e0b16de0978431db29a4" # Replace with actual SHA256
  license "MIT"
  version "1.0.0"

  depends_on "bash"
  depends_on "jq"

  def install
    bin.install "bin/slim_container" => "slim_container"
  end

  def caveats
    <<~EOS
      To get started, run:
        slim_container --help

      This CLI runs image slimming, security scanning, and pushes to Docker Hub.
      Logs and reports are stored under:
        logs/<image>/<timestamp>/
    EOS
  end

  test do
    assert_match "Usage", shell_output("#{bin}/slim_container --help")
  end
end
