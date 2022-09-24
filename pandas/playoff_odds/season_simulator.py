# Functions that implement the logic for monte carlo playoff odds

import os
import typer
import pandas as pd
import numpy as np

def get_games():
    # Read in the 538 dataset, which has a row for each game in the current season (played or unplayed)
    gms = pd.read_csv('https://projects.fivethirtyeight.com/mlb-api/mlb_elo_latest.csv')
    #gms = pd.read_csv('../data/538/mlb-elo/mlb_elo_latest.csv')

    # Split out the games that have been played vs those remaining
    played = gms.dropna(subset=['score1']) # games that have a score
    remain = gms.loc[gms.index.difference(played.index)] # all other games
    return (played, remain)

def compute_standings(gms_played):
    margins = gms_played['score1']-gms_played['score2']
    winners = pd.Series(np.where(margins>0, gms_played['team1'], gms_played['team2']))
    losers  = pd.Series(np.where(margins<0, gms_played['team1'], gms_played['team2']))
    standings = pd.concat([winners.value_counts().rename('W'), losers.value_counts().rename('L')], axis=1)
    standings.index.name = 'team'
    return standings

(cur, remain) = get_games()

def h2h_standings(games, teams):
    return compute_standings(games.query('team1 in @teams and team2 in @teams'))


tie_breakers = {}
def break_tie(teams):
    tm_key = tuple(sorted(list(teams)))
    if tm_key not in tie_breakers:
        standings = h2h_standings(cur, teams)
        tie_breakers[tm_key] = standings.index.values
    return tie_breakers[tm_key]

tie_breakers = {}
def break_tie(teams):
    tm_key = tuple(sorted(list(teams)))
    if tm_key not in tie_breakers:
        standings = h2h_standings(cur, teams)
        tie_breakers[tm_key] = standings.index.values
    return tie_breakers[tm_key]

# Merge in league structure, and compute playoff seeding
def process_sim_results(sim_results):
    sim_results['run_id'] = sim_results['job_id'].astype(int)*10000 + sim_results['iter']
    sim_results['wpct'] = sim_results['W'] / (sim_results['W'] + sim_results['L'])

    # Merge in the div/lg data
    sim_results = pd.merge(left=sim_results, right=league_structure, left_on='team', right_index=True)
    sim_results = sim_results.set_index(['run_id', 'team'])[['W', 'L', 'wpct', 'div', 'lg']]

    # compute div_wins and playoff seeds
    add_division_winners(sim_results)
    add_lg_ranks(sim_results)

    return sim_results

def summarize_results(standings):
    counts = standings.reset_index()[['team', 'lg_rank']].value_counts().unstack()
    wins = standings.groupby('team')['W'].agg(['sum', 'max', 'min', len])
    summary = pd.merge(left=wins, right=counts, on='team', how='left')
    for col in counts.columns:
        summary[col] = summary[col].fillna(0).astype(int)
    return summary.rename(columns={i: f'r{i}' for i in range(100)})


def compute_standings_from_results(sim_results, incoming_standings):
    standings = pd.concat([sim_results.groupby('iter')[col].value_counts().rename(col) for col in ('W', 'L')], axis=1)
    standings.index.names = ['iter', 'team']
    for col in standings.columns:
        standings[col] = standings[col].fillna(0).astype(int)

    iters = standings.reset_index()['iter'].unique()
    stds_iterated = pd.concat([incoming_standings] * len(iters))
    stds_iterated['iter'] = np.concatenate([np.repeat(i, len(incoming_standings)) for i in iters])
    stds_iterated = stds_iterated.reset_index().set_index(['iter', 'team'])
    full_standings = stds_iterated + standings
    return full_standings

def add_division_winners(sim_results):
    sim_results['div_win'] = False

    div_leading_wpct = sim_results.groupby(['run_id', 'div'])['wpct'].transform(max)
    potential_div_winners = sim_results.query('wpct == @div_leading_wpct')
    tied_team_ct = potential_div_winners.reset_index()[['run_id', 'div']].value_counts().rename("tied_teams")
    potential_div_winners = pd.merge(left=potential_div_winners.reset_index(), right=tied_team_ct, on=['run_id', 'div']).set_index(['run_id', 'team'])
    # outright division winners
    outright_div_winners = potential_div_winners.query('tied_teams==1').index
    sim_results.loc[outright_div_winners, 'div_win'] = True
    # ties
    tied_teams = potential_div_winners.query('tied_teams>1').reset_index()
    tied_sets = tied_teams.groupby(['run_id', 'div'])['team'].apply(set)
    tie_winners = tied_sets.apply(lambda tms: break_tie(tms)[0]).reset_index().set_index(['run_id', 'team']).index
    sim_results.loc[tie_winners, 'div_win'] = True
    return sim_results


