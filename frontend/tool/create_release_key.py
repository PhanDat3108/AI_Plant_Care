"""Create a private local signing key once; never replace an existing key."""
from pathlib import Path
import os
import secrets
import shutil
import subprocess

android = Path(__file__).resolve().parents[1] / 'android'
key = android / 'release.jks'
properties = android / 'key.properties'
if key.exists() or properties.exists():
    raise SystemExit('Signing files already exist. Reuse/back up them; do not overwrite.')
keytool = shutil.which('keytool')
if not keytool:
    raise SystemExit('Install JDK and put keytool on PATH.')
password = secrets.token_hex(32)
env = dict(os.environ, PLANT_RELEASE_PASSWORD=password)
os.umask(0o077)
subprocess.run([
    keytool, '-genkeypair', '-keystore', str(key), '-storetype', 'PKCS12',
    '-alias', 'plantcare-release', '-keyalg', 'RSA', '-keysize', '3072',
    '-validity', '10000', '-dname', 'CN=AI Plant Care, O=AI Plant Care, C=VN',
    '-storepass:env', 'PLANT_RELEASE_PASSWORD',
    '-keypass:env', 'PLANT_RELEASE_PASSWORD',
], env=env, check=True)
with properties.open('x') as f:
    f.write(f'storeFile=release.jks\nstorePassword={password}\nkeyAlias=plantcare-release\nkeyPassword={password}\n')
key.chmod(0o600)
properties.chmod(0o600)
print('Created private android/release.jks and android/key.properties. Back up both securely.')
