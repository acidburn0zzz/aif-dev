# Maintainer: Chrysostomus @forum.manjaro.org

pkgname=manjaro-architect
pkgver=0.1
pkgrel=1
pkgdesc="A clone of architect installer modified to install manjaro instead of arch linux"
arch=(any)
url="https://github.com/Manjaro-Pek/$pkgname"
license=(GPL2)
depends=('pacman'
	'arch-install-scripts'
	'mhwd'
	'manjaro-tools-base'
	'dialog'
	'bash'
	'pacman-mirrors')
makedepends=('git')
source=("git://github.com/Chrysostomus/aif-dev")
md5sums=('SKIP')
package () {
    cd "$srcdir/aif-dev"
    install -dm755 "${pkgdir}/usr/lib/$pkgname"
    install -Dm755 "$srcdir/aif" "$pkgdir/usr/bin/aif"
    install -dm644 $pkgdir/usr/share/aif/package-lists
    install -dm644 $pkgdir/usr/share/aif/translations
    cp -r Package-lists/* "$pkgdir/usr/share/aif/package-lists/"
    cp -r translations/* "$pkgdir/usr/share/aif/translations/"
}
