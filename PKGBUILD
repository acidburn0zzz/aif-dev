# Maintainer: Chrysostomus @forum.manjaro.org

pkgname=manjaro-architect
_pkgname=aif-dev
pkgver=0.7.3.r0.g4e25727
pkgrel=1
pkgdesc="A clone of architect installer modified for manjaro"
arch=(any)
url="https://github.com/Chrysostomus/$_pkgname"
license=(GPL2)
depends=('bash'
	'dialog'
	'f2fs-tools'
	'git'
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

package () {
    cd $_pkgname
    install -Dm755 $pkgname $pkgdir/usr/bin/$pkgname 
    mkdir -p $pkgdir/usr/share/aif/{package-lists,translations}
    cp -r package-lists $pkgdir/usr/share/aif/
    cp -r translations $pkgdir/usr/share/aif/
    install -Dm644 $pkgname.desktop $pkgdir/usr/share/applications/$pkgname.desktop
    install -Dm644 $pkgname.png $pkgdir/usr/share/icons/hicolor/48x48/apps/$pkgname.png
    install -Dm644 ma-launcher.desktop $pkgdir/etc/skel/.config/autostart/ma-launcher.desktop
    install -m755 ma-launcher $pkgdir/usr/bin/ma-launcher
}
