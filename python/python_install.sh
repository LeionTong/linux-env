#!/bin/sh

MAJOR=3
MINOR=9

tar -xvf Python-3.$MINOR.9.tar.xz
mkdir /usr/local/python3.$MINOR
cd Python-3.$MINOR.9
./configure --prefix=/usr/local/python3.$MINOR/
make -j $(nproc)
make altinstall

# 必须(创建 /usr/bin/python3.$MINOR、/usr/bin/pip3.$MINOR)
ln -svf /usr/local/python3.$MINOR/bin/python3.$MINOR /usr/bin/python3.$MINOR
ln -svf /usr/local/python3.$MINOR/bin/pip3.$MINOR /usr/bin/pip3.$MINOR

# 可选(创建 /usr/bin/python、/usr/bin/pip)
mv /usr/bin/python{,.ori} || ln -svf python3.$MINOR /usr/bin/python
mv /usr/bin/pip{,.ori} || ln -svf pip3.$MINOR /usr/bin/pip

# 可选(创建 /usr/bin/python3、/usr/bin/pip3)
# 注意：会影响dnf、yum、yum-config-manager等命令: grep python `which dnf`.
mv /usr/bin/python3{,.ori} || ln -svf python3.$MINOR /usr/bin/python3
mv /usr/bin/pip3{,.ori} || ln -svf pip3.$MINOR /usr/bin/pip3


# 检查版本
python --version
pip --version
python3 --version
pip3 --version
## 检查软链接指向
ll /usr/bin/{python,python3,python3.$MINOR,pip,pip3,pip3.$MINOR}
ll /usr/bin/{python*,pip*}