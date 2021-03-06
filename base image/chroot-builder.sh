#!/usr/bin/env bash

set -e

BUILDDIR=/build
OUTPUTDIR=/out

pacman -Syu arch-install-scripts devtools fakechroot fakeroot --needed --noconfirm

mkdir -vp $BUILDDIR/alpm-hooks/usr/share/libalpm/hooks

find /usr/share/libalpm/hooks -exec ln -sf /dev/null $BUILDDIR/alpm-hooks{} \;

mkdir -vp $BUILDDIR/var/lib/pacman/ $OUTPUTDIR

install -Dm644 /usr/share/devtools/pacman-extra.conf $BUILDDIR/etc/pacman.conf

cat /pacman-conf.d-noextract.conf >> $BUILDDIR/etc/pacman.conf

fakechroot -- fakeroot -- pacman -Sy -r $BUILDDIR \
		--noconfirm --dbpath $BUILDDIR/var/lib/pacman \
		--config $BUILDDIR/etc/pacman.conf \
		--noscriptlet \
		--hookdir $BUILDDIR/alpm-hooks/usr/share/libalpm/hooks/ pacman sed glibc gawk gzip

echo "en_US.UTF-8 UTF-8" > $BUILDDIR/etc/locale.gen
echo "LANG=en_US.UTF-8" > $BUILDDIR/etc/locale.conf
echo "Server = https://mirror.pkgbuild.com/\$repo/os/\$arch" > $BUILDDIR/etc/pacman.d/mirrorlist
echo "Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch" >> $BUILDDIR/etc/pacman.d/mirrorlist
echo "Server = https://mirror.leaseweb.net/archlinux/\$repo/os/\$arch" >> $BUILDDIR/etc/pacman.d/mirrorlist

fakechroot -- fakeroot -- chroot $BUILDDIR update-ca-trust

fakechroot -- fakeroot -- chroot $BUILDDIR locale-gen

fakechroot -- fakeroot -- chroot $BUILDDIR sh -c 'pacman-key --init && pacman-key --populate archlinux && bash -c "rm -rf etc/pacman.d/gnupg/{openpgp-revocs.d/,private-keys-v1.d/,pubring.gpg~,gnupg.S.}*"'

ln -fs /usr/lib/os-release $BUILDDIR/etc/os-release

# add system users
# uncommented due to missing systemd
# fakechroot -- fakeroot -- chroot $BUILDDIR /usr/bin/systemd-sysusers --root "/"

# remove passwordless login for root (see CVE-2019-5021 for reference)
sed -i -e 's/^root::/root:!:/' "$BUILDDIR/etc/shadow"

# remove not needed packages

fakechroot -- fakeroot -- pacman -Rns -r $BUILDDIR \
		--noconfirm --dbpath $BUILDDIR/var/lib/pacman \
		--config $BUILDDIR/etc/pacman.conf \
		--noscriptlet \
		--hookdir $BUILDDIR/alpm-hooks/usr/share/libalpm/hooks/ sed gawk gzip

# fakeroot to map the gid/uid of the builder process to root
# fixes #22
fakeroot -- tar --numeric-owner --xattrs --acls --exclude-from=exclude -C $BUILDDIR -c . -f $OUTPUTDIR/minimal.tar

cd $OUTPUTDIR; xz -9 -T0 -f minimal.tar; sha256sum minimal.tar.xz > minimal.tar.xz.SHA256
