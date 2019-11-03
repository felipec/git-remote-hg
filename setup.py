#!/usr/bin/env python
# -*- coding: us-ascii -*-
# vim:ts=4:sw=4:softtabstop=4:smarttab:expandtab
#
"""Simple setup.py for https://github.com/felipec/git-remote-hg

There are many different tools with the name git-remote-hg,
this is for https://github.com/felipec/git-remote-hg which
gives hg access/support to a git client.

This setup.py is currently focused on creating an exe
for Microsoft Windows.
"""

import sys
import glob
from distutils.core import setup

import py2exe

if len(sys.argv) == 1:
    print('defaulting to creating py2exe')
    sys.argv += ['py2exe']

"""
    options =   { "py2exe": {
                                #'bundle_files': 1,
                            }
                },

"""

setup(
    options =   { "py2exe": {
                                "includes": ["mercurial.cext.parsers",
                                            #"mercurial.pure.parser"  # for some reason I can't get this to work, pyd above works fine so no need for this backup
                                            ],  # force include as 
                                'bundle_files': 1,
                                'ascii': False,
                            }
                },
    zipfile = None, ## try and make a single exe, if do not want this loose this and the 'bundle_files' option
    console=['git-remote-hg']
    )
