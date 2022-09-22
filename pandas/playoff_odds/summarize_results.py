import pandas as pd
import numpy as np
import season_simulator as sim
import playoff_simulator as psim

# Weight each playoff seed, for various purposes
weights = {}
# Home-game likelihood.  Top 4 seeds get home games, bottom two have to win the wild card series
weights['home_game'] = dict(enumerate([1, 1, 1, 1, .44, .44], 1))

# Count the number of div/wc/playoff appearances by team from a set of results
def summarize_sim_results(df_results):
    counts = df_results.query('lg_rank <= 6').reset_index()[['team', 'lg_rank']].value_counts().unstack()
    wins = df_results.groupby('team')['W'].agg(['mean', 'max', 'min'])
    summary = pd.merge(left=wins, right=counts, on='team', how='left')
    for col in counts.columns:
        summary[col] = summary[col].fillna(0).astype(int)    

    summary['div_wins'] = summary[range(1, 4)].sum(axis=1)
    summary['playoffs'] = summary[range(1, 7)].sum(axis=1)
    
    # Generate a column for each set of weights defined
    for col in weights.keys():
        summary[col] = (summary[range(1,7)] * np.array(weights[col])).sum(axis=1)

    # Restructure the results, and download ratings for computing the post-season
    (wins, lg_ranks, tms_by_rank, wins_by_rank) = restructure_results(df_results)
    cur, remain = sim.get_games()
    ratings = remain[['team1', 'rating1_pre']].drop_duplicates().set_index('team1')['rating1_pre'].rename('rating').sort_values(ascending=False)

    # Compute pennant and championship shares
    pennant_shares = compute_pennant_shares(tms_by_rank, ratings)
    ws_shares = compute_ws_shares(pennant_shares, ratings, summary['mean'])
    summary['ws_shares'] = pd.Series(ws_shares)
    summary['ws_shares'] = summary['ws_shares'].fillna(0)
    
    return summary.sort_values(['ws_shares', 'mean'], ascending=[False, False])

def restructure_results(sim_results):
    wins = sim_results['W'].unstack(level='team')
    lg_ranks = sim_results['lg_rank'].unstack(level='team')
    tms_by_rank = sim_results[['lg', 'lg_rank']].reset_index().set_index(['run_id', 'lg', 'lg_rank'])['team'].unstack(level='lg_rank')
    wins_by_rank = sim_results.reset_index().set_index(['run_id', 'lg', 'lg_rank'])['W'].unstack(level='lg_rank')
    return (wins, lg_ranks, tms_by_rank, wins_by_rank)


# Compute pennant shares for all teams, by iterating over the possible playoff fields
def compute_pennant_shares(tms_by_rank, ratings):
    def compute_pennant_prob(field):
        seeds = dict(enumerate(field.name, 1))
        return pd.Series(psim.run_league(ratings, seeds))*field["count"]

    pennant_shares = {}
    for lg in ('N', 'A'):
        fields = tms_by_rank.query("lg==@lg").loc[:,1:6].value_counts().rename("count")
        pennant_shares[lg]  = pd.DataFrame(fields).apply(compute_pennant_prob, axis=1).fillna(0).sum()

    return pennant_shares


def compute_ws_shares(pennant_shares, ratings, wins):
    ws_shares = {}
    for a in pennant_shares['A'].index:
        for n in pennant_shares['N'].index:
            likelihood = pennant_shares['A'][a]/pennant_shares['A'].sum() * pennant_shares['N'][n]
            key_func = lambda tm: wins[tm]
            tms = sorted([a, n], key=key_func, reverse=True)
            p = psim.p_series7(ratings[tms[0]], ratings[tms[1]])
            ws_shares[tms[0]] = ws_shares.get(tms[0], 0) + (p * likelihood)
            ws_shares[tms[1]] = ws_shares.get(tms[1], 0) + ((1-p) * likelihood)

    return ws_shares