import re
import sys

print('::set-output name=VTAG::%s' % re.match(r'refs/tags/(v[0-9]+)', sys.argv[1]).group(1))
