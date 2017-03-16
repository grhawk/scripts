#!/usr/bin/env python3

""" Take a gen file (dftb+) and add the cell parameters.

This is very useful to automatize dftb+ computations that needs a cell starting
from xyz. The xyz file is assumed in ipi format.
"""

import re
import sys

# define useful regex
cell_re = [re.compile('CELL[\(\[\{]abcABC[\)\]\}]: ([-+0-9\.Ee ]*)\s*'),
           re.compile('CELL[\(\[\{]GENH[\)\]\}]: ([-+0-9\.?Ee ]*)\s*'),
           re.compile('CELL[\(\[\{]H[\)\]\}]: ([-+0-9\.?Ee ]*)\s*')]
position_units = [re.compile('position{(\w+)}')]
cell_units = [re.compile('cell{(\w+)}')]

# first argument xyz file and second the gen file
xyzfile = sys.argv[1]
genfile = sys.argv[2]

with open(xyzfile, 'r') as xyzdesc:
    for i, line in enumerate(xyzdesc.readlines()):
        if i == 0:
            natom = int(line)
        elif i == 1:
            cell = [key.search(line) for key in cell_re]
            if cell[0] is not None:
                a, b, c  = [float(x) for x in cell[0].group(1).split()[:3]]
                alpha, beta, gamma = [float(x)
                                      for x in cell[0].group(1).split()[3:6]]
                if not(alpha == 90. and
                       beta == 90. and
                       gamma == 90. ):
                    print("Only orthorombic cell are supported!")
                    exit(1)
            else:
                print("Only abcABC notation is supported!")
                exit(1)
            break

cell_gen = (str(a) + ' 0. 0.\n'
            '0. ' + str(b) + ' 0.\n'
            '0. 0. ' + str(c) + '\n')


_gen_cont = open(genfile, 'r').readlines()
if _gen_cont[0].find('S') > -1:
    print('!E! Already cellerized!')
    exit(1)

_tmp = [x.strip('\n') for x in _gen_cont]
_gen_cont = _tmp
_gen_cont[0] = _gen_cont[0].replace('C', 'S')
_gen_cont.append('0. 0. 0.')
_gen_cont.append(cell_gen)

open(genfile, 'w').write('\n'.join(_gen_cont))
