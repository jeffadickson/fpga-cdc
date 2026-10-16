#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Yosys bounded multi-clock mailbox safety, reachability and negative control."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--depth', type=int, default=40)
    p.add_argument('--cover-depth', type=int, default=112)
    p.add_argument('--req-width', type=int, default=4)
    p.add_argument('--rsp-width', type=int, default=3)
    p.add_argument('--stages', type=int, default=2)
    p.add_argument('--timeout', type=int, default=120)
    p.add_argument('--matrix', action='store_true', help='Run 1/1/2, 4/3/2 and 32/16/3 width/stage configurations')
    p.add_argument('--out', type=Path, default=ROOT/'build/cdc-mailbox-formal')
    a=p.parse_args()
    if min(a.depth,a.cover_depth,a.req_width,a.rsp_width,a.timeout)<1 or a.stages<2:
        p.error('Positive depths/widths/timeout and at least two synchronizer stages required')
    if a.matrix:
        results=[]
        for req,rsp,stages in [(1,1,2),(4,3,2),(32,16,3)]:
            name=f'req{req}-rsp{rsp}-sync{stages}'
            print('Configuration: '+name,flush=True)
            command=[os.sys.executable,str(Path(__file__)), '--req-width',str(req),
                     '--rsp-width',str(rsp),'--stages',str(stages),'--depth',str(a.depth),
                     '--cover-depth',str(a.cover_depth),'--timeout',str(a.timeout),
                     '--out',str(a.out/name)]
            run=subprocess.run(command,cwd=ROOT)
            results.append({'configuration':name,'returncode':run.returncode})
        a.out.mkdir(parents=True,exist_ok=True)
        (a.out/'matrix.json').write_text(json.dumps(results,indent=2)+'\n')
        return int(any(r['returncode'] for r in results))
    yosys=shlex.split(os.environ.get('YOSYS','yosys'))
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    rtl=ROOT/'rtl/common/cdc_mailbox.sv';props=Path(__file__).with_name('properties.svh')
    source=rtl.read_text()
    if source.count('endmodule')!=1: raise RuntimeError('Expected one mailbox module')
    checked=source.replace('endmodule',props.read_text()+'\nendmodule')
    (out/'checked.sv').write_text(checked)
    mutations={
        'corrupt_request': ('dst_data <= src_payload;', 'dst_data <= ~src_payload;'),
        'corrupt_response': ('src_rsp_data <= dst_response;', 'src_rsp_data <= ~dst_response;'),
        'early_ack': ('ack_toggle <= req_sync[SYNC_STAGES-1];',
                      'ack_toggle <= req_sync[SYNC_STAGES-1];'),
        'drop_stalled_response': ('if (src_rsp_valid && src_rsp_ready) src_rsp_valid <= 0;',
                                  'if (src_rsp_valid) src_rsp_valid <= 0;'),
    }
    for name,(needle,replacement) in mutations.items():
        if checked.count(needle)!=1: raise RuntimeError('Mutation site changed: '+name)
        if name=='early_ack':
            # Acknowledge when presenting the request, before destination commit.
            mutant=checked.replace(needle,'')
            site='dst_valid <= 1;'
            if mutant.count(site)!=1: raise RuntimeError('Early ACK mutation site changed')
            mutant=mutant.replace(site,site+' ack_toggle <= req_sync[SYNC_STAGES-1];')
        else: mutant=checked.replace(needle,replacement)
        (out/(name+'.sv')).write_text(mutant)
    version=subprocess.run(yosys+['-V'],capture_output=True,text=True,check=True).stdout.strip()
    result={'tool':version,'kind':'bounded safety, existential reachability, negative control',
            'clock_model':'clk2fflogic; independent arbitrary binary clocks; no fairness',
            'parameters':{k:str(v) if isinstance(v,Path) else v for k,v in vars(a).items()},'source_sha256':{str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest()
                for f in [rtl,props,Path(__file__)]},'targets':[]}
    success='SAT proof finished - no model found: SUCCESS!'
    witness='SAT proof finished - model found: FAIL!'
    targets=[('safety','checked.sv',a.depth,'-prove-asserts -verify',success)]
    for name,signal in [('two_roundtrips_and_stalls','f_cover'),
                        ('reset_in_transit','f_cover_reset_transit'),
                        ('reset_at_destination','f_cover_reset_destination'),
                        ('reset_at_response','f_cover_reset_response'),
                        ('four_roundtrips','f_cover_four')]:
        targets.append(('cover_'+name,'checked.sv',a.cover_depth,'-prove '+signal+' 0',witness))
    for name in mutations:
        targets.append(('negative_'+name,name+'.sv',a.depth,'-prove-asserts',witness))
    observed=' '.join('-show '+n for n in ['f_sent','f_committed','f_returned','f_pending',
                      'req_toggle','ack_toggle','src_payload','dst_response',
                      'f_abort_transit','f_abort_dst','f_abort_response'])
    for name,file,depth,option,marker in targets:
        script=f'''read_verilog -formal -sv {out}/{file}
chparam -set REQ_WIDTH {a.req_width} -set RSP_WIDTH {a.rsp_width} -set SYNC_STAGES {a.stages} cdc_mailbox
prep -top cdc_mailbox -flatten
clk2fflogic
opt -full
sat -seq {depth} -set-assumes {option} -timeout {a.timeout} -show-ports {observed} -dump_vcd {out}/{name}.vcd
'''
        path=out/(name+'.ys');path.write_text(script)
        vcd=out/(name+'.vcd');vcd.unlink(missing_ok=True)
        start=time.monotonic()
        try:
            run=subprocess.run(yosys+['-s',str(path)],cwd=ROOT,text=True,stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,timeout=a.timeout+30)
            log=run.stdout;code=run.returncode
        except subprocess.TimeoutExpired as e:
            log=e.stdout or b''
            if isinstance(log,bytes):log=log.decode(errors='replace')
            code=None
        (out/(name+'.log')).write_text(log)
        passed=code==0 and marker in log
        result['targets'].append({'name':name,'status':'PASS' if passed else 'FAIL',
                                  'returncode':code,'seconds':round(time.monotonic()-start,2)})
        (out/'results.json').write_text(json.dumps(result,indent=2)+'\n')
        print(name+': '+('PASS' if passed else 'FAIL'),flush=True)
        if not passed: print(log[-1800:],flush=True)
    return int(any(t['status']!='PASS' for t in result['targets']))

if __name__=='__main__':raise SystemExit(main())
