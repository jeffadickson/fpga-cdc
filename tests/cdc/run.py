#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Compile and run the generic CDC mailbox checks with Verilator 5.x."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]

def main():
    verilator = shutil.which('verilator')
    if not verilator:
        raise SystemExit('Install Verilator 5.x, a C++ compiler and GNU Make.')
    build = ROOT/'build/cdc-mailbox'
    build.mkdir(parents=True, exist_ok=True)
    with (build/'build.log').open('w') as log:
        subprocess.run([verilator, '--binary', '--timing', '--top-module',
                        'tb_cdc_mailbox', '--Mdir', str(build), '-j', '2',
                        'rtl/common/cdc_mailbox.sv',
                        'tests/cdc/tb_cdc_mailbox.sv'], cwd=ROOT, stdout=log,
                       stderr=subprocess.STDOUT, check=True, timeout=300)
    result = subprocess.run([str(build/'Vtb_cdc_mailbox')], cwd=ROOT,
                            capture_output=True, text=True, timeout=60)
    (build/'run.log').write_text(result.stdout+result.stderr)
    print(result.stdout+result.stderr, end='')
    result.check_returncode()

if __name__ == '__main__':
    main()
