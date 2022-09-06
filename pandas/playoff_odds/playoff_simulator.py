from scipy.stats import binom
import pandas as pd

import playoff_odds


def p_from_diff(diff):
    return 1/(10**(-diff/400)+1)

def p_game(r_home, r_away):
    return p_from_diff(24 + r_home - r_away)



def p_series3(r_home, r_away):
    p_g = p_game(r_home, r_away)
    
    # Binomial chance of winning at least 2 of 3 when all games are at p_g
    return sum([binom.pmf(i, 3, p_g) for i in range(2, 4)])


def p_series5(r_home, r_away):
    p_g1 = p_game(r_home, r_away)
    p_g2 = p_game(r_away, r_home)


    dist1 = pd.Series({i: binom.pmf(i, 3, p_g1) for i in range(0, 4)})
    dist2 = pd.Series({2-i: binom.pmf(i, 2, p_g2) for i in range(0, 3)})

    total = {(i,j): (i+j, dist1[i]*dist2[j]) for i in dist1.keys() for j in dist2.keys()}
    ps = pd.DataFrame(total).T.rename(columns = {0: 'w', 1: 'p'}).groupby('w')['p'].sum()
    return (ps[3:].sum())

def p_series7(r_home, r_away):
    p_g1 = p_game(r_home, r_away)
    p_g2 = p_game(r_away, r_home)


    dist1 = pd.Series({i: binom.pmf(i, 4, p_g1) for i in range(0, 5)})
    dist2 = pd.Series({3-i: binom.pmf(i, 3, p_g2) for i in range(0, 4)})

    total = {(i,j): (i+j, dist1[i]*dist2[j]) for i in dist1.keys() for j in dist2.keys()}
    ps = pd.DataFrame(total).T.rename(columns = {0: 'w', 1: 'p'}).groupby('w')['p'].sum()
    return (ps[4:].sum())


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
            
