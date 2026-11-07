import numpy as np

from sgg.optimize import HI, LO, _poly_mut, _sbx, decode, encode
from sgg.hook import HookParams


def test_decode_encode_roundtrip_and_bounds():
    p = HookParams()
    assert decode(encode(p)) == p
    rng = np.random.default_rng(1)
    for _ in range(50):
        a, b = rng.random(6), rng.random(6)
        c1, c2 = _sbx(a, b, rng)
        for c in (c1, c2, _poly_mut(c1, rng, 0.5)):
            v = np.array(list(decode(c).to_dict().values()))
            assert (v >= LO - 1e-9).all() and (v <= HI + 1e-9).all()
