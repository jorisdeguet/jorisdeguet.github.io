from sgg.validation import cantilever_check, hook_stem_check


def test_cantilever_vs_beam_theory():
    r = cantilever_check(1.0)
    assert abs(r["defl_ratio"] - 1) < 0.05
    assert abs(r["stress_ratio"] - 1) < 0.12


def test_hook_stem_vs_beam_theory():
    r = hook_stem_check(1.0)
    assert abs(r["ratio"] - 1) < 0.10
