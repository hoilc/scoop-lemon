# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "internetarchive",
# ]
# ///
import os
import re
import time
import hashlib
import fnmatch
import json
from pathlib import Path
from requests.adapters import HTTPAdapter
from internetarchive import get_session

class RateLimitedAdapter(HTTPAdapter):
    def __init__(self, *args, max_calls=5, period=30, **kwargs):
        super().__init__(*args, **kwargs)
        self.max_calls = max_calls
        self.period = period
        self.calls = []

    def send(self, request, *args, **kwargs):
        now = time.time()
        self.calls = [call for call in self.calls if now - call < self.period]

        if len(self.calls) >= self.max_calls:
            sleep_time = self.period - (now - self.calls[0])
            if sleep_time > 0:
                print(f'Rate limit reached, waiting {sleep_time:.1f} seconds...')
                time.sleep(sleep_time)

        self.calls.append(time.time())
        return super().send(request, *args, **kwargs)

def calculate_sha256(file_path):
    sha256_hash = hashlib.sha256()
    with open(file_path, 'rb') as f:
        for byte_block in iter(lambda: f.read(4096), b''):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def parse_size(size_str):
    size_str = size_str.strip().upper()
    if not size_str:
        return None

    units = {
        'B': 1,
        'KB': 1024,
        'MB': 1024 ** 2,
        'GB': 1024 ** 3,
        'TB': 1024 ** 4,
    }

    for unit, multiplier in units.items():
        if size_str.endswith(unit):
            try:
                return int(size_str[:-len(unit)]) * multiplier
            except ValueError:
                return None

    try:
        return int(size_str)
    except ValueError:
        return None

def is_manifest_blacklisted(manifest_name):
    blacklist_env = os.environ.get('ARCHIVE_BLACKLIST_MANIFESTS', '')
    if not blacklist_env:
        return False

    blacklist = [item.strip() for item in blacklist_env.replace('\n', ',').split(',') if item.strip()]

    for pattern in blacklist:
        if fnmatch.fnmatch(manifest_name, pattern):
            return True

    return False

def is_url_blacklisted(manifest_name, bucket_dir):
    blacklist_env = os.environ.get('ARCHIVE_BLACKLIST_URLS', '')
    if not blacklist_env:
        return False

    blacklist = [item.strip() for item in blacklist_env.replace('\n', ',').split(',') if item.strip()]

    manifest_file = Path(bucket_dir) / f'{manifest_name}.json'
    if not manifest_file.exists():
        return False

    try:
        with open(manifest_file, 'r', encoding='utf-8') as f:
            manifest_data = json.load(f)
    except:
        return False

    urls = []

    def extract_urls(obj):
        if isinstance(obj, dict):
            for key, value in obj.items():
                if key == 'url' and isinstance(value, str):
                    urls.append(value)
                else:
                    extract_urls(value)
        elif isinstance(obj, list):
            for item in obj:
                extract_urls(item)

    extract_urls(manifest_data)

    for url in urls:
        for pattern in blacklist:
            if pattern in url:
                return True

    return False

def process_cache_files():
    scoop_dir = os.environ.get('SCOOP')
    if not scoop_dir:
        print('SCOOP environment variable not set')
        return

    cache_dir = Path(scoop_dir) / 'cache'
    if not cache_dir.exists():
        print(f'Cache directory does not exist: {cache_dir}')
        return

    bucket_dir = os.environ.get('ARCHIVE_BUCKET_DIR')
    if not bucket_dir:
        print('ARCHIVE_BUCKET_DIR environment variable not set')
        return

    max_file_size_str = os.environ.get('ARCHIVE_MAX_FILE_SIZE', '')
    max_file_size = parse_size(max_file_size_str) if max_file_size_str else None

    pattern = re.compile(r'^.*?#')
    download_suffix = '.download'

    session = get_session()
    adapter = RateLimitedAdapter(max_calls=3, period=20)
    session.mount('https://', adapter)
    session.mount('http://', adapter)

    dark_identifiers = set()
    files_to_process = {}

    for file_path in cache_dir.iterdir():
        if not file_path.is_file():
            continue

        filename = file_path.name

        if not pattern.match(filename):
            continue

        if filename.endswith(download_suffix):
            continue

        parts = filename.split('#')
        if len(parts) < 2:
            continue

        manifest_name = parts[0]
        manifest_version = parts[1]

        if is_manifest_blacklisted(manifest_name):
            print(f'Skipping {manifest_name} - manifest blacklisted')
            continue

        if is_url_blacklisted(manifest_name, bucket_dir):
            print(f'Skipping {manifest_name} - url blacklisted')
            continue

        if max_file_size:
            file_size = file_path.stat().st_size
            if file_size > max_file_size:
                print(f'Skipping {filename} - size {file_size} exceeds limit {max_file_size}')
                continue

        if manifest_name not in files_to_process:
            files_to_process[manifest_name] = []

        files_to_process[manifest_name].append({
            'file_path': file_path,
            'manifest_name': manifest_name,
            'manifest_version': manifest_version,
            'filename': filename
        })

    for manifest_name, files in files_to_process.items():
        identifier = f'scoop-lemon-{manifest_name}'
        print(f'::group::Archiving {manifest_name}')

        item = None
        try:
            print(f'Getting item {identifier}')
            item = session.get_item(identifier)
            if item.is_dark:
                print(f'Skipping {identifier} - item is dark')
                dark_identifiers.add(identifier)
                print('::endgroup::')
                continue
            existing_files = {f.name for f in item.files}
        except:
            existing_files = set()

        files_to_upload = {}

        for file_info in files:
            file_path = file_info['file_path']
            manifest_version = file_info['manifest_version']
            filename = file_info['filename']

            ext = Path(filename).suffix

            sha256 = calculate_sha256(file_path)
            new_filename = f'{manifest_name}#{manifest_version}#{sha256}{ext}'

            if new_filename in existing_files:
                print(f'Skipping {new_filename} - already exists in {identifier}')
                continue

            files_to_upload[new_filename] = str(file_path)

        if not files_to_upload:
            print('::endgroup::')
            continue

        metadata = {
            'mediatype': 'software',
            'title': f'{manifest_name} - scoop-lemon',
            'description': f'',
            'collection': ['scoop-lemon', 'softwarelibrary'],
            'subject': ['scoop', 'scoop-lemon'],
            'bucket': 'scoop-lemon',
            'repo': 'https://github.com/hoilc/scoop-lemon',
            'manifest': manifest_name
        }

        if item is None:
            item = session.get_item(identifier)

        try:
            print(f'Uploading {len(files_to_upload)} file(s) to {identifier}:')
            for remote_name in files_to_upload:
                print(f'- {remote_name}')
            item.upload(
                files_to_upload,
                metadata=metadata,
                checksum=True,
                verify=True,
                delete=True,
                retries=3,
                retries_sleep=30,
            )
            print(f'Successfully uploaded {len(files_to_upload)} file(s) to {identifier}')
        except Exception as e:
            print(f'Failed to upload to {identifier}: {e}')

        print('::endgroup::')

    if dark_identifiers:
        print('\n::group::Skipped dark items')
        for identifier in sorted(dark_identifiers):
            print(f'- {identifier}')
        print('::endgroup::')

if __name__ == '__main__':
    process_cache_files()
