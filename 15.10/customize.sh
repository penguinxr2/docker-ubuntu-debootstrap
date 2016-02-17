#!/bin/bash

set -e -o pipefail

. /etc/profile

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

if ! grep -q '^' /etc/shells; then
  printf "/bin/sh\n/bin/dash\n/bin/bash\n/bin/rbash\n" > /etc/shells
fi

# This removes packages we don't need in a Docker image:
cp -a /usr/bin/{getopt,taskset} /
apt-get -y --allow-remove-essential remove \
  systemd \
  libsystemd. \
  libdebconfclient. \
  e2fslibs \
  libdevmapper. \
  libkmod. \
  libfdisk.
mv /{getopt,taskset} /usr/bin/

# Making it one file makes it easier for the user to tell what has been from what he added.
cat /etc/apt/sources.list.d/multistrap-*.list | sort -u | sed -e '/^deb-src/s:^:# :' | sort > /etc/apt/sources.list
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
mv /usr/share/i18n/charmaps/{ISO-8859-1,UTF-8,GBK}.gz /
rm /usr/share/i18n/charmaps/*.gz
mv /{ISO-8859-1,UTF-8,GBK}.gz /usr/share/i18n/charmaps/

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
dpkg-reconfigure locales
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
