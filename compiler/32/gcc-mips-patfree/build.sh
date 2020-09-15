#!/bin/bash

set -e

# check parameters
if [ $# -ne 1 ] || [ $1 == "--help" ] || [ $1 == "-h" ]; then
    echo "Usage:"
    echo "./build.sh install_path"
    exit
fi

# check if given parameter is a valid directory
if [ ! -d $1 ]; then
    echo "Error!"
    echo "$1 is no valid install directory!"
    exit
fi

echo "Install path is:"
echo "$1"
read -p "Press [Enter] key to continue"

if [[ "$1" = /* ]]; then
    PREFIX=$1
else
    PREFIX=`pwd`/$1
fi

# get gcc
echo -n "Downloading gcc..."
wget ftp://ftp.gnu.org/gnu/gcc/gcc-9.3.0/gcc-9.3.0.tar.gz

# extract all tools

echo "Extracting all tools to the current directory"
read -p "Press [Enter] key to start extraction"
echo ""
echo -n "Extracting binutils..."
tar xf binutils-2.27.tar.gz
echo " done!"

echo -n "Extracting gmp..."
tar --lzip -xf gmp-6.1.2.tar.lz
echo " done!"

echo -n "Extracting mpfr..."
tar xf mpfr-3.1.5.tar.gz
echo " done!"

echo -n "Extracting mpc..."
tar xf mpc-1.0.3.tar.gz
echo " done!"

echo -n "Extracting gcc..."
tar xf gcc-9.3.0.tar.gz
echo " done!"

echo -n "Extracting newlib..."
tar xf newlib-2.5.0.tar.gz
echo " done!"

echo ""

echo "Building all tools"
read -p "Press [Enter] key to start building process"

# build binutils
echo -n "Patching binutils..."
patch ./binutils-2.27/opcodes/mips-opc.c < ./binutils-patch/binutils-2.27_mips-opc.c.patch
echo " done!"
echo -n "Building binutils..."
mkdir build-binutils
cd build-binutils
../binutils-2.27/configure --target=mipsel-elf --prefix=$PREFIX --disable-nls > /dev/null
make -j 9 > /dev/null
make install > /dev/null
cd ..
echo " done!"

# build gmp
echo -n "Building gmp..."
mkdir build-gmp
cd build-gmp
../gmp-6.1.2/configure --prefix=$PREFIX --disable-shared > /dev/null
make -j 9 > /dev/null
make install > /dev/null
cd ..
echo " done!"

# build mpfr
echo -n "Building mpfr..."
mkdir build-mpfr
cd build-mpfr
../mpfr-3.1.5/configure --prefix=$PREFIX --disable-shared --with-gmp=$PREFIX > /dev/null
make -j 9 > /dev/null
make install > /dev/null
cd ..
echo " done!"

# build mpc
echo -n "Building mpc..."
mkdir build-mpc
cd build-mpc
../mpc-1.0.3/configure --prefix=$PREFIX --disable-shared --with-gmp=$PREFIX > /dev/null
make -j 9 > /dev/null
make install > /dev/null
cd ..
echo " done!"

# patch gcc
echo -n "Patching gcc..."
patch ./gcc-9.3.0/gcc/config/mips/mips.h < ./gcc-patches/gcc-9.3.0_mips.h.patch
patch ./gcc-9.3.0/gcc/config/mips/mips.md < ./gcc-patches/gcc-9.3.0_mips.md.patch
patch ./gcc-9.3.0/gcc/config/mips/mips.opt < ./gcc-patches/gcc-9.3.0_mips.opt.patch
patch ./gcc-9.3.0/gcc/opth-gen.awk < ./gcc-patches/gcc-9.3.0_opth-gen.awk.patch
echo " done!"

# build gcc
echo -n "Building bootstrap gcc..."
mkdir build-bootstrap-gcc
cd build-bootstrap-gcc
../gcc-9.3.0/configure --target=mipsel-elf \
    --prefix=$PREFIX \
    --enable-languages=c,c++ \
    --with-mpfr=$PREFIX \
    --with-gmp=$PREFIX \
    --with-mpc=$PREFIX \
    --enable-lto \
    --disable-nls \
    --disable-shared \
    --disable-libstdc___v3 \
    --disable-decimal-float \
    --disable-threads \
    --disable-libmudflap \
    --disable-libssp \
    --disable-libgomp \
    --disable-libquadmath \
    --with-newlib > /dev/null
make -j 9 > /dev/null
make install > /dev/null
cd ..
echo " done!"

export PATH=$PREFIX/bin:$PATH

# "patch" newlib
# remove handwritten memcpy that uses unsupported assembly instructions
rm newlib-2.5.0/newlib/libc/machine/mips/memcpy.S
cp ./newlib-patches/Makefile.am newlib-2.5.0/newlib/libc/machine/mips/
cp ./newlib-patches/Makefile.in newlib-2.5.0/newlib/libc/machine/mips/

# build newlib
echo -n "Building newlib..."
oldCFLAGS=$CFLAGS
export CFLAGS_FOR_TARGET="-mno-unaligned-mem-access -DSMALL_MEMORY -Os"
mkdir build-newlib
cd build-newlib
../newlib-2.5.0/configure --target=mipsel-elf --prefix=$PREFIX > /dev/null
make all -j 9 > /dev/null
make install > /dev/null
CFLAGS=$CFLAGS
cd ..
echo " done"

# build gcc with newlib support
echo -n "Building gcc with newlib support..."
mkdir build-gcc
cd build-gcc
../gcc-9.3.0/configure --target=mipsel-elf \
    --prefix=$PREFIX \
    --enable-languages=c,c++ \
    --with-mpfr=$PREFIX \
    --with-gmp=$PREFIX \
    --with-mpc=$PREFIX \
    --enable-lto \
    --disable-nls \
    --disable-shared \
    --disable-libstdc___v3 \
    --disable-decimal-float \
    --disable-threads \
    --disable-libmudflap \
    --disable-libssp \
    --disable-libgomp \
    --disable-libquadmath \
    --with-newlib > /dev/null
make -j 9 > /dev/null
make install > /dev/null
cd ..
echo " done!"

# create environment profile
echo -n "Creating environment profile..."
echo "export PATH=\"\$PATH:$PREFIX/bin\"" > gcc-mips-patfree.env
echo " done!"

echo ""
echo "Finished!"
