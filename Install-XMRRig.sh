#!/bin/bash
sudo apt-get install software-properties-common && \

#Install GCC/G++ on Ubuntu 14/16
sudo apt-get update -y && \
sudo apt-get upgrade -y && \
sudo apt-get dist-upgrade -y && \
sudo apt-get install build-essential software-properties-common -y && \
sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
sudo apt-get update -y && \
sudo apt-get install gcc-7 g++-7 -y && \
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 60 --slave /usr/bin/g++ g++ /usr/bin/g++-7 && \
sudo update-alternatives --config gcc

#Install GCC/G++ on Ubuntu 18
#sudo add-apt-repository ppa:jonathonf/gcc-7.1 && \
#sudo apt-get update -y && \
#sudo apt-get upgrade -y && \

#Install libuv on Ubuntu 14
sudo add-apt-repository ppa:acooks/libwebsockets6 && \
sudo apt-get update && \
sudo apt-get install libuv1.dev && \

#Install packages for XMRRig
sudo apt-get install git build-essential cmake libuv1-dev libssl-dev libmicrohttpd-dev gcc-7 g++-7 && \

#Reboot after installation
#sudo reboot

#Install XMRRig
git clone https://github.com/xmrig/xmrig.git && \
cd xmrig && \
mkdir build && \
cd build && \
cmake .. -DCMAKE_C_COMPILER=gcc-7 -DCMAKE_CXX_COMPILER=g++-7 && \

#If you get (missing: HWLOC_LIBRARY HWLOC_INCLUDE_DIR) error, skip the above cmake command and run below
#cmake .. -DCMAKE_C_COMPILER=gcc-7 -DCMAKE_CXX_COMPILER=g++-7 -DWITH_HWLOC=OFF && \

make && \

#Check for Huge Pages
cat /sys/kernel/mm/transparent_hugepage/enabled && \

#Enable Huge Pages according to the number of CPU Cores you have
sysctl -w vm.nr_hugepages=8
