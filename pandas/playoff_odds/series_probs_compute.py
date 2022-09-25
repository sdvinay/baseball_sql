from scipy.stats import binom
import pandas as pd

# Directly compute probabilities of winning games and series

# This is 538's formula to convert an elo ratings differential into winning probability
# From https://fivethirtyeight.com/methodology/how-our-nfl-predictions-work/
# But I confirmed that that's what they use for baseball, too
def p_from_diff(diff):
    return 1/(10**(-diff/400)+1)


# Compute a probability for an individual game, including the HFA
def p_game(r_home, r_away):
    return p_from_diff(24 + r_home - r_away)


# Compute probability for a 3-game series, where all 3 games are at home for the team with HFA 
# Binomial chance of winning at least 2 of 3 when all games are at p_g
def p_series3(r_home, r_away):
    p_g = p_game(r_home, r_away)
    p_series = sum([binom.pmf(i, 3, p_g) for i in range(2, 4)])
    return p_series


# Generic function for any best-of-n, where n is an odd number,
# And the HFA team gets (n+1)/2 of those games at home
# Everything is from the POV of the team with HFA (e.g., p_gh is prob of that team winning at home)
def p_balanced_series(games, r_home, r_away):
    gms = {'H': int((games+1)/2)}
    gms['A'] = gms['H']-1

    p_g = {'H': p_game(r_home, r_away), 
           'A': 1 - p_game(r_away, r_home)
        }

    def get_distribution(num_games, p_g):
        return pd.Series({i: binom.pmf(i, num_games, p_g) for i in range(num_games+1)})

    dists = [get_distribution(gms[ha], p_g[ha]) for ha in ['H', 'A']]
    total = {(i,j): (i+j, dists[0][i]*dists[1][j]) for i in dists[0].keys() for j in dists[1].keys()}
    ps = pd.DataFrame(total).T.rename(columns = {0: 'w', 1: 'p'}).groupby('w')['p'].sum()
    return (ps[gms['H']:].sum())


# Now define funcs for 5 and 7 (for now, just to maintain compatibility with the notebook)
def p_series5(r_home, r_away):
    return p_balanced_series(5, r_home, r_away)


def p_series7(r_home, r_away):
    return p_balanced_series(7, r_home, r_away)

series_probs = {}
def p_series(games, r_home, r_away):
    key = (games, (r_home-r_away))
    if key not in series_probs:
        if games == 3:
            series_probs[key] = p_series3(r_home, r_away)
        else:
            series_probs[key] = p_balanced_series(games, r_home, r_away)
    return series_probs[key]