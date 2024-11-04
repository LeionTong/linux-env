#!/bin/sh

MAJOR=3
MINOR=9
PATCH=9
PREFIX=/usr/local/python$MAJOR.$MINOR

# 下载源码包
# wget https://www.python.org/ftp/python/$MAJOR.$MINOR.$PATCH/Python-$MAJOR.$MINOR.$PATCH.tar.xz

rm -rf $PREFIX
mkdir $PREFIX
tar -xvf Python-$MAJOR.$MINOR.$PATCH.tar.xz
cd Python-$MAJOR.$MINOR.$PATCH
./configure --prefix=$PREFIX/
make -j $(nproc)
make altinstall

# 必须(创建 /usr/bin/python$MAJOR.$MINOR、/usr/bin/pip$MAJOR.$MINOR)
ln -svf $PREFIX/bin/python$MAJOR.$MINOR /usr/bin/python$MAJOR.$MINOR
ln -svf $PREFIX/bin/pip$MAJOR.$MINOR /usr/bin/pip$MAJOR.$MINOR

# 可选(创建 /usr/bin/python、/usr/bin/pip)
# mv /usr/bin/python{,.ori} || ln -svf python$MAJOR.$MINOR /usr/bin/python
# mv /usr/bin/pip{,.ori} || ln -svf pip$MAJOR.$MINOR /usr/bin/pip

# 可选(创建 /usr/bin/python3、/usr/bin/pip3)
# 注意：会影响dnf、yum、yum-config-manager等命令: grep python `which dnf`.
# mv /usr/bin/python3{,.ori} || ln -svf python$MAJOR.$MINOR /usr/bin/python3
# mv /usr/bin/pip3{,.ori} || ln -svf pip$MAJOR.$MINOR /usr/bin/pip3


## 检查软链接指向
# ls -l /usr/bin/{python*,pip*}
# ls -l /usr/bin/{python3.*,pip3.*}
ls -l /usr/bin/{python,python3,python3.*,pip,pip3,pip3.*}
## 检查版本
# python --version
# pip --version
# python3 --version
# pip3 --version