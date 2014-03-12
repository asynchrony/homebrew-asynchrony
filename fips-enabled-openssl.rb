require 'formula'

class FipsEnabledOpenssl < Formula
  homepage 'http://openssl.org'
  url 'https://www.openssl.org/source/openssl-1.0.1f.tar.gz'
  sha256 '6cc2a80b17d64de6b7bac985745fdaba971d54ffd7d38d3556f998d7c0c9cb5a'

  keg_only :provided_by_osx,
    "The OpenSSL provided by OS X is too old for some software, and does not support FIPS mode."

  depends_on 'openssl-fips-module'

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

      setup_makedepend_shim
    else
      args << "darwin-i386-cc"
    end

    system "perl", *args

    ENV.deparallelize
    system "make", "depend" if MacOS.prefer_64_bit?
    system "make"
    system "make", "install", "MANDIR=#{man}", "MANSUFFIX=ssl"
  end

  def setup_makedepend_shim
    path = buildpath/"brew/makedepend"
    path.write <<-EOS.undent
      #!/bin/sh
      exec "#{ENV.cc}" -M "$@"
      EOS
    path.chmod 0755
    ENV.prepend_path 'PATH', path.parent
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
