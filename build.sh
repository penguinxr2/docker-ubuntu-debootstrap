#!/bin/bash

set -e -o pipefail

curl -sSfLR --create-dirs \
  -z contrib/etc/ssl/certs/ca-certificates.crt \
  -o contrib/etc/ssl/certs/ca-certificates.crt \
  https://github.com/wmark/docker-curl/raw/master/ca-certificates.crt

: ${ARCH:=amd64}
: ${DOCKER_PREFIX:=""}

mktarball() {
  local ARCH=$1
  local NUM=$2
  local WORKDIR=$(mktemp -d -t $ARCH-$NUM.XXXXXX)
  local DOCKERTAG="${DOCKER_PREFIX}debootstrap-${ARCH}:${NUM}"

  cp -a $NUM/multistrap.conf $WORKDIR/
  sed -i \
    -e "s@/tmp/amd64@${WORKDIR}@g" \
    -e "/^arch=/c\arch=${ARCH}" \
    -e "/s.blitznote.com/s:amd64:${ARCH}:" \
    $WORKDIR/multistrap.conf
  multistrap -f $WORKDIR/multistrap.conf || true
  rm $WORKDIR/multistrap.conf

  mkdir -p $WORKDIR/target-dir/etc/ssl/certs
  cp -a contrib/etc/ssl/certs/ca-certificates.crt $_
  cp contrib/usr/bin/get-gpg-key $WORKDIR/target-dir/usr/bin/
  cp -a contrib/share/i18n/locales/* $WORKDIR/target-dir/usr/share/i18n/locales/
  cp $NUM/customize.sh $WORKDIR/target-dir/

  (cd $WORKDIR; \
   mount proc -t proc target-dir/proc \
   && mount -o bind /dev target-dir/dev \
   && chroot target-dir/ /bin/bash /customize.sh; \
   umount target-dir/proc target-dir/dev)
  rm $WORKDIR/target-dir/customize.sh
  mv $WORKDIR/target-dir/extra.tar.* $WORKDIR/
  printf "build.manifest\nextra.tar.*\nrootfs_contents.sig\n" > $WORKDIR/.dockerignore

  (cd $WORKDIR/target-dir; tar -caf ../rootfs.tar.xz ./* && cd .. && rm -rf target-dir)

  cp Dockerfile $WORKDIR/
  (cd $WORKDIR; docker build --rm -t "$DOCKERTAG" .)

  if [[ -d $NUM/$ARCH ]]; then
    rm -r $NUM/$ARCH
  fi
  mv $WORKDIR $NUM/$ARCH

  docker run --rm "$DOCKERTAG" dpkg-query -f '${Status}\t${Package}\t${Version}\n' -W \
    | awk '/^install ok installed/{print $4,"\t",$5}' >$NUM/$ARCH/build.manifest
}

for NUM; do
  mktarball $ARCH $NUM &
  sleep 2
done

wait
