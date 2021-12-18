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

OSIS = [
    '0BSD',
    'AAL',
    'Abstyles',
    'Adobe-2006',
    'Adobe-Glyph',
    'ADSL',
    'AFL-1.1',
    'AFL-1.2',
    'AFL-2.0',
    'AFL-2.1',
    'AFL-3.0',
    'Afmparse',
    'AGPL-1.0',
    'AGPL-1.0-only',
    'AGPL-1.0-or-later',
    'AGPL-3.0',
    'AGPL-3.0-only',
    'AGPL-3.0-or-later',
    'Aladdin',
    'AMDPLPA',
    'AML',
    'AMPAS',
    'ANTLR-PD',
    'Apache-1.0',
    'Apache-1.1',
    'Apache-2.0',
    'APAFML',
    'APL-1.0',
    'APSL-1.0',
    'APSL-1.1',
    'APSL-1.2',
    'APSL-2.0',
    'Artistic-1.0',
    'Artistic-1.0-cl8',
    'Artistic-1.0-Perl',
    'Artistic-2.0',
    'Bahyph',
    'Barr',
    'Beerware',
    'BitTorrent-1.0',
    'BitTorrent-1.1',
    'Borceux',
    'BSD-1-Clause',
    'BSD-2-Clause',
    'BSD-2-Clause-FreeBSD',
    'BSD-2-Clause-NetBSD',
    'BSD-2-Clause-Patent',
    'BSD-3-Clause',
    'BSD-3-Clause-Attribution',
    'BSD-3-Clause-Clear',
    'BSD-3-Clause-LBNL',
    'BSD-3-Clause-No-Nuclear-License',
    'BSD-3-Clause-No-Nuclear-License-2014',
    'BSD-3-Clause-No-Nuclear-Warranty',
    'BSD-4-Clause',
    'BSD-4-Clause-UC',
    'BSD-Protection',
    'BSD-Source-Code',
    'BSL-1.0',
    'bzip2-1.0.5',
    'bzip2-1.0.6',
    'Caldera',
    'CATOSL-1.1',
    'CC-BY-1.0',
    'CC-BY-2.0',
    'CC-BY-2.5',
    'CC-BY-3.0',
    'CC-BY-4.0',
    'CC-BY-NC-1.0',
    'CC-BY-NC-2.0',
    'CC-BY-NC-2.5',
    'CC-BY-NC-3.0',
    'CC-BY-NC-4.0',
    'CC-BY-NC-ND-1.0',
    'CC-BY-NC-ND-2.0',
    'CC-BY-NC-ND-2.5',
    'CC-BY-NC-ND-3.0',
    'CC-BY-NC-ND-4.0',
    'CC-BY-NC-SA-1.0',
    'CC-BY-NC-SA-2.0',
    'CC-BY-NC-SA-2.5',
    'CC-BY-NC-SA-3.0',
    'CC-BY-NC-SA-4.0',
    'CC-BY-ND-1.0',
    'CC-BY-ND-2.0',
    'CC-BY-ND-2.5',
    'CC-BY-ND-3.0',
    'CC-BY-ND-4.0',
    'CC-BY-SA-1.0',
    'CC-BY-SA-2.0',
    'CC-BY-SA-2.5',
    'CC-BY-SA-3.0',
    'CC-BY-SA-4.0',
    'CC0-1.0',
    'CDDL-1.0',
    'CDDL-1.1',
    'CDLA-Permissive-1.0',
    'CDLA-Sharing-1.0',
    'CECILL-1.0',
    'CECILL-1.1',
    'CECILL-2.0',
    'CECILL-2.1',
    'CECILL-B',
    'CECILL-C',
    'ClArtistic',
    'CNRI-Jython',
    'CNRI-Python',
    'CNRI-Python-GPL-Compatible',
    'Condor-1.1',
    'CPAL-1.0',
    'CPL-1.0',
    'CPOL-1.02',
    'Crossword',
    'CrystalStacker',
    'CUA-OPL-1.0',
    'Cube',
    'curl',
    'D-FSL-1.0',
    'diffmark',
    'DOC',
    'Dotseqn',
    'DSDP',
    'dvipdfm',
    'ECL-1.0',
    'ECL-2.0',
    'eCos-2.0',
    'EFL-1.0',
    'EFL-2.0',
    'eGenix',
    'Entessa',
    'EPL-1.0',
    'EPL-2.0',
    'ErlPL-1.1',
    'EUDatagrid',
    'EUPL-1.0',
    'EUPL-1.1',
    'EUPL-1.2',
    'Eurosym',
    'Fair',
    'Frameworx-1.0',
    'FreeImage',
    'FSFAP',
    'FSFUL',
    'FSFULLR',
    'FTL',
    'GFDL-1.1',
    'GFDL-1.1-only',
    'GFDL-1.1-or-later',
    'GFDL-1.2',
    'GFDL-1.2-only',
    'GFDL-1.2-or-later',
    'GFDL-1.3',
    'GFDL-1.3-only',
    'GFDL-1.3-or-later',
    'Giftware',
    'GL2PS',
    'Glide',
    'Glulxe',
    'gnuplot',
    'GPL-1.0',
    'GPL-1.0+',
    'GPL-1.0-only',
    'GPL-1.0-or-later',
    'GPL-2.0',
    'GPL-2.0+',
    'GPL-2.0-only',
    'GPL-2.0-or-later',
    'GPL-2.0-with-autoconf-exception',
    'GPL-2.0-with-bison-exception',
    'GPL-2.0-with-classpath-exception',
    'GPL-2.0-with-font-exception',
    'GPL-2.0-with-GCC-exception',
    'GPL-3.0',
    'GPL-3.0+',
    'GPL-3.0-only',
    'GPL-3.0-or-later',
    'GPL-3.0-with-autoconf-exception',
    'GPL-3.0-with-GCC-exception',
    'gSOAP-1.3b',
    'HaskellReport',
    'HPND',
    'IBM-pibs',
    'ICU',
    'IJG',
    'ImageMagick',
    'iMatix',
    'Imlib2',
    'Info-ZIP',
    'Intel',
    'Intel-ACPI',
    'Interbase-1.0',
    'IPA',
    'IPL-1.0',
    'ISC',
    'JasPer-2.0',
    'JSON',
    'LAL-1.2',
    'LAL-1.3',
    'Latex2e',
    'Leptonica',
    'LGPL-2.0',
    'LGPL-2.0+',
    'LGPL-2.0-only',
    'LGPL-2.0-or-later',
    'LGPL-2.1',
    'LGPL-2.1+',
    'LGPL-2.1-only',
    'LGPL-2.1-or-later',
    'LGPL-3.0',
    'LGPL-3.0+',
    'LGPL-3.0-only',
    'LGPL-3.0-or-later',
    'LGPLLR',
    'Libpng',
    'libtiff',
    'LiLiQ-P-1.1',
    'LiLiQ-R-1.1',
    'LiLiQ-Rplus-1.1',
    'Linux-OpenIB',
    'LPL-1.0',
    'LPL-1.02',
    'LPPL-1.0',
    'LPPL-1.1',
    'LPPL-1.2',
    'LPPL-1.3a',
    'LPPL-1.3c',
    'MakeIndex',
    'MirOS',
    'MIT',
    'MIT-0',
    'MIT-advertising',
    'MIT-CMU',
    'MIT-enna',
    'MIT-feh',
    'MITNFA',
    'Motosoto',
    'mpich2',
    'MPL-1.0',
    'MPL-1.1',
    'MPL-2.0',
    'MPL-2.0-no-copyleft-exception',
    'MS-PL',
    'MS-RL',
    'MTLL',
    'Multics',
    'Mup',
    'NASA-1.3',
    'Naumen',
    'NBPL-1.0',
    'NCSA',
    'Net-SNMP',
    'NetCDF',
    'Newsletr',
    'NGPL',
    'NLOD-1.0',
    'NLPL',
    'Nokia',
    'NOSL',
    'Noweb',
    'NPL-1.0',
    'NPL-1.1',
    'NPOSL-3.0',
    'NRL',
    'NTP',
    'Nunit',
    'OCCT-PL',
    'OCLC-2.0',
    'ODbL-1.0',
    'OFL-1.0',
    'OFL-1.1',
    'OGTSL',
    'OLDAP-1.1',
    'OLDAP-1.2',
    'OLDAP-1.3',
    'OLDAP-1.4',
    'OLDAP-2.0',
    'OLDAP-2.0.1',
    'OLDAP-2.1',
    'OLDAP-2.2',
    'OLDAP-2.2.1',
    'OLDAP-2.2.2',
    'OLDAP-2.3',
    'OLDAP-2.4',
    'OLDAP-2.5',
    'OLDAP-2.6',
    'OLDAP-2.7',
    'OLDAP-2.8',
    'OML',
    'OpenSSL',
    'OPL-1.0',
    'OSET-PL-2.1',
    'OSL-1.0',
    'OSL-1.1',
    'OSL-2.0',
    'OSL-2.1',
    'OSL-3.0',
    'PDDL-1.0',
    'PHP-3.0',
    'PHP-3.01',
    'Plexus',
    'PostgreSQL',
    'psfrag',
    'psutils',
    'Python-2.0',
    'Qhull',
    'QPL-1.0',
    'Rdisc',
    'RHeCos-1.1',
    'RPL-1.1',
    'RPL-1.5',
    'RPSL-1.0',
    'RSA-MD',
    'RSCPL',
    'Ruby',
    'SAX-PD',
    'Saxpath',
    'SCEA',
    'Sendmail',
    'SGI-B-1.0',
    'SGI-B-1.1',
    'SGI-B-2.0',
    'SimPL-2.0',
    'SISSL',
    'SISSL-1.2',
    'Sleepycat',
    'SMLNJ',
    'SMPPL',
    'SNIA',
    'Spencer-86',
    'Spencer-94',
    'Spencer-99',
    'SPL-1.0',
    'StandardML-NJ',
    'SugarCRM-1.1.3',
    'SWL',
    'TCL',
    'TCP-wrappers',
    'TMate',
    'TORQUE-1.1',
    'TOSL',
    'Unicode-DFS-2015',
    'Unicode-DFS-2016',
    'Unicode-TOU',
    'Unlicense',
    'UPL-1.0',
    'Vim',
    'VOSTROM',
    'VSL-1.0',
    'W3C',
    'W3C-19980720',
    'W3C-20150513',
    'Watcom-1.0',
    'Wsuipa',
    'WTFPL',
    'wxWindows',
    'X11',
    'Xerox',
    'XFree86-1.1',
    'xinetd',
    'Xnet',
    'xpp',
    'XSkat',
    'YPL-1.0',
    'YPL-1.1',
    'Zed',
    'Zend-2.0',
    'Zimbra-1.3',
    'Zimbra-1.4',
    'Zlib',
    'zlib-acknowledgement',
    'ZPL-1.1',
    'ZPL-2.0',
    'ZPL-2.1',
    '389-exception',
    'Autoconf-exception-2.0',
    'Autoconf-exception-3.0',
    'Bison-exception-2.2',
    'Bootloader-exception',
    'Classpath-exception-2.0',
    'CLISP-exception-2.0',
    'DigiRule-FOSS-exception',
    'eCos-exception-2.0',
    'Fawkes-Runtime-exception',
    'FLTK-exception',
    'Font-exception-2.0',
    'freertos-exception-2.0',
    'GCC-exception-2.0',
    'GCC-exception-3.1',
    'gnu-javamail-exception',
    'i2p-gpl-java-exception',
    'Libtool-exception',
    'Linux-syscall-note',
    'LLVM-exception',
    'LZMA-exception',
    'mif-exception',
    'Nokia-Qt-exception-1.1',
    'OCCT-exception-1.0',
    'OpenJDK-assembly-exception-1.0',
    'openvpn-openssl-exception',
    'Qt-GPL-exception-1.0',
    'Qt-LGPL-exception-1.1',
    'Qwt-exception-1.0',
    'u-boot-exception-2.0',
    'sWxWindows-exception-3.1'
]

OSImap = {}
for osi in OSIS:
    OSImap[osi.lower()] = 'https://opensource.org/licenses/%s' % osi

lmap = {
    'commercial': 'https://en.m.wikipedia.org/wiki/Software_license#Proprietary_software_licenses',
    'freeware': 'https://en.wikipedia.org/wiki/Freeware',
    'proprietary': 'https://en.m.wikipedia.org/wiki/Software_license#Proprietary_software_licenses',
    'public_domain': 'https://wiki.creativecommons.org/wiki/Public_domain',
    'public domain': 'https://wiki.creativecommons.org/wiki/Public_domain',
    'public-domain': 'https://wiki.creativecommons.org/wiki/Public_domain',
    'publicdomain': 'https://wiki.creativecommons.org/wiki/Public_domain',
    'shareware': 'https://en.wikipedia.org/wiki/Shareware',
}


def do_license(v):
    """ doc me """
    url = v
    if 'identifier' in v:
        identifier = v['identifier']
    else:
        identifier = ''
    if 'url' in v:
        url = v['url']
    if re.search('^(http|ftp)', url):
        if not identifier:
            identifier = 'Link'
        v = '[%s](%s "%s")' % (identifier, url, url)
        return v

    if not identifier:
        identifier = url

    parts = re.split(r'[,|\s]+', identifier)
    v = ''
    for part in parts:
        if v > '':
            v += '/'
        url = ''
        k = part.lower()
        if k in OSImap:
            url = OSImap[k]
        elif lmap.get(k):
            url = lmap[k]
        if url > '':
            v += '[%s](%s "%s")' % (part, url, url)
        else:
            v += part
    return v


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
    return '[%s](%s "%s")' % (version, url, url)

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
        'license',
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

        with open(file, 'r') as f:
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
                    if key == 'license':
                        val = do_license(val)
                    if key == 'version':
                        val = do_version(j)
                    row[key] = val
                else:
                    row[key] = ''
            rows[name] = row

    table = [
        '<!-- The following table was inserted by makeindex.py -->',
        '<!-- Your edits will be lost the next time makeindex.py is run -->',
        '|Name|Version|Description|License|',
        '|----|-------|-----------|-------|'
    ]

    newlist = [(key, rows[key]) for key in sorted(rows.keys())]

    for (name, row) in newlist:
        table.append('|[%s](%s "%s")|%s|%s|%s|' % (
            name, row['homepage'], row['homepage'], row['version'], row['description'], row['license']))

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
