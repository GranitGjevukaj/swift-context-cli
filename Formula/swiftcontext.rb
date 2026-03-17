class Swiftcontext < Formula
  desc "Generate AI coding-agent context from Swift projects"
  homepage "https://github.com/granitgjevukaj/swift-context-cli"
  version "0.5.0"
  url "https://github.com/granitgjevukaj/swift-context-cli/releases/download/v#{version}/swiftcontext-macos-universal.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  def install
    bin.install "swiftcontext"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/swiftcontext --version")
  end
end
