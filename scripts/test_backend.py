#!/c/Python314/python
"""Test backend API endpoints"""
import json, urllib.request, urllib.parse, os, sys
from pathlib import Path

os.chdir(os.path.dirname(os.path.abspath(__file__)))
NAOXIN_ROOT = Path(os.path.dirname(os.path.abspath(__file__))).parent

# Find mat files in Naoxinyuyu_app/send_xzc/ or ../send_xzc/
mat_dir = NAOXIN_ROOT / 'send_xzc' / 'live_result'
if not mat_dir.exists():
    mat_dir = Path(os.path.dirname(NAOXIN_ROOT)) / 'send_xzc' / 'live_result'
files = list(mat_dir.glob('*.mat'))
if not files:
    print(f'No .mat files found in {mat_dir.resolve()}')
    sys.exit(1)

fpath = files[0]
print(f'Using: {fpath.name}')

# Upload
data = fpath.read_bytes()
boundary = '----WebKitFormBoundary' + os.urandom(16).hex()
body = (
    b'--' + boundary.encode() + b'\r\n'
    + b'Content-Disposition: form-data; name="file"; filename="' + fpath.name.encode() + b'"\r\n'
    + b'Content-Type: application/octet-stream\r\n\r\n'
    + data + b'\r\n'
    + b'--' + boundary.encode() + b'--\r\n'
)

req = urllib.request.Request(
    'http://127.0.0.1:8000/api/upload',
    data=body,
    headers={'Content-Type': f'multipart/form-data; boundary={boundary}'}
)
resp = urllib.request.urlopen(req)
d = json.loads(resp.read())
fid = d['file_id']
print(f'Upload: id={fid[:8]}... samples={d["num_samples"]} @{d["sample_rate"]}Hz')

# HRV
req2 = urllib.request.Request(
    'http://127.0.0.1:8000/api/hrv',
    data=json.dumps({'file_id': fid}).encode(),
    headers={'Content-Type': 'application/json'}
)
resp2 = urllib.request.urlopen(req2)
h = json.loads(resp2.read())
print(f'HRV: HR={h["heart_rate"]} BPM | SDNN={h["sdnn_ms"]} ms | RMSSD={h["rmssd_ms"]} ms')
print(f'     LF/HF={h["lf_hf_ratio"]} | Stress={h["stress_index"]} | R-peaks={h["r_peak_count"]}')
print(f'     RR intervals (first 3): {[round(x,1) for x in h["rr_intervals_ms"][:3]]}')

# Analyze
req3 = urllib.request.Request(
    'http://127.0.0.1:8000/api/analyze',
    data=json.dumps({'file_id': fid}).encode(),
    headers={'Content-Type': 'application/json'}
)
resp3 = urllib.request.urlopen(req3)
a = json.loads(resp3.read())
print(f'Analysis: score={a["health_score"]}')
print(f'  Summary: {a["interpretation"]["summary"][:120]}')
for f_ in a['interpretation']['findings']:
    print(f'  [F] {f_}')
for r_ in a['interpretation']['recommendations']:
    print(f'  [R] {r_}')

print('\nAll endpoints OK!')
