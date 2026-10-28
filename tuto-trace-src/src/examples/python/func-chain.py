def doubler(x):
    return x * 2

def quadruple(x):
    d = doubler(x)
    return doubler(d)

print(quadruple(5))
