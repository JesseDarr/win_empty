#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: 
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)


ANSIBLE_METADATA = {'metadata_version': '1.1',
                    'status': ['preview'],
                    'supported_by': 'community'}

DOCUMENTATION = r'''
---
module: win_empty
short_description: Deletes or empties folders on Windows hosts.
description:
  - Designed to do mass cleanup of windows servers/workstations as quickly as possible.
  - Works much fast than nesting win_find and win_file for the same purpose.
  - Allows for 'emptying' folders and preserving sub-folders.
  - This module is fully recursive in all modes.
version_added: "2.9"
author: Jesse Darr
options:
  age:
    description:
      - Optional when using the 'empty' state.
      - Number of days old an item's agestamp must be in order for it to be removed.
      - Only accepts integer values.
      - Defaults to 0 when not specified.
    default: 0
    type: int
  agestamp:
    description:
      - Optional when using the 'empty' state.
      - Defaults to mtime when not specified.
    choices:
      - atime
      - ctime
      - mtime
    default: mtime
    type: str
  keepfolders:
    description:
      - Optional when using the 'empty' state.
      - Defaults to false when not specified.
    default: false
    type: bool
  patterns:
    description:
      - Optional when using the 'empty' state.
      - "Defaults to '*' when not specified."
      - "Accepts powershell's GLOB like input using the * character."
      - "Accepts single input like:    '*.txt'"
      - "Accepts multiple input like:  ['*.txt', '*win*' ]"
    default: "'*'"
    type: list
  path:
    description:
      - Path to directory to be deleted or emptied.
      - Only accepts single paths.
      - Use with_items in your playbook to pass in multiple paths.
    type: str  
    required: true
  state:
    description:
      - Delete will attempt to delete a folder and all of its contents.
      - Empty will preserve the folder passed into it, and will attempt to delete all of its content that matches the other criteria (age, agestamp, keepfolders, patterns).
    choices:
      - delete
      - empty
    type: str
    required: true
notes:
  - This will likely run on Server 2008 R1, but that has not been tested.
  - Do not delete the recycle bin, use empty instead.
  - Only the recycle bin on the C drive is supported.  
requirements:
  - Server 2008 R2 or higher
  - Powershell v3 or higher
'''

EXAMPLES = r'''
- name: Delete a folder and all of its contents
  win_empty:
    path: c:\temp
    state: delete

vars:
  folders:
  - c:\foo
  - c:\bar
- name: Delete multiple folders and all of their contents
  win_empty:
    path: "{{ item }}"
    state: delete
  with_items: >
    {{ folders }}

- name: Empty a folder - preserves the folder but deletes all of its contents
  win_empty:
    path: c:\temp
    state: empty

- name: Empty the default recycle bin
  win_empty:
    path: c:\$recycle.bin
    state: empty

- name: Empty a folder of all itmes who's mtime (Last Modified Time) is more than 180 days old
  win_empty:
    age: 180
    path: c:\temp
    state: empty

- name: Empty a folder of all itmes who's ctime (Creation Time) is more than 180 days old
  win_empty:
    age: 180
    agestamp: ctime
    path: c:\temp
    state: empty

- name: Empty a folder of all itmes who's ctime (Last Access Time) is more than 180 days old
  win_empty:
    age: 180
    agestamp: atime
    path: c:\temp
    state: empty

- name: Empty a folder but preserver all sub-folders (useful for deleting logs of very old software)
  win_empty:
    keepfolders: true
    path: c:\temp
    state: empty

- name: Empty a folder of all files ending in .txt
  win_empty:
    patterns: '*.txt'
    path: c:\temp
    state: empty

- name: Empty a folder of all files ending in .txt and .log
  win_empty:
    patterns: ['*.txt', '*.log']
    path: c:\temp
    state: empty

- name: Empty a folder of all files who's names contain 'win'
  win_empty:
    patterns: '*win*'
    path: c:\temp
    state: empty

- name: Empty folder of all contents where: ctime > 180 days, .txt or .log extension, preserve sub-folders
  win_empty:
    age: 180
    agestamp: ctime
    keepfolders: true
    patterns: ['*.txt', '*.log']
    path: c:\temp
    state: empty
'''