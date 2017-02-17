# Maintainer: Chrysostomus @forum.manjaro.org
# Maintainer: Bernhard Landauer <oberon@manjaro.org>

pkgname=manjaro-architect
_pkgname=aif
pkgver=0.7.4.r34.g9b50b7b
pkgrel=1
pkgdesc="Manjaro CLI net-installer, forked from the Archlinux Architect"
arch=(any)
url="https://github.com/Chrysostomus/$_pkgname"
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
    cd $_pkgname
    git describe --long --tags | sed 's/\([^-]*-g\)/r\1/;s/-/./g'
}

build() {
    cd $_pkgname
	make PREFIX=/usr
}

package() {
    cd $_pkgname
	make PREFIX=/usr DESTDIR=${pkgdir} install
}
