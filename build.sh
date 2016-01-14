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
    $WORKDIR/multistrap.conf
  multistrap -f $WORKDIR/multistrap.conf || true
  rm $WORKDIR/multistrap.conf

  mkdir -p $WORKDIR/target-dir/etc/ssl/certs
  cp -a contrib/etc/ssl/certs/ca-certificates.crt $_
  cp -a $NUM/customize.sh $WORKDIR/target-dir/

  (cd $WORKDIR; \
   mount proc -t proc target-dir/proc \
   && mount -o bind /dev target-dir/dev \
   && chroot target-dir/ /bin/bash /customize.sh; \
   umount target-dir/proc target-dir/dev)
  rm $WORKDIR/target-dir/customize.sh

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
