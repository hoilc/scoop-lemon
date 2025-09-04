#!/usr/bin/env python
# -*- coding: utf-8 -*-
""" @todo add docstring """

# Copy from https://github.com/rasa/scoops/blob/master/makeindex.py

# ### imports ###

from __future__ import (
    absolute_import,
    division,
    print_function  # ,
    #  unicode_literals
)

import fnmatch
import io
import json
import re
import os
# import pprint
import subprocess
import sys

def get_url(js):
    """ doc me """
    if 'checkver' in js:
        if 'url' in js['checkver']:
            return js['checkver']['url']
    if 'homepage' in js:
        return js['homepage']
    return ''


def do_version(js):
    """ doc me """
    version = js['version']
    url = get_url(js)
    if 'checkver' not in js:
        version = '<i>%s</i>' % version
    if url == '':
        return version
    return '[%s](%s)' % (version, url)

# pylint: disable=R0912 # Too many branches (22/12) (too-many-branches)
# pylint: disable=R0915 # Too many statements (71/50) (too-many-statements)
def main():
    """ doc me """
    markdown = 'README.md'
    print("Reading %s" % markdown)
    with io.open(markdown, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for i, line in enumerate(lines):
        lines[i] = str(line)

    specs = sys.argv
    specs.pop(0)

    if len(specs) == 0:
        specs = ['bucket/*.json']

    keys = [
        'checkver',
        'description',
        'homepage',
        'version',
    ]

    rows = {}

    cmdline = "git ls-files"
    proc = subprocess.Popen(cmdline, stdout=subprocess.PIPE, shell=True)
    (out, _) = proc.communicate()

    files = out.splitlines()
    for file in files:
        file = file.decode("utf-8")
        if re.search('wip/', file):
            # print("skipping %s: wip" % file)
            continue
        accept = False
        print("file=%s" % file)
        for spec in specs:
            # print("spec=%s" % spec)
            if fnmatch.fnmatch(file, spec):
                accept = True
                break

        if not accept:
            # print("skipping %s: not matched" % file)
            continue

        with open(file, 'r', encoding='utf-8') as f:
            j = json.load(f)
            row = {}
            (name, _) = os.path.splitext(os.path.basename(file))
            if re.search('^_', name):
                # print("skipping %s: starts with _" % name)
                continue
            if re.search('^schema', name):
                # print("skipping %s: starts with schema" % name)
                continue
            for key in keys:
                if key in j:
                    val = j[key]
                    if type(val).__name__ == 'unicode':
                        val = val.strip()
                    if key == 'version':
                        val = do_version(j)
                    row[key] = val
                else:
                    row[key] = ''
            rows[name] = row

    table = [
        '<!-- The following table was inserted by makeindex.py -->',
        '<!-- Your edits will be lost the next time makeindex.py is run -->',
        '|Name|Version|Description|',
        '|----|-------|-----------|'
    ]

    newlist = [(key, rows[key]) for key in sorted(rows.keys())]

    for (name, row) in newlist:
        table.append('|[%s](%s)|%s|%s|' % (
            name, row['homepage'], row['version'], row['description']))

    out = []

    found = False
    for line in lines:
        line = str(line.strip())
        if found:
            if re.match(r'^\s*<!--\s+</apps>\s+-->', line):
                found = False
            else:
                continue
        if re.match(r'^\s*<!--\s+<apps>\s+-->', line):
            found = True
            out.append(line)
            out.extend(table)
            continue

        out.append(line)

    print("Writing %s" % markdown)

    with io.open(markdown + '.tmp', 'w', encoding='utf-8', newline='\n') as f:
        data = "\n".join(out) + "\n"
        f.write(data)

    if os.path.exists(markdown + '.bak'):
        os.remove(markdown + '.bak')

    os.rename(markdown, markdown + '.bak')
    os.rename(markdown + '.tmp', markdown)

main()

sys.exit(0)
