#!/bin/bash

[ ! -d ~/lenovo-leion ] && sudo mkdir -p ~/lenovo-leion
sudo mount -t drvfs //192.168.31.13/Users/leion ~/lenovo-leion
