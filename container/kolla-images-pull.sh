#!/bin/bash

. .venv_py3.9/bin/activate
kolla-ansible -i ./all-in-one -vvvv pull

## kolla-ansible -i ./all-in-one -vvvv pull --tags=prometheus
