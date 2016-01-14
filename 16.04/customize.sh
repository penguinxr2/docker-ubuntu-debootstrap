#!/bin/bash

set -e -o pipefail

. /etc/profile

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

# This removes packages we don't need in a Docker image:
apt-get -y --allow-remove-essential remove \
  systemd \
  libsystemd. \
  libdebconfclient. \
  e2fslibs \
  libdevmapper. \
  libkmod. \
  libfdisk.

# Making it one file makes it easier for the user to tell what has been from what he added.
cat /etc/apt/sources.list.d/multistrap-*.list | sort -u | sed -e '/^deb-src/s:^:# :' | sort > /etc/apt/sources.list
rm /etc/apt/sources.list.d/multistrap-*.list

# Creates /etc/default/locale
update-locale LANG=C.UTF-8

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
