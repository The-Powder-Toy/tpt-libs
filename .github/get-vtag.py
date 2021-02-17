import datetime
import re
import sys

match = re.match(r'refs/tags/(v[0-9]+)', sys.argv[1])
if match:
	vtag = match.group(1)
else:
	vtag = datetime.datetime.now().strftime('v%Y%m%d%H%M%S')
print('::set-output name=VTAG::' + vtag)
