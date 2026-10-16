import sys; sys.stdout.reconfigure(encoding="utf-8")
import os,re,sys
T=os.path.expanduser('~/.matlab/agentic-toolkits')
rows=[]
for tk in ('matlab','simulink'):
    root=f'{T}/{tk}/skills-catalog'
    for g in sorted(os.listdir(root)):
        gp=os.path.join(root,g)
        if not os.path.isdir(gp): continue
        for s in sorted(os.listdir(gp)):
            f=os.path.join(gp,s,'SKILL.md')
            if not os.path.isfile(f): continue
            txt=open(f,encoding='utf-8',errors='replace').read()
            m=re.match(r'---\s*\n(.*?)\n---',txt,re.S)
            fm=m.group(1) if m else ''
            d=re.search(r'^description:\s*(.*?)(?=^\w[\w-]*:|\Z)',fm,re.S|re.M)
            desc=d.group(1).strip() if d else ''
            desc=re.sub(r'^[>|][-+]?\s*','',desc)
            desc=re.sub(r'\s+',' ',desc).strip().strip('"\'')
            rows.append((tk,g,s,desc))
from collections import OrderedDict
cnt=OrderedDict()
for tk,g,s,d in rows: cnt[(tk,g)]=cnt.get((tk,g),0)+1
out=[]
out.append('# Vendor skills catalog (MathWorks Agentic Toolkit)\n')
out.append(f'Regenerated 2026-10-13 from the toolkit installed with **matlab 2026.08.27 / simulink 2026.09.a** - **{len(rows)} skills** ({sum(1 for r in rows if r[0]=="matlab")} MATLAB + {sum(1 for r in rows if r[0]=="simulink")} Simulink). Text is each skill\'s own frontmatter `description`, which is exactly what the agent sees when deciding whether to load it. These skills are MathWorks\' work; this file only lists them. Install them with `setupAgenticToolkit` (see ../README.md) - do not copy from here.\n')
out.append('Refresh this list yourself any time: `python tools/gen_skills_catalog.py > SKILLS_CATALOG.md`.\n')
out.append('| Toolkit | Group | Skills |\n|---|---|---|')
for (tk,g),n in cnt.items(): out.append(f'| {tk} | {g} | {n} |')
out.append(f'| **Total** | | **{len(rows)}** |\n\n---\n')
cur=None
for tk,g,s,d in rows:
    if (tk,g)!=cur:
        cur=(tk,g); out.append(f'\n## {tk} / {g}\n')
    out.append(f'- **`{s}`** - {d}')
print('\n'.join(out))
