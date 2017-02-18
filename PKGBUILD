# Maintainer: Chrysostomus @forum.manjaro.org
# Maintainer: Bernhard Landauer <oberon@manjaro.org>

pkgname=manjaro-architect
pkgver=0.7.4.r42.g79967a2
pkgrel=1
pkgdesc="Manjaro CLI net-installer, forked from the Archlinux Architect"
arch=(any)
url="https://github.com/Chrysostomus/$pkgname"
license=(GPL2)
depends=('bash'
         'dialog'
         'f2fs-tools'
         'gptfdisk'
         'manjaro-tools-base'
         'mhwd'
         'nilfs-utils'
         'pacman'
         'pacman-mirrorlist'
         'parted')
makedepends=('git')
source=("git+$url.git")
md5sums=('SKIP')

pkgver() {
    cd $pkgname
    git describe --long --tags | sed 's/\([^-]*-g\)/r\1/;s/-/./g'
}

build() {
    cd $pkgname
	make PREFIX=/usr
}

package() {
    cd $pkgname
	make PREFIX=/usr DESTDIR=${pkgdir} install
}
