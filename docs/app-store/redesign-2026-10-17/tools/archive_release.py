#!/usr/bin/env python3
"""Rebuild the shipped Glow source for the approved metadata-only update.

Uses the existing Xcode signing setup. Does not upload or change the checkout.
Version overrides apply consistently to the app, widget, and Watch targets.
"""
import json, pathlib, plistlib, subprocess, tarfile, tempfile
RELEASE_SOURCE='29d3f071ab45bb51d9c4aabffc7e9f614cbba614'
VERSION='2.4'
BUILD='3'
repo=pathlib.Path(__file__).resolve().parents[4]
work=pathlib.Path(tempfile.mkdtemp(prefix='glow-release-2.4-3-'))
source=work/'Source'
source.mkdir()
subprocess.run(['git','archive','--format=tar','--output='+str(work/'source.tar'),RELEASE_SOURCE],cwd=repo,check=True)
with tarfile.open(work/'source.tar') as archive: archive.extractall(source,filter='data')
archive=work/'Glow-2.4-3.xcarchive'
command=['xcodebuild','-project','Glow.xcodeproj','-scheme','Glow','-configuration','Release','-destination','generic/platform=iOS','-archivePath',str(archive),'-derivedDataPath',str(work/'DerivedData'),'MARKETING_VERSION='+VERSION,'CURRENT_PROJECT_VERSION='+BUILD,'SWIFT_TREAT_WARNINGS_AS_ERRORS=YES','GCC_TREAT_WARNINGS_AS_ERRORS=YES','archive']
print('Release working directory:',work,flush=True)
(work/'release-input.json').write_text(json.dumps({'source_commit':RELEASE_SOURCE,'version':VERSION,'build':BUILD,'command':command},indent=2)+'\n')
with (work/'archive.log').open('w') as log: result=subprocess.run(command,cwd=source,stdout=log,stderr=subprocess.STDOUT)
log=(work/'archive.log').read_text()
if result.returncode or 'warning:' in log.lower(): raise SystemExit('Archive failed or contains warnings; inspect '+str(work/'archive.log'))
app=archive/'Products/Applications/Glow.app'
bundles=[app,*app.glob('PlugIns/*.appex'),*app.glob('Watch/*.app')]
for bundle in bundles:
    info=plistlib.loads((bundle/'Info.plist').read_bytes())
    assert (info['CFBundleShortVersionString'],info['CFBundleVersion'])==(VERSION,BUILD),info
    print(info['CFBundleIdentifier'],VERSION,'('+BUILD+')',flush=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
print('ARCHIVE VERIFIED:',archive,flush=True)
