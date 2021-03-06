class Haxe < Formula
  desc "Multi-platform programming language"
  homepage "https://haxe.org/"
  license all_of: ["GPL-2.0-or-later", "MIT"]
  head "https://github.com/HaxeFoundation/haxe.git", branch: "development"

  stable do
    url "https://github.com/HaxeFoundation/haxe.git",
        tag:      "4.2.2",
        revision: "a2f4ba95400edf10195ce2a1c87c56dc0d67111b"

    # Remove when campl5 dependency is bumped to 8.00 in a release
    patch do
      url "https://github.com/HaxeFoundation/haxe/commit/db72b31390c51c1627cf5658ca256aace41a81b0.patch?full_index=1"
      sha256 "95a22f2cc227c4e6d066e60eb88b2a71ad6c278d6f38656fbd87ee905411918a"
    end
  end

  livecheck do
    url :stable
    strategy :github_latest
  end

  bottle do
    sha256 cellar: :any, arm64_big_sur: "74bc5a229f86d345f643054840ca1cbf395c9f5c937acf66f67d445ace61b715"
    sha256 cellar: :any, big_sur:       "c7ddddb58e535f31e496ffdc78142aa55f1ae30982bbfbdd626914b91fe1bbe0"
    sha256 cellar: :any, catalina:      "06f2c63317134f8554cf2a7b1c45f774ac341b1a8155fe4fc05b2fc444d4c398"
    sha256 cellar: :any, mojave:        "a8eca0f220ec10a993c4208508993567c6e9e509611418d5dbd70e00570bc38d"
  end

  depends_on "cmake" => :build
  depends_on "ocaml" => :build
  depends_on "opam" => :build
  depends_on "pkg-config" => :build
  depends_on "mbedtls"
  depends_on "neko"
  depends_on "pcre"

  uses_from_macos "m4" => :build
  uses_from_macos "perl" => :build
  uses_from_macos "unzip" => :build

  resource "String::ShellQuote" do
    url "https://cpan.metacpan.org/authors/id/R/RO/ROSCH/String-ShellQuote-1.04.tar.gz"
    sha256 "e606365038ce20d646d255c805effdd32f86475f18d43ca75455b00e4d86dd35"
  end

  resource "IPC::System::Simple" do
    url "https://cpan.metacpan.org/authors/id/J/JK/JKEENAN/IPC-System-Simple-1.30.tar.gz"
    sha256 "22e6f5222b505ee513058fdca35ab7a1eab80539b98e5ca4a923a70a8ae9ba9e"
  end

  def install
    # Build requires targets to be built in specific order
    ENV.deparallelize

    ENV.prepend_create_path "PERL5LIB", libexec/"lib/perl5"
    resources.each do |r|
      r.stage do
        system "perl", "Makefile.PL", "INSTALL_BASE=#{libexec}"
        system "make", "install"
      end
    end

    Dir.mktmpdir("opamroot") do |opamroot|
      ENV["OPAMROOT"] = opamroot
      ENV["OPAMYES"] = "1"
      ENV["ADD_REVISION"] = "1" if build.head?
      system "opam", "init", "--no-setup", "--disable-sandboxing"
      system "opam", "config", "exec", "--",
             "opam", "pin", "add", "haxe", buildpath, "--no-action"
      system "opam", "config", "exec", "--",
             "opam", "install", "haxe", "--deps-only", "--working-dir"
      system "opam", "config", "exec", "--",
             "make"
    end

    # Rebuild haxelib as a valid binary
    cd "extra/haxelib_src" do
      system "cmake", ".", *std_cmake_args
      system "make"
    end
    rm "haxelib"
    cp "extra/haxelib_src/haxelib", "haxelib"

    bin.mkpath
    system "make", "install", "INSTALL_BIN_DIR=#{bin}",
           "INSTALL_LIB_DIR=#{lib}/haxe", "INSTALL_STD_DIR=#{lib}/haxe/std"
  end

  def caveats
    <<~EOS
      Add the following line to your .bashrc or equivalent:
        export HAXE_STD_PATH="#{HOMEBREW_PREFIX}/lib/haxe/std"
    EOS
  end

  test do
    ENV["HAXE_STD_PATH"] = "#{HOMEBREW_PREFIX}/lib/haxe/std"
    system "#{bin}/haxe", "-v", "Std"
    system "#{bin}/haxelib", "version"

    (testpath/"HelloWorld.hx").write <<~EOS
      import js.html.Console;

      class HelloWorld {
          static function main() Console.log("Hello world!");
      }
    EOS
    system "#{bin}/haxe", "-js", "out.js", "-main", "HelloWorld"
    _, stderr, = Open3.capture3("osascript -so -lJavaScript out.js")
    assert_match "Hello world!", stderr.strip
  end
end
