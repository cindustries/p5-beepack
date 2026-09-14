#!/usr/bin/env bash
set -euo pipefail
cpanm --installdeps --notest .
prove -lr t/
