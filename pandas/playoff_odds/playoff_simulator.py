import pandas as pd
import series_probs_approx as ssim

# Compute probabilities of each team to win a playoff bracket
# By iterating through all possible matchups and their likelihood
# Implements 2022 MLB playoff format
# Depends on a series simulator (ssim) to compute/return probabilities for individual series


def run_series(length, teams_l, teams_r, ratings, seeds):
    def run_scenario(sl, pl, sr, pr):
        s1 = sl if sl < sr else sr
        s2 = sl if sl > sr else sr
        p_this_matchup = pl * pr
        ps = ssim.p_series(length, ratings[seeds[s1]], ratings[seeds[s2]])
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