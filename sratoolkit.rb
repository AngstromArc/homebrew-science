class Sratoolkit < Formula
  desc "Data tools for INSDC Sequence Read Archive"
  homepage "https://github.com/ncbi/sra-tools"
  # doi "10.1093/nar/gkq1019"
  # tag "bioinformatics"

  url "https://github.com/ncbi/sra-tools/archive/2.8.0.tar.gz"
  sha256 "df6ea1041d3fd3aab357b4c01c43d0054358a0e7f985a59511cae9c9e220b70a"
  head "https://github.com/ncbi/sra-tools.git"

  bottle do
    cellar :any
    sha256 "45c37805ea30f294fc184f2abcb1d1676499635cfc31a3ba6d03a8c6b5ad740f" => :sierra
    sha256 "59dd859f7796c64ce25c3f03285bc6f4d0120c6c228021f074854a9ce3df30fd" => :el_capitan
    sha256 "3b89566ee4e0b52d118a82efb8349b8617c54b1e7c5b538992ddd60c4bcfcd95" => :yosemite
    sha256 "b96fca67fe48bc75035455644727489cea8e7d60cc66304e69e6d5ee3c283571" => :x86_64_linux
  end

  depends_on "autoconf" => :build
  depends_on "libxml2"
  depends_on "libmagic" => :recommended
  depends_on "hdf5" => :recommended

  resource "ngs-sdk" do
    url "https://github.com/ncbi/ngs/archive/1.3.0.tar.gz"
    sha256 "803c650a6de5bb38231d9ced7587f3ab788b415cac04b0ef4152546b18713ef2"
  end

  resource "ncbi-vdb" do
    url "https://github.com/ncbi/ncbi-vdb/archive/2.8.0.tar.gz"
    sha256 "efa0b9b4987db7ef80e2c91ba35f5a0bab202e3a4824e8f34c51de303ca4eb17"
  end

  def install
    ENV.deparallelize

    # Linux fix: libbz2.a(blocksort.o): relocation R_X86_64_32 against `.rodata.str1.1'
    # https://github.com/Homebrew/homebrew-science/issues/2338
    ENV["LDFLAGS"]="" if OS.linux?

    resource("ngs-sdk").stage do
      cd "ngs-sdk" do
        system "./configure", "--prefix=#{prefix}",
                              "--build=#{Pathname.pwd}/ngs-sdk-build"
        system "make"
        system "make", "test"
        system "make", "install"
      end
    end

    (buildpath/"ncbi-vdb").install resource("ncbi-vdb")
    cd "ncbi-vdb" do
      system "./configure", "--prefix=#{prefix}",
                            "--with-ngs-sdk-prefix=#{prefix}",
                            "--build=#{buildpath}/ncbi-vdb-build"
      system "make"
      system "make", "install"
    end

    inreplace "tools/copycat/Makefile", "-smagic-static", "-smagic"

    # Fix the error: undefined reference to `SZ_encoder_enabled'
    inreplace "tools/pacbio-load/Makefile", "-shdf5 ", "-shdf5 -ssz "

    system "./configure", "--prefix=#{prefix}",
                          "--with-ngs-sdk-prefix=#{prefix}",
                          "--with-ncbi-vdb-sources=#{buildpath}/ncbi-vdb",
                          "--with-ncbi-vdb-build=#{buildpath}/ncbi-vdb-build",
                          "--build=#{buildpath}/sra-tools-build"

    system "make", "VDB_SRCDIR=#{buildpath}/ncbi-vdb"
    system "make", "VDB_SRCDIR=#{buildpath}/ncbi-vdb", "install"

    rm "#{bin}/magic"
    rm_rf "#{bin}/ncbi"
    rm_rf "#{lib}64"
    rm_rf include.to_s
  end

  test do
    # just download the first FASTQ read from an NCBI SRA run (needs internet connection)
    system bin/"fastq-dump", "-N", "1", "-X", "1", "SRR000001"
    assert_match "@SRR000001.1 EM7LVYS02FOYNU length=284", File.read("SRR000001.fastq")
  end
end
