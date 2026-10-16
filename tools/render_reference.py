#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Render project reference Markdown (headings, tables, code, paragraphs)."""
from pathlib import Path
import html,re,sys
for name in sys.argv[1:]:
 p=Path(name);lines=p.read_text().splitlines();out=[];i=0
 inline=lambda x:re.sub(r'`([^`]+)`',r'<code>\1</code>',re.sub(r'\*\*([^*]+)\*\*',r'<strong>\1</strong>',html.escape(x)))
 while i<len(lines):
  s=lines[i]
  if s.startswith('```') or s.startswith('    '):
   fenced=s.startswith('```');block=[]
   if fenced:i+=1
   while i<len(lines) and (not lines[i].startswith('```') if fenced else lines[i].startswith('    ')):
    block.append(lines[i] if fenced else lines[i][4:]);i+=1
   if fenced:i+=1
   out.append('<pre>'+html.escape('\n'.join(block))+'</pre>')
  elif s.startswith('|'):
   rows=[];j=0
   while i<len(lines) and lines[i].startswith('|'):
    cells=lines[i].strip('|').split('|')
    if not all(re.fullmatch(r'\s*:?-+:?\s*',c)for c in cells):
     tag='th'if j==0 else 'td';rows.append('<tr>'+''.join(f'<{tag}>'+inline(c.strip())+f'</{tag}>'for c in cells)+'</tr>')
    i+=1;j+=1
   out.append('<div class="scroll"><table>'+''.join(rows)+'</table></div>')
  elif s.startswith('#'):
   n=len(s)-len(s.lstrip('#'));out.append(f'<h{n}>'+inline(s[n:].strip())+f'</h{n}>');i+=1
  elif not s.strip():i+=1
  else:
   para=[s];i+=1
   while i<len(lines) and lines[i].strip() and not lines[i].startswith(('#','|','```','    ','- ')):
    para.append(lines[i]);i+=1
   out.append('<p>'+inline(' '.join(para))+'</p>')
 p.with_suffix('.html').write_text('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>'+html.escape(p.stem)+'</title><style>body{max-width:1100px;margin:32px auto;padding:0 22px;background:#101923;color:#e5edf5;font:16px/1.6 system-ui}h1,h2{color:#70ddd2}pre{white-space:pre-wrap;background:#182635;padding:18px}code{color:#a1e4e1}table{border-collapse:collapse}th,td{padding:10px;border:1px solid #344b60;text-align:left}.scroll{overflow-x:auto}</style></head><body>'+''.join(out)+'</body></html>')
