import pandas as pd
import numpy as np
import season_simulator as sim
import playoff_simulator as psim


# Count the number of div/wc/playoff appearances by team from a set of results
# Compute other probabilities (pennant, championship, home game)
def summarize_sim_results(df_results):
    counts = df_results.query('lg_rank <= 6').reset_index()[['team', 'lg_rank']].value_counts().unstack()
    wins = df_results.groupby('team')['W'].agg(['mean', 'max', 'min'])
    summary = pd.merge(left=wins, right=counts, on='team', how='left')
    for col in counts.columns:
        summary[col] = summary[col].fillna(0).astype(int)    


def augment_summary(summary, tms_by_rank):
    summary['div_wins'] = summary[[f'r{i}' for i in range(1, 4)]].sum(axis=1)
    summary['playoffs'] = summary[[f'r{i}' for i in range(1, 7)]].sum(axis=1)

    summary['mean'] = summary['sum']/summary['len']

    # Download ratings for computing the post-season
    _, remain = sim.get_games()
    ratings = remain[['team1', 'rating1_pre']].drop_duplicates().set_index('team1')['rating1_pre'].rename('rating').sort_values(ascending=False)

    # Compute pennant and championship shares
    pennant_shares = compute_pennant_shares(tms_by_rank, ratings)
    ws_shares = compute_ws_shares(pennant_shares, ratings, summary['mean'])
    summary['ws_shares'] = pd.Series(ws_shares)
    summary['ws_shares'] = summary['ws_shares'].fillna(0)

    # Compute home games
    # Play out the wild-card series
    summary['home_game'] = compute_home_game_prob(summary, tms_by_rank, ratings)

    cols = ['mean', 'max', 'min'] + [f'r{i}' for i in range(1, 7)] + ['div_wins', 'playoffs', 'ws_shares', 'home_game']
    return summary[cols].sort_values(['ws_shares', 'mean'], ascending=False)

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
        fields = tms_by_rank.query("lg==@lg")[[f'r{i}' for i in range(1, 7)]].value_counts().rename("count")
        pennant_shares[lg]  = pd.DataFrame(fields).apply(compute_pennant_prob, axis=1).fillna(0).sum()

    return pennant_shares


def compute_ws_shares(pennant_shares, ratings, wins):
    ws_shares = {}
    for a in pennant_shares['A'].index:
        for n in pennant_shares['N'].index:
            likelihood = pennant_shares['A'][a]/pennant_shares['A'].sum() * pennant_shares['N'][n]
            key_func = lambda tm: wins[tm]
            tms = sorted([a, n], key=key_func, reverse=True)
            p = psim.ssim.p_series(7, ratings[tms[0]], ratings[tms[1]])
            ws_shares[tms[0]] = ws_shares.get(tms[0], 0) + (p * likelihood)
            ws_shares[tms[1]] = ws_shares.get(tms[1], 0) + ((1-p) * likelihood)

    return ws_shares


# For estimating likelihood of home games, let's play out the first-round series
def compute_home_game_prob(summary, tms_by_rank, ratings):
    mapper = {f'r{i}': i for i in range(16)}
    summary = summary.rename(columns=mapper)
    tms_by_rank = tms_by_rank.rename(columns=mapper)

    # Top 4 seeds always get a home game
    top_4 = summary[range(1, 5)].sum(axis=1)

    # 5 and 6 need to advance in wild-card round
    mapper = {3: 'h', 4: 'h', 5: 'a', 6: 'a'}
    wc_series = pd.concat([tms_by_rank.loc[:,tms].rename(columns=mapper) for tms in ([3,6], [4,5])]).value_counts().rename('ct')

    def compute_advance_counts(series):
        p = 1-psim.ssim.p_series(3, ratings[series.name[0]], ratings[series.name[1]])
        return p * series['ct']

    advances = pd.DataFrame(wc_series).apply(compute_advance_counts, axis=1).groupby('a').sum()

    home_gms = top_4.add(advances, fill_value=0)
    return home_gms
