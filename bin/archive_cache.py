# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "internetarchive",
# ]
# ///
import os
import re
import hashlib
import fnmatch
import json
from pathlib import Path
from internetarchive import get_session

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

        try:
            print(f'Getting item {identifier}')
            item = session.get_item(identifier)
            existing_files = {f.name for f in item.files}
        except:
            existing_files = set()

        for file_info in files:
            file_path = file_info['file_path']
            manifest_version = file_info['manifest_version']
            filename = file_info['filename']

            ext = Path(filename).suffix

            sha256 = calculate_sha256(file_path)
            new_filename = f'{manifest_name}#{manifest_version}#{sha256}{ext}'
            new_file_path = file_path.parent / new_filename

            if new_filename in existing_files:
                print(f'Skipping {new_filename} - already exists in {identifier}')
                continue

            try:
                file_path.rename(new_file_path)
            except Exception as e:
                print(f'Failed to rename {filename}: {e}')
                continue

            metadata = {
                'mediatype': 'software',
                'title': f'{manifest_name} - scoop-lemon',
                'description': f'scoop bucket add lemon https://github.com/hoilc/scoop-lemon ; scoop install lemon/{manifest_name}',
                'collection': 'open_source_software',
                'subject': ['scoop', 'scoop-lemon'],
                'bucket': 'scoop-lemon',
                'repo': 'https://github.com/hoilc/scoop-lemon',
                'manifest': manifest_name
            }

            try:
                print(f'Uploading {new_filename}')
                item.upload(
                    str(new_file_path),
                    metadata=metadata,
                    checksum=True,
                    verify=True,
                    delete=True,
                    retries=3,
                    retries_sleep=30,
                )
                print(f'Successfully uploaded {new_filename}')
            except Exception as e:
                print(f'Failed to upload {new_filename}: {e}')
                new_file_path.rename(file_path)

if __name__ == '__main__':
    process_cache_files()
