import numpy as np
import sys

def get_term(fname, term):
    a = None
    with open(fname, 'r') as f:
        for l in f:
            if l.startswith("Grad {:s} ".format(term)):
                a = []
                l = next(f)
                while l.strip():
                    a += [[float(x) for x in l.split()]]
                    l = next(f)
                a = np.array(a)
    return a

a = get_term(sys.argv[1], sys.argv[3])
b = get_term(sys.argv[2], sys.argv[3])

if len(sys.argv) >= 5:
    rtol = float(sys.argv[4])
else:
    rtol = 1e-05

if len(sys.argv) >= 6:
    atol = float(sys.argv[5])
else:
    atol = 1e-08

delta = np.abs(a - b)
deltar = np.abs((a-b)/b)
m = np.max(delta)
mr = 100*np.nanmax(deltar)
if np.isnan(mr):
    mr = 0.0

for i in range(a.shape[0]):
    print("[{:5d}] {:12.6f} {:12.6f} {:12.6f}".format(i, a[i,0], a[i,1], a[i,2]))
    print("        {:12.6f} {:12.6f} {:12.6f}".format(b[i,0], b[i,1], b[i,2]))
    print("        {:12.6f} {:12.6f} {:12.6f}".format(delta[i,0], delta[i,1], delta[i,2]))
isok = np.isclose(a, b, rtol, atol).all()
print("Delta Max {:5s} {:6d}/{:1d} {:8.2g}({:8.2g}) {:8.2g}%({:8.2g}%) {}".format(sys.argv[3], np.argmax(delta)//3, np.argmax(delta)%3, m, atol, mr, rtol*100, isok))

if isok:
    exit(0)
else:
    exit(1)