#!/usr/bin/env python3
"""Seed only an empty, backed-up Glow Simulator SQLite store with fictional data.

Stop Glow first. Never use this with a physical device or live CloudKit database.
Uses the existing store schema without changing application code or behavior.
"""
import argparse
import datetime as dt
import json
import sqlite3
import uuid
from zoneinfo import ZoneInfo
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('store', type=Path)
p.add_argument('--date', default=dt.date.today().isoformat())
a = p.parse_args()
assert '/CoreSimulator/Devices/' in str(a.store), 'Simulator stores only'
c = sqlite3.connect(a.store)
for table in ['ZHABIT', 'ZHABITLOG', 'ZWATERENTRY', 'ZWATERDAYGOAL', 'ZWATERPREFERENCES']:
    assert c.execute('select count(*) from '+table).fetchone()[0] == 0, 'Refusing a non-empty store'
today = dt.date.fromisoformat(a.date)
epoch = dt.datetime(2001, 1, 1, tzinfo=dt.timezone.utc).timestamp()
def stamp(day, hour=0):
    return dt.datetime.combine(day, dt.time(hour), tzinfo=ZoneInfo("America/Los_Angeles")).timestamp() - epoch
habits = [
    ('Morning walk', 'figure.walk', [1,2,3,4,5,6,7], 8, 0),
    ('Read a little', 'book.closed.fill', [1,2,3,4,5,6,7], 20, 30),
    ('Stretch', 'figure.flexibility', [1,2,3,4,5,6,7], 7, 30),
    ('Write a few lines', 'pencil.line', [1,2,3,4,5,6,7], 21, 0),
    ('Strength training', 'dumbbell.fill', [2,4,6], 17, 30),
]
log_pk = 0
with c:
    for pk, (title, icon, days, hour, minute) in enumerate(habits, 1):
        schedule = {'kind':'daily' if len(days)==7 else 'custom','days':days}
        c.execute('insert into ZHABIT (Z_PK,Z_ENT,Z_OPT,ZISARCHIVED,ZREMINDERENABLED,ZREMINDERHOUR,ZREMINDERMINUTE,ZSORTORDER,ZCREATEDAT,ZICONNAME,ZID,ZTITLE,ZSCHEDULEDATA) values (?,?,?,?,?,?,?,?,?,?,?,?,?)',
            (pk,1,1,0,1,hour,minute,pk-1,stamp(today-dt.timedelta(days=42)),icon,str(uuid.uuid4()),title,json.dumps(schedule).encode()))
        for offset in range(35,-1,-1):
            day=today-dt.timedelta(days=offset)
            weekday=(day.weekday()+1)%7+1
            if weekday not in days: continue
            complete = (offset + pk*3) % (8+pk) != 0
            if offset==0: complete=pk in (1,3)
            if not complete: continue
            log_pk+=1
            c.execute('insert into ZHABITLOG values (?,?,?,?,?,?)',(log_pk,2,1,1,pk,stamp(day)))
    oz=29.5735295625
    entry_pk=0
    for offset in range(29,-1,-1):
        day=today-dt.timedelta(days=offset)
        if offset in (12,21): continue
        key=day.isoformat()
        c.execute('insert into ZWATERDAYGOAL values (?,?,?,?,?,?,?)',(30-offset,3,1,stamp(day,7),80*oz,key,str(uuid.uuid4())))
        amounts=[12,21,12,[16,24,38,44][offset%4]]
        if offset==0: amounts=[12,21,12,12]
        for hour,amount in zip([6,7,8,9],amounts):
            entry_pk+=1
            c.execute('insert into ZWATERENTRY values (?,?,?,?,?,?,?)',(entry_pk,4,1,amount*oz,stamp(day,hour),key,str(uuid.uuid4())))
    c.execute('insert into ZWATERPREFERENCES values (?,?,?,?,?,?,?,?,?)',(1,5,1,80*oz,stamp(today),str(uuid.uuid4()),'custom','ounces',json.dumps({'amounts':[8*oz,12*oz,21*oz,24*oz]}).encode()))
    for ent, maximum in [(1,len(habits)),(2,log_pk),(3,30),(4,entry_pk),(5,1)]:
        c.execute('update Z_PRIMARYKEY set Z_MAX=? where Z_ENT=?',(maximum,ent))
    assert c.execute('pragma integrity_check').fetchone()[0]=='ok'
c.close()
print(f'Seeded {len(habits)} fictional habits, {log_pk} logs, {entry_pk} water entries for {today}.')
