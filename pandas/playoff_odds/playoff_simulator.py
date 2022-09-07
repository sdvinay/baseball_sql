from scipy.stats import binom
import pandas as pd

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



series_funcs = {1: p_game, 3: p_series3, 5: p_series5, 7: p_series7}


def run_series(length, teams_l, teams_r, ratings, seeds):
    series_func = series_funcs[length]
    def run_scenario(sl, pl, sr, pr):
        s1 = sl if sl < sr else sr
        s2 = sl if sl > sr else sr
        p_this_matchup = pl * pr
        ps = series_func(ratings[seeds[s1]], ratings[seeds[s2]])
        return pd.Series({s1: p_this_matchup*ps, s2: p_this_matchup*(1-ps)})

    ps = [run_scenario(sl, pl, sr, pr) for (sl, pl) in teams_l.items() for (sr, pr) in teams_r.items()]
    return pd.concat(ps, axis=1).fillna(0).sum(axis=1)
            
def run_league(ratings, seeds):
    d1 = run_series(5, run_series(3, {3: 1}, {6: 1}, ratings, seeds), {2: 1}, ratings, seeds)
    d2 = run_series(5, run_series(3, {4: 1}, {5: 1}, ratings, seeds), {1: 1}, ratings, seeds)
    lcs = run_series(7, d1, d2, ratings, seeds)
    return {seeds[sd]: lcs[sd] for sd in seeds}

def run_playoffs(ratings, seeds1, seeds2):
    l1 = run_league(ratings, seeds1)
    l2 = run_league(ratings, seeds2)
    tms = list(seeds1.values()) + list(seeds2.values())
    
    def run_world_series(seeds):
        l1_probs = {sd: l1[tm] for (sd, tm) in seeds.items() if tm in l1.keys()}
        l2_probs = {sd: l2[tm] for (sd, tm) in seeds.items() if tm in l2.keys()}
        ws = run_series(7, l1_probs, l2_probs, ratings, seeds)
        return pd.Series({seeds[sd]: ws[sd] for sd in seeds}).rename('champ_prob').sort_values()

    # Until we get WS seeding right, just run it twice, with order of seeds then the other, and average everything
    # This will simulate a coin-flip for HFA.  Better than hard-coding in some bias.
    comb_seeds = [dict(enumerate((order), 1)) for order in (tms, tms[::-1])]
    return pd.concat([run_world_series(seeds) for seeds in comb_seeds], axis=1).mean(axis=1)