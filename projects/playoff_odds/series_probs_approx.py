# Approximate the probabilities instead of computing them
# Based on the analysis in approximate_series_probs.ipynb

def p_series(games, r_home, r_away):
    consts = {3: {'intercept': 0.5487166161582245,
        'coeffs': [ 2.18372656e-03, -1.50440176e-06]},
        5: {'intercept': 0.5118946934380574,
        'coeffs': [ 2.77425761e-03, -2.80645606e-06]},
        7: {'intercept': 0.5096396566543989,
        'coeffs': [ 3.26422337e-03, -4.25017182e-06]}}

    diff = r_home - r_away
    diff_sq = abs(diff) * diff

    cs = consts[games]
    p = cs['intercept'] + diff * cs['coeffs'][0] + diff_sq * cs['coeffs'][1]
    return p