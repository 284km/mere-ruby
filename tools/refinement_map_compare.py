import hashlib,json,os,subprocess,time
from pathlib import Path
root=Path.cwd()
temp=Path(os.environ['RUNNER_TEMP'])
baseline=temp/'map-baseline/mere-ruby'
head=root/'mere-ruby'
stdlib=subprocess.check_output(['ruby','-rrbconfig','-e','print RbConfig::CONFIG["rubylibdir"]'],text=True)
rows=[]
for label,binary in [('baseline',baseline),('head',head),('head',head),('baseline',baseline)]:
    command=['/usr/bin/time','-v',str(binary),'--disable=gems','-I',stdlib,'-r',str(root/'.ruby-network/tool/lib/memory_status.rb'),str(root/'tools/refinement_diagnostic.rb')]
    start=time.monotonic()
    run=subprocess.run(command,capture_output=True,text=True,timeout=120)
    row=dict(label=label,binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),seconds=time.monotonic()-start,exit=run.returncode,stdout=run.stdout,stderr=run.stderr)
    rows.append(row)
    (temp/'refinement-map-comparison.json').write_text(json.dumps(rows,indent=2)+'\n')
    print(json.dumps(row),flush=True)
    assert run.returncode==0
