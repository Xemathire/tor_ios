#!/bin/bash
REPOROOT=$(pwd)

DEPENDIR="${REPOROOT}/dependencies"
mkdir -p "${DEPENDIR}"

echo "Building Tor.framework with Carthage…"
cd "${REPOROOT}"
carthage update --platform iOS --verbose

cp "${REPOROOT}/Carthage/Checkouts/Tor.framework/Tor/tor/src/config/geoip" "${DEPENDIR}/geoip"
cp "${REPOROOT}/Carthage/Checkouts/Tor.framework/Tor/tor/src/config/geoip6" "${DEPENDIR}/geoip6"
cp -R "${REPOROOT}/Carthage/Build/iOS/Tor.framework" "${DEPENDIR}/Tor.framework"

BUILDDIR="${REPOROOT}/build"
mkdir -p "${BUILDDIR}"

SRCDIR="${BUILDDIR}/src"
mkdir -p "${SRCDIR}"

echo $'\n\nCloning https://github.com/mtigas/iObfs.git…'
cd "${SRCDIR}"
rm -fr "${SRCDIR}/iObfs"
git clone https://github.com/mtigas/iObfs.git

echo $'\n\nBuilding iObfs.framework…'
cd ./iObfs
./build.sh

cp -R "${SRCDIR}/iObfs/Iobfs4proxy.framework" "${DEPENDIR}/Iobfs4proxy.framework"

echo $'\n\nCleaning up…'
cd "${REPOROOT}"
rm -rf "${BUILDDIR}"
rm -rf "${REPOROOT}/Carthage"

echo "Done!"