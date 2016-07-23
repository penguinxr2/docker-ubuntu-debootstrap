#!/bin/bash

set -e -o pipefail

if [[ -s /etc/profile ]]; then
  . /etc/profile
fi

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

dpkg --configure -a

if ! grep -q '^' /etc/shells; then
  printf "/bin/sh\n/bin/dash\n/bin/bash\n/bin/rbash\n" > /etc/shells
fi

# This removes packages we don't need in a Docker image:
cp -a /usr/bin/{getopt,script,taskset} /
for entry in systemd libsystemd. libdebconfclient. e2fslibs libdevmapper. libkmod. libfdisk. mount login libmount1 libblkid1 libcryptsetup4 \
             diffutils gcc-5-base insserv libapparmor1 libcap2 libcap2-bin libcomerr2 libncurses5 ncurses-bin libss2; do
  apt-get -y --allow-remove-essential remove ${entry} || true
done
mv /{getopt,script,taskset} /usr/bin/

printf "Package: ca-certificates\nStatus: install ok installed\nVersion: $(date --utc +'%Y%m%d')\nArchitecture: all\nDescription: Common CA certificates\nMaintainer: Nobody <noreply@blitznote.de>\n\n" >> /var/lib/dpkg/status
printf "/etc/ssl/certs/ca-certificates.crt\n" >/var/lib/dpkg/info/ca-certificates.list
md5sum etc/ssl/certs/ca-certificates.crt >/var/lib/dpkg/info/ca-certificates.md5sums

if [[ ! -x /usr/bin/gpg ]]; then
  update-alternatives --install /usr/bin/gpg gnupg /usr/bin/gpg2 100
fi
if [[ ! -x /usr/bin/gpgv ]]; then
  update-alternatives --install /usr/bin/gpgv gpgv /usr/bin/gpgv2 100
fi

# Making it one file makes it easier for the user to tell what has been from what he added.
cat /etc/apt/sources.list.d/multistrap-*.list \
| sort -u \
| sed -e '/^deb-src/s:^:# :' -e '/blitznote/s:]: trusted=yes]:g' \
| sort >/etc/apt/sources.list
rm /etc/apt/sources.list.d/multistrap-*.list
printf 'Package: apt-transport-https curl golang-1.6* libcurl3 libssl1.0.0 libtorrent19 openssl rtorrent\nPin: origin "s.blitznote.com"\nPin-Priority: 509\n' > /etc/apt/preferences.d/from-blitznote

# Add everything we remove below to its own neat tarball for recovery
tar --use-compress-program=plzip \
  -cf /extra.tar.lz \
  /usr/share/i18n/charmaps \
  /usr/share/i18n/locales \
  /usr/share/locale \
  /usr/share/zoneinfo \
  /usr/share/doc /usr/share/man

# remove uncommon locales and charmaps
mv /usr/share/i18n/charmaps/{ISO-8859-1,UTF-8,GBK,ANSI_X3.110-1983,ANSI_X3.4-1968}.gz /
rm /usr/share/i18n/charmaps/*.gz
mv /{ISO-8859-1,UTF-8,GBK,ANSI_X3.110-1983,ANSI_X3.4-1968}.gz /usr/share/i18n/charmaps/

mv /usr/share/i18n/locales/{i18n,iso14651_t1,iso14651_t1_common,POSIX,ISO,translit_*,en_GB,en_US} /
rm /usr/share/i18n/locales/*
rm /translit_{hangul,cjk_variants}
mv /{i18n,iso14651_t1,iso14651_t1_common,POSIX,ISO,translit_*,en_GB,en_US} /usr/share/i18n/locales/

find /usr/share/locale/ -maxdepth 1 -mindepth 1 -type d -exec rm -r '{}' \;

mv /usr/share/zoneinfo/{Etc,Factory,localtime,posixrules,Universal,UTC,Zulu} /tmp/
rm -r /usr/share/zoneinfo/*
mv /tmp/{Etc,Factory,localtime,posixrules,Universal,UTC,Zulu} /usr/share/zoneinfo/

# remove doc- and manpages -- this is no interactive system
rm -r /usr/share/doc /usr/share/man

# Creates /etc/default/locale
printf "ISO.UTF-8 UTF-8\n" >> /usr/share/i18n/SUPPORTED
locale-gen "ISO.UTF-8"
update-locale --no-checks LANG=ISO.UTF-8

# add keys of release maintainers whose repositories we already use here
cat <<EOF | apt-key add
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v2

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
=qUpq
-----END PGP PUBLIC KEY BLOCK-----
EOF
wait
killall gpg-agent || true

# remove cruft
find /var -name '*-old' -type f -delete
find /etc -name '*~' -type f -delete

# some swag
cat >>/etc/bash.bashrc <<EOF

if [[ \${EUID} == 0 ]]; then
    PS1='\[\033[01;31m\]\h\[\033[01;96m\] \W \$\[\033[00m\] '
else
    PS1='\[\033[01;32m\]\u@\h\[\033[01;96m\] \w \$\[\033[00m\] '
fi

if [ -r /etc/default/locale ]; then
    . /etc/default/locale
    export LANG
fi

alias dir="ls -alh --color"
EOF

sed -i -e "/color_prompt.*then/,/fi/{N;d}" /root/.bashrc

# tune apt and dpkg
printf 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup

cat >/etc/apt/apt.conf.d/docker-tuning <<EOF
Acquire::Languages "none";
Acquire::GzipIndexes "true";
APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };

Dir::Cache::pkgcache "";
Dir::Cache::srcpkgcache "";'
DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };
EOF

echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

if [[ ! -s /var/log/installer/initial-status.gz ]]; then
  mkdir -p /var/log/installer
  dpkg-query --show --showformat="Package: \${Package}\n" \
  | gzip -9 >/var/log/installer/initial-status.gz
fi
