class Swiftcontext < Formula
  desc "Generate AI coding-agent context from Swift projects"
  homepage "https://github.com/GranitGjevukaj/swift-context-cli"
  head "https://github.com/GranitGjevukaj/swift-context-cli.git", branch: "main"
  license "MIT"

  depends_on xcode: ["16.0", :build]

  resource "swift-argument-parser" do
    url "https://github.com/apple/swift-argument-parser/archive/refs/tags/1.7.0.tar.gz"
    sha256 "84e685f0ca4d069a60193c9e477b6ec5a44016dc789db01e0b17c38b400a922e"
  end

  resource "swift-syntax" do
    url "https://github.com/swiftlang/swift-syntax/archive/refs/tags/600.0.1.tar.gz"
    sha256 "c2a7c0b7e53d68f9043c4cfe4adbee3cf27acb1fa81c89456d974209c7a67f94"
  end

  resource "XcodeProj" do
    url "https://github.com/tuist/XcodeProj/archive/refs/tags/8.27.7.tar.gz"
    sha256 "080f11b8f0f1ac02ec96a2b292cc42a8c6da04885b1e4c7137ae00d18a597c46"
  end

  resource "AEXML" do
    url "https://github.com/tadija/AEXML/archive/refs/tags/4.7.0.tar.gz"
    sha256 "5bd753bc135615554a966efb2f03362a058b2f334dbf1881c75cd38c82432d27"
  end

  resource "PathKit" do
    url "https://github.com/kylef/PathKit/archive/refs/tags/1.0.1.tar.gz"
    sha256 "fcda78cdf12c1c6430c67273333e060a9195951254230e524df77841a0235dae"
  end

  resource "Spectre" do
    url "https://github.com/kylef/Spectre/archive/refs/tags/0.10.1.tar.gz"
    sha256 "6850c20f828fcfb040e99a011fedb56f7811a5afb6acbdfa8e7fe15e78b9370e"
  end

  def install
    vendor = buildpath/"vendor"
    vendor.mkpath

    resource("swift-argument-parser").stage(vendor/"swift-argument-parser")
    resource("swift-syntax").stage(vendor/"swift-syntax")
    resource("XcodeProj").stage(vendor/"XcodeProj")
    resource("AEXML").stage(vendor/"AEXML")
    resource("PathKit").stage(vendor/"PathKit")
    resource("Spectre").stage(vendor/"Spectre")

    inreplace "Package.swift",
              '.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")',
              '.package(path: "vendor/swift-argument-parser")'
    inreplace "Package.swift",
              '.package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")',
              '.package(path: "vendor/swift-syntax")'
    inreplace "Package.swift",
              '.package(url: "https://github.com/tuist/XcodeProj.git", from: "8.24.0")',
              '.package(path: "vendor/XcodeProj")'

    inreplace vendor/"XcodeProj"/"Package.swift",
              '.package(url: "https://github.com/tadija/AEXML.git", .upToNextMinor(from: "4.7.0"))',
              '.package(path: "../AEXML")'
    inreplace vendor/"XcodeProj"/"Package.swift",
              '.package(url: "https://github.com/kylef/PathKit.git", .upToNextMinor(from: "1.0.1"))',
              '.package(path: "../PathKit")'
    inreplace vendor/"PathKit"/"Package.swift",
              '.package(url:"https://github.com/kylef/Spectre.git", .upToNextMinor(from:"0.10.0"))',
              '.package(path: "../Spectre")'

    rm_f "Package.resolved"

    system "swift", "build", "-c", "release", "--disable-sandbox", "--product", "swiftcontext"

    bin.install ".build/release/swiftcontext"
  end

  test do
    assert_match "Generate AI agent context from Swift projects",
                 shell_output("#{bin}/swiftcontext --help")
  end
end
