# Maintainer: Chrysostomus @forum.manjaro.org

pkgname=manjaro-architect
_pkgname=aif-dev
pkgver=0.7.3.r5.g2be235c
pkgrel=1
pkgdesc="A clone of architect installer modified for manjaro"
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

package () {

    _bindir=$pkgdir/usr/bin
    _sharedir=$pkgdir/usr/share
    _datadir=$_sharedir/aif
    _launchdir=$pkgdir/usr/share
    
    cd $_pkgname
    install -Dm755 $pkgname $_bindir/$pkgname
    install -m755 setup $_bindir/setup
    install -m755 ma-launcher $_bindir/ma-launcher
    mkdir -p $_datadir/{package-lists,translations}
    cp -r package-lists $_datadir
    cp -r translations $_datadir
    install -Dm644 $pkgname.desktop $_sharedir/applications/$pkgname.desktop
    install -Dm644 $pkgname.png $_sharedir/icons/hicolor/48x48/apps/$pkgname.png
    install -Dm644 ma-launcher.desktop $pkgdir/etc/skel/.config/autostart/ma-launcher.desktop
}
