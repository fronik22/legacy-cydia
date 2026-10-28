from analyze import summarize
r={'type':'sample','session':'x','segment':'video-vpn-on','monotonic_ticks':0,'timebase_numer':1,'timebase_denom':1,'battery':{'ExternalConnected':False,'charge_percent':80,'discharge_w':4},'processes':[]}
s={**r,'monotonic_ticks':900000000000,'elapsed_seconds':900,'battery':{**r['battery'],'charge_percent':75},'processes':[{'name':'vpn','cpu_one_core_percent':50}]}
x=summarize([r,s])[0];assert x['unplugged_charge_drop_points_per_hour']==20;assert x['process_cpu'][0]['cpu_seconds']==450;assert x['signals'][0]['sampling_gaps_seconds']==[900]
y=summarize([{**r,'battery':{**r['battery'],'ExternalConnected':True}},s])[0];assert y['unplugged_charge_drop_points_per_hour']is None
print('Analysis charging exclusion, CPU-time integration and sampling-gap handling passed')

z=summarize([r,{**s,'processes':[{'name':'kernel_task','pid':0,'cpu_one_core_percent':200},{'name':'vpn','pid':10,'cpu_one_core_percent':1}]}])[0];assert [p['process']for p in z['process_cpu']]==['vpn']
print('Kernel idle-thread counter exclusion passed')

a={**s,'monotonic_ticks':1000000000,'elapsed_seconds':1,'processes':[{'name':'vpn','cpu_one_core_percent':100}]}
b={**s,'monotonic_ticks':10000000000,'elapsed_seconds':9,'processes':[{'name':'vpn','cpu_one_core_percent':0}]}
w=summarize([r,a,b])[0]['process_cpu'][0];assert w['mean_one_core_percent']==10
print('Unequal sampling intervals use a time-weighted mean')

import tempfile
from analyze import read
with tempfile.NamedTemporaryFile(mode='w+',suffix='.jsonl')as f:
 f.write('{"type":"stop"}\n{"partial":');f.flush();rows,bad=read([f.name]);assert len(rows)==1 and bad==1
print('Partial final log lines are reported and skipped')
