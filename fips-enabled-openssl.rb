require 'formula'

class FipsEnabledOpenssl < Formula
  homepage 'http://openssl.org'
  url 'https://www.openssl.org/source/openssl-1.0.1g.tar.gz'
  sha256 '53cb818c3b90e507a8348f4f5eaedb05d8bfe5358aabb508b7263cc670c3e028'

  bottle do
    root_url 'https://github.com/asynchrony/homebrew-asynchrony/releases/download/bottles'
    sha1 "e4fe6a4d23721a0709149713d9d19c0ea44ae21b" => :mavericks
  end

  keg_only :provided_by_osx,
    "The OpenSSL provided by OS X is too old for some software, and does not support FIPS mode."

  depends_on 'openssl-fips-module' => :build

  def patches
    DATA
  end

  def install
    fips = Formula['openssl-fips-module']
    args = %W[./Configure
               --prefix=#{prefix}
               --openssldir=#{openssldir}
               zlib-dynamic
               shared
               enable-cms
               fips
               --with-fipsdir=#{fips.prefix}
             ]

    if MacOS.prefer_64_bit?
      args << "darwin64-x86_64-cc" << "enable-ec_nistp_64_gcc_128"

      # -O3 is used under stdenv, which results in test failures when using clang
      inreplace 'Configure',
        %{"darwin64-x86_64-cc","cc:-arch x86_64 -O3},
        %{"darwin64-x86_64-cc","cc:-arch x86_64 -Os}

      inreplace "util/domd", %{expr "$MAKEDEPEND" : '.*gcc$' > /dev/null}, %{true}
      inreplace "util/domd", %{${MAKEDEPEND}}, ENV.cc
    else
      args << "darwin-i386-cc"
    end

    system "perl", *args

    ENV.deparallelize
    system "make", "depend" if MacOS.prefer_64_bit?
    system "make"
    system "make", "install", "MANDIR=#{man}", "MANSUFFIX=ssl"
  end

  def openssldir
    etc/"fips-enabled-openssl"
  end

  def cert_pem
    openssldir/"cert.pem"
  end

  def osx_cert_pem
    openssldir/"osx_cert.pem"
  end

  def write_pem_file
    system "security find-certificate -a -p /Library/Keychains/System.keychain > '#{osx_cert_pem}.tmp'"
    system "security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain >> '#{osx_cert_pem}.tmp'"
    system "mv", "-f", "#{osx_cert_pem}.tmp", osx_cert_pem
  end

  def post_install
    openssldir.mkpath

    if cert_pem.exist?
      write_pem_file
    else
      cert_pem.unlink if cert_pem.symlink?
      write_pem_file
      openssldir.install_symlink 'osx_cert.pem' => 'cert.pem'
    end
  end
end

__END__
diff --git a/openssl.cnf.old b/openssl.cnf
index 18760c6..8f5a596 100644
--- a/apps/openssl.cnf.old
+++ b/apps/openssl.cnf
@@ -8,9 +8,13 @@
 HOME			= .
 RANDFILE		= $ENV::HOME/.rnd

+openssl_conf = openssl_init
+
+[ openssl_init ]
 # Extra OBJECT IDENTIFIER info:
 #oid_file		= $ENV::HOME/.oid
 oid_section		= new_oids
+alg_section = algs

 # To use this configuration file with the "-extfile" option of the
 # "openssl x509" utility, name here the section containing the
@@ -32,6 +36,9 @@ tsa_policy1 = 1.2.3.4.1
 tsa_policy2 = 1.2.3.4.5.6
 tsa_policy3 = 1.2.3.4.5.7

+[ algs ]
+fips_mode = yes
+
 ####################################################################
 [ ca ]
 default_ca	= CA_default		# The default ca section
