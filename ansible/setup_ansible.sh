#!/bin/bash
#
# Copyright (c) 2023, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#

SCRIPT_PATH="$( cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 ; pwd -P )"
VENV_PATH=${1:-$SCRIPT_PATH}

if [[ -d ${VENV_PATH}/.venv ]]; then
  rm -rf ${VENV_PATH}/.venv
fi

python3 -m venv ${VENV_PATH}/.venv
source ${VENV_PATH}/.venv/bin/activate
pip install --upgrade pip wheel
pip install -r requirements.txt

echo "#####################################################"
echo "## Ansible Setup! To activate, please run:"
if [[ ${SCRIPT_PATH} == ${VENV_PATH} ]]; then
  echo "## source ./activate.env"
else
  echo "## source ./activate.env ${VENV_PATH}/"
fi
echo "#####################################################"
