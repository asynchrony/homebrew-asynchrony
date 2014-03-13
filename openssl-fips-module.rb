require 'formula'

class OpensslFipsModule < Formula
  homepage 'http://openssl.org'
  url 'https://www.openssl.org/source/openssl-fips-2.0.5.tar.gz'
  sha256 '9efa2948a812c6529c4e1f70d9b1e76a360b7d8e18c318e3755f360fe0e9237a'

  bottle do
    root_url 'https://github.com/asynchrony/homebrew-asynchrony/releases/download/bottles'
    sha1 "f811e0dd97a6f95757649adccd2b190659055c5f" => :mavericks
  end

  keg_only 'This is a dependency for OpenSSL, which is itself keg_only'

  def install
    args = %W[./Configure
               --prefix=#{prefix}
             ]

    if MacOS.prefer_64_bit?
      args << "darwin64-x86_64-cc" << "enable-ec_nistp_64_gcc_128"

      # -O3 is used under stdenv, which results in test failures when using clang
      inreplace 'Configure',
        %{"darwin64-x86_64-cc","cc:-arch x86_64 -O3},
        %{"darwin64-x86_64-cc","cc:-arch x86_64 -Os}
    else
      args << "darwin-i386-cc"
    end

    system "perl", *args

    ENV.deparallelize
    system "make"
    system "make", "install"
  end
end
