#!/usr/bin/python
import os
import sys
TAGS_TEMP_FILE = '/tmp/tags'
projectDir = '../code'
ctagsExecutablePath = "/Applications/BBEdit.app/Contents/Helpers/ctags"
baseArgs = '--excmd=number --tag-relative=no --fields=+a+m+n+S -f /tmp/tags -R'
appendArg = '--append'

sourceDir = projectDir
tagsFile = os.path.join(projectDir, 'tags')

# create the project's tags in '/tmp'
if os.access(sourceDir, os.F_OK):
	buildTagsCommand = ''''%s' %s '%s' ''' % (ctagsExecutablePath, baseArgs, sourceDir)
	print buildTagsCommand
	output = os.popen(buildTagsCommand).read()
# move it where it goes
os.rename(TAGS_TEMP_FILE, tagsFile)