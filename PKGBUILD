# Maintainer: Chrysostomus @forum.manjaro.org

pkgname=manjaro-architect
pkgver=0.5
pkgrel=1
pkgdesc="A clone of architect installer modified to install manjaro instead of arch linux"
arch=(any)
url="https://github.com/Chrysostomus/aif-dev"
license=(GPL2)
depends=('pacman'
	'mhwd'
	'manjaro-tools-base'
	'dialog'
	'bash'
	'gptfdisk'
	'f2fs-tools'
	'nilfs-utils'
	'parted'
	'git'
	'pacman-mirrorlist')
makedepends=('git')
source=("git://github.com/Chrysostomus/aif-dev")
md5sums=('SKIP')
package () {
    cd "$srcdir/aif-dev"
    install -Dm755 "$srcdir/aif-dev/manjaro-architect" "$pkgdir/usr/bin/manjaro-architect"
    install -dm655 $pkgdir/usr/share/aif/package-lists
    install -dm655 $pkgdir/usr/share/aif/translations
    cp -r $srcdir/aif-dev/package-lists/ "$pkgdir/usr/share/aif/"
    cp -r $srcdir/aif-dev/translations/ "$pkgdir/usr/share/aif/"
}
