#!/usr/bin/env python3
"""Summarize recorder JSONL without claiming per-app energy attribution."""
import argparse,json,statistics
from pathlib import Path
from collections import defaultdict

def summarize(rows):
 groups=defaultdict(list)
 for r in rows:
  if r.get('type')=='sample':groups[r.get('session','unknown')].append(r)
 result=[]
 for sid,rs in groups.items():
  rs=sorted({r['monotonic_ticks']:r for r in rs}.values(),key=lambda r:r['monotonic_ticks'])
  times=[r.get('elapsed_seconds')for r in rs if r.get('elapsed_seconds')is not None]
  cpu=defaultdict(list);cpu_seconds=defaultdict(float);cpu_coverage=defaultdict(float);temps=[];discharge=[];gaps=[];charging=0
  for r in rs:
   dt=r.get('elapsed_seconds')or 0
   if dt>max(90,3*(r.get('interval_seconds')or 15)):gaps.append(dt)
   b=r.get('battery',{});charging+=bool(b.get('ExternalConnected'))
   if b.get('temperature_c')is not None:temps.append(b['temperature_c'])
   if b.get('discharge_w')is not None:discharge.append(b['discharge_w'])
   for p in r.get('processes',[]):
    if p.get('pid')==0 or p.get('name')=='kernel_task':continue
    load=p.get('cpu_one_core_percent')
    if load is not None and dt>0:
     cpu[p['name']].append(load);cpu_seconds[p['name']]+=load*dt/100;cpu_coverage[p['name']]+=dt
  top=[{'process':name,'cpu_seconds':round(seconds,2),'mean_one_core_percent':round(100*seconds/cpu_coverage[name],2),'max_one_core_percent':round(max(cpu[name]),2)}for name,seconds in sorted(cpu_seconds.items(),key=lambda p:p[1],reverse=True)[:12]]
  anomalies=[]
  if gaps:anomalies.append({'sampling_gaps_seconds':gaps,'meaning':'sleep/suspension or delay; missing time is not continuously measured'})
  for name,values in cpu.items():
   if len(values)>=4 and sum(v>=80 for v in values)>=4:anomalies.append({'high_cpu_candidate':name,'meaning':'load observation, not proof of a fault'})
  if temps and max(temps)>=40:anomalies.append({'high_battery_temperature_c':max(temps)})
  battery=rs[0].get('battery',{});last=rs[-1].get('battery',{})
  duration=(rs[-1]['monotonic_ticks']-rs[0]['monotonic_ticks'])*rs[-1].get('timebase_numer',1)/rs[-1].get('timebase_denom',1)/1e9
  charge_drop=None
  if not charging and duration>=600 and battery.get('charge_percent')is not None and last.get('charge_percent')is not None:charge_drop=(battery['charge_percent']-last['charge_percent'])*3600/duration
  result.append({'session':sid,'segment':rs[0].get('segment'),'samples':len(rs),'span_seconds':round(duration,2),'externally_powered_samples':charging,'charge_percent_first':battery.get('charge_percent'),'charge_percent_last':last.get('charge_percent'),'unplugged_charge_drop_points_per_hour':charge_drop,'mean_net_discharge_w':statistics.mean(discharge)if discharge else None,'max_temperature_c':max(temps)if temps else None,'max_sampling_gap_seconds':max(times)if times else None,'mean_collection_cpu_ms':statistics.mean(r['collection_cpu_ms']for r in rs if 'collection_cpu_ms'in r)if any('collection_cpu_ms'in r for r in rs)else None,'process_cpu':top,'signals':anomalies,'limits':'CPU is not per-app watts. Charging records do not measure device power. Short/gapped traces cannot establish VPN battery cost.'})
 return result

def read(paths):
 rows=[];invalid=0
 for path in paths:
  for line in Path(path).read_text(errors='replace').splitlines():
   try:r=json.loads(line)
   except ValueError:invalid+=1;continue
   if isinstance(r,dict):rows.append(r)
 return rows,invalid
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('logs',nargs='+');args=parser.parse_args();rows,invalid=read(args.logs);print(json.dumps({'invalid_or_partial_lines':invalid,'sessions':summarize(rows)},indent=2))