def add_lg_ranks(sim_results):
    sim_results['tiebreak'] = 0
    tied_tm_ct = sim_results.groupby(['run_id', 'lg', 'wpct'])['wpct'].transform('size')
    tied_sets = sim_results[tied_tm_ct>1].reset_index().groupby(['run_id', 'lg', 'wpct'])['team'].apply(set)
    tie_orders = tied_sets.apply(lambda tms: break_tie(tms)).explode()
    tiebreak = (15 - tie_orders.groupby(['run_id', 'lg', 'wpct']).cumcount())
    sim_results['tiebreak'] = pd.concat([tie_orders, tiebreak], axis=1).reset_index().set_index(['run_id', 'team'])[0]
    sim_results['lg_rank'] = sim_results.sort_values(by=['div_win', 'wpct', 'tiebreak'], ascending=False).groupby(['run_id', 'lg']).cumcount()+1
    return sim_results


# This is the source data for the mapping of teams to divisions/leagues
def get_league_structure():
    div_text = '''
    NLW: ARI COL LAD SDP SFG
    NLE: ATL FLA NYM PHI WSN
    ALW: SEA ANA HOU OAK TEX
    ALE: TBD TOR BAL NYY BOS
    ALC: MIN CHW CLE KCR DET
    NLC: STL MIL CHC PIT CIN
    '''

    lines = [line.strip().split(': ') for line in div_text.strip().split('\n')]
    div_map = {l[0]: l[1].split(' ') for l in lines} # a map of div names to lists of team names
    div = pd.concat([pd.Series({team: div for team in teams}) for (div, teams) in div_map.items()])
    teams = pd.DataFrame()
    teams['div'] = div
    teams['lg'] = teams['div'].str[0]
    return teams

league_structure = get_league_structure()


def sim_n_seasons(games, n):
    gms = pd.concat([games[['team1', 'team2', 'rating_prob1']]] * n)
    gms['iter'] = np.concatenate([np.repeat(i, len(games)) for i in range(n)])

    rands = np.random.rand(len(gms))
    gm_results = np.where(rands<gms['rating_prob1'], (gms['team1'], gms['team2'], gms['iter']), (gms['team2'], gms['team1'], gms['iter']))
    results = pd.DataFrame(gm_results).T
    results.columns = ['W', 'L', 'iter']
    return results

def get_tm_ranks(standings):
    tms_by_rank = standings[['lg', 'lg_rank']].reset_index().set_index(['run_id', 'lg', 'lg_rank'])['team'].unstack(level='lg_rank')
    return tms_by_rank.rename(columns={i: f'r{i}' for i in range(100)})

def gather_results():
    sim_results = pd.concat([pd.read_feather(f'output/standings/{filename}') for filename in os.listdir('output/standings/')], axis=0)
    sim_results = sim_results.set_index(['run_id', 'team'])
    return sim_results

def gather_ranks():
    ranks = pd.concat([pd.read_feather(f'output/ranks/{filename}') for filename in os.listdir('output/ranks/')], axis=0)
    ranks = ranks.set_index(['run_id', 'lg'])
    return ranks


def gather_summaries():
    summaries = pd.concat([pd.read_feather(f'output/summaries/{filename}') for filename in os.listdir('output/summaries/')], axis=0)
    summary = summaries.groupby('team').sum()
    summary['max'] = summaries.groupby('team')['max'].max()
    summary['min'] = summaries.groupby('team')['min'].min()
    return summary
    
def main(num_seasons: int = 100, save_output: bool = False, save_summary: bool = True, save_ranks: bool = True, id: int = 0, show_summary: bool = True):
    print(f'Simulating {num_seasons} seasons as ID {id}')
    (played, remain) = get_games()
    cur_standings = compute_standings(played)
    sim_results = sim_n_seasons(remain, num_seasons)
    sim_results['job_id'] = id

    standings = compute_standings_from_results(sim_results, cur_standings)
    standings['job_id'] = id
    standings = process_sim_results(standings.reset_index())

    if save_output:
        standings.reset_index().to_feather(f'output/standings/{id}.feather')

    if save_summary:
        summary = summarize_results(standings)
        summary.reset_index().to_feather(f'output/summaries/{id}.feather')

    if save_ranks:
        tms_by_rank = get_tm_ranks(standings)
        tms_by_rank.reset_index().to_feather(f'output/ranks/{id}.feather')

if __name__ == "__main__":
    typer.run(main) 