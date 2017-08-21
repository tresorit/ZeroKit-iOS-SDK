#!/usr/bin/python

import shutil
import os
import argparse

def prepareSource(baseUrl, clientId, appBackendUrl):
	baseUrl = baseUrl.rstrip("/")
	
	scriptDir = os.path.dirname(os.path.realpath(__file__))

	configFiles = []

	src = os.path.join(scriptDir, '../ZeroKitExample/Config.sample.plist')
	dst = os.path.join(scriptDir, '../ZeroKitExample/Config.plist')
	shutil.copyfile(src, dst)
	configFiles.append(dst)

	for filepath in configFiles:
		filedata = None
		with open(filepath, 'r') as file :
			filedata = file.read()

		filedata = filedata.replace('{ServiceUrl}', baseUrl)
		filedata = filedata.replace('{ClientId}', clientId)
		filedata = filedata.replace('{AppBackendUrl}', appBackendUrl)

		with open(filepath, 'w') as file:
			file.write(filedata)

	print('Example app configured.')

def argParser():
	parser = argparse.ArgumentParser(description='Configure ZeroKit example app')
	parser.add_argument('-b', '--baseurl', help='Your service URL.', required=True)
	parser.add_argument('-c', '--clientid', help='Your mobile app client ID.', required=True)
	parser.add_argument('-a', '--appbackendurl', help='Your application backend URL.', required=True)
	return parser

if __name__ == '__main__':
	args = argParser().parse_args()
	prepareSource(args.baseurl, args.clientid, args.appbackendurl)
