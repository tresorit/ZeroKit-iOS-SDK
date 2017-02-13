#!/usr/bin/python

import shutil
import os
import argparse

def prepareSource(baseUrl, tenantId, adminKey):
	baseUrl = baseUrl.rstrip("/")
	
	scriptDir = os.path.dirname(os.path.realpath(__file__))

	configFiles = []

	src = os.path.join(scriptDir, '../ZeroKitExampleTests/Info.sample.plist')
	dst = os.path.join(scriptDir, '../ZeroKitExampleTests/Info.plist')
	shutil.copyfile(src, dst)
	configFiles.append(dst)

	src = os.path.join(scriptDir, '../ZeroKitExample/Info.sample.plist')
	dst = os.path.join(scriptDir, '../ZeroKitExample/Info.plist')
	shutil.copyfile(src, dst)
	configFiles.append(dst)

	src = os.path.join(scriptDir, '../ZeroKitExample/ExampleAppMock/ExampleAppMock.sample.plist')
	dst = os.path.join(scriptDir, '../ZeroKitExample/ExampleAppMock/ExampleAppMock.plist')
	shutil.copyfile(src, dst)
	configFiles.append(dst)

	for filepath in configFiles:
		filedata = None
		with open(filepath, 'r') as file :
			filedata = file.read()

		filedata = filedata.replace('{TenantBaseUrl}', baseUrl)
		filedata = filedata.replace('{TenantId}', tenantId)
		filedata = filedata.replace('{AdminKey}', adminKey)

		with open(filepath, 'w') as file:
			file.write(filedata)

	print('Example app configured.')

def argParser():
	parser = argparse.ArgumentParser(description='Configure ZeroKit example app')
	parser.add_argument('-b', '--baseurl', help='Your API base URL.', required=True)
	parser.add_argument('-t', '--tenantid', help='Your tenant ID.', required=True)
	parser.add_argument('-a', '--adminkey', help='Your admin key.', required=True)
	return parser

if __name__ == '__main__':
	args = argParser().parse_args()
	prepareSource(args.baseurl, args.tenantid, args.adminkey)
