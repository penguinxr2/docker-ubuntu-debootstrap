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
cp -a /usr/bin/{getopt,taskset} /
for entry in systemd libsystemd. libdebconfclient. e2fslibs libdevmapper. libkmod. libfdisk. mount login libmount1 libblkid1 libcryptsetup4 \
             diffutils gcc-5-base insserv libapparmor1 libcap2 libcap2-bin libcomerr2 libncurses5 ncurses-bin libss2; do
  apt-get -y --allow-remove-essential remove ${entry} || true
done
mv /{getopt,taskset} /usr/bin/

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

# remove cruft
find /var -name '*-old' -type f -delete

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
