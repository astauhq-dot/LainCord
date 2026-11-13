"""Check an encrypted user supplied IPA without publishing its contents."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import zipfile

archive, work = Path(sys.argv[1]), Path(sys.argv[2])
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for entry in z.infolist():
        p = Path(entry.filename)
        assert not p.is_absolute() and '..' not in p.parts
    info_path = next(n for n in z.namelist() if n.endswith('.app/Info.plist'))
    raw_info = z.read(info_path)
    info = plistlib.loads(raw_info)
    executable_path = info_path.rsplit('/', 1)[0] + '/' + info['CFBundleExecutable']
    zip_mode = oct(z.getinfo(executable_path).external_attr >> 16)

subprocess.run(['ditto', '-x', '-k', str(archive), str(work / 'extracted')], check=True)
app = work / 'extracted' / info_path.rsplit('/', 1)[0]
profile_result = subprocess.run(['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')], capture_output=True)
profile = plistlib.loads(profile_result.stdout) if profile_result.returncode == 0 else {}
redactions = [str(work)]
for key in ['Name', 'UUID', 'ApplicationIdentifierPrefix', 'TeamIdentifier', 'ProvisionedDevices']:
    value = profile.get(key)
    if isinstance(value, str): redactions.append(value)
    if isinstance(value, list): redactions += [v for v in value if isinstance(v, str)]
for cert in profile.get('DeveloperCertificates', []):
    cert_path = work / 'signer.der'
    cert_path.write_bytes(cert)
    cert_info = subprocess.run(['openssl', 'x509', '-inform', 'DER', '-in', str(cert_path), '-noout', '-subject'], capture_output=True, text=True)
    redactions += re.findall(r'(?:CN\s*=\s*|CN=)([^,/]+)', cert_info.stdout)

def clean(text):
    for item in sorted(set(redactions), key=len, reverse=True):
        if item: text = text.replace(item, '<redacted>')
    return text[:8000]

def run(label, args):
    result = subprocess.run(args, capture_output=True, text=True)
    print(json.dumps({'check': label, 'exit_code': result.returncode,
                      'output': clean(result.stdout + result.stderr)}, ensure_ascii=False))
    return result

print(json.dumps({'ipa_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
                  'bundle_id': info['CFBundleIdentifier'],
                  'minimum_ios': info['MinimumOSVersion'],
                  'zip_executable_mode': zip_mode,
                  'extracted_executable_mode': oct((app / info['CFBundleExecutable']).stat().st_mode),
                  'profile_decoded_by_apple': profile_result.returncode == 0,
                  'registered_device_count': len(profile.get('ProvisionedDevices', []))}))
run('Info.plist', ['plutil', '-lint', str(app / 'Info.plist')])
run('native_strict_signature', ['codesign', '--verify', '--deep', '--strict', '--all-architectures', '--verbose=4', str(app)])
run('apple_anchor_requirement', ['codesign', '--verify', '--strict', '--verbose=4', '-R=anchor apple generic', str(app)])
run('designated_requirement', ['codesign', '--display', '--requirements', '-', str(app)])
result = subprocess.run(['codesign', '--display', '--entitlements', '-', '--xml', str(app)], capture_output=True)
try:
    entitlements = plistlib.loads(result.stdout)
    identifier = entitlements.get('application-identifier', '')
    matches = identifier.partition('.')[2] == info['CFBundleIdentifier']
    print(json.dumps({'check': 'apple_decoded_entitlements', 'decoded': True,
                      'count': len(entitlements), 'application_identifier_matches_bundle': matches}))
except Exception:
    print(json.dumps({'check': 'apple_decoded_entitlements', 'decoded': False,
                      'error': clean(result.stderr.decode(errors='replace'))}))
run('architecture', ['lipo', '-archs', str(app / info['CFBundleExecutable'])])
# Test whether filesystem permissions affect Apple's signature validation.
os.chmod(app / info['CFBundleExecutable'], 0o755)
run('strict_signature_after_chmod', ['codesign', '--verify', '--deep', '--strict', '--verbose=4', str(app)])
