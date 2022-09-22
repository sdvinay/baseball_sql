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
    return standings


def break_tie(teams):
    match sorted(list(teams)):
        case  ['ATL', 'NYM']:
            return ['NYM', 'ATL']
    return sorted(list(teams))


# Merge in league structure, and compute playoff seeding
def process_sim_results(sim_results):
    sim_results['run_id'] = sim_results['job_id'].astype(int)*10000 + sim_results['iter']
    sim_results['wpct'] = sim_results['W'] / (sim_results['W'] + sim_results['L'])

    # Merge in the div/lg data
    sim_results = pd.merge(left=sim_results, right=league_structure, left_on='team', right_index=True)

    # Rather than model out all the tie-breakers, I'm assuming that they are all random (not exactly true, but close enough),
    # and so I'm just generating a random number for each team, and we break ties by comparing that random num for each of the tied teams.
    # This is *so* much simpler and faster than modeling all the different scenarios.
    # It might be worth modeling them out with 1-2 days left in the season, but for most of the season, I way prefer using the random num to break ties
    sim_results['rand'] = np.random.rand(len(sim_results))

    sim_results = sim_results.set_index(['run_id', 'team'])[['W', 'L', 'wpct', 'div', 'lg', 'rand']]

    # compute div_wins and playoff seeds
    add_division_winners(sim_results)
    add_lg_ranks(sim_results)

    return sim_results


def add_division_winners(sim_results):
    div_winners = sim_results.sort_values(['wpct', 'rand'], ascending=False).groupby(['run_id', 'div']).head(1).index
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
    sim_results['lg_rank'] = sim_results.sort_values(by=['div_win', 'wpct', 'rand'], ascending=False).groupby(['run_id', 'lg']).cumcount()+1
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


def sim_rem_games(remain: pd.DataFrame):
    # Figure out the winners and losers
    rands = np.random.rand(len(remain))
    winners = pd.Series(np.where(rands<remain['rating_prob1'], remain['team1'], remain['team2']))
    losers = pd.Series(np.where(rands>remain['rating_prob1'], remain['team1'], remain['team2']))

    # Compute and return the standings
    standings = pd.concat([winners.value_counts().rename('W'), losers.value_counts().rename('L')], axis=1)
    for col in standings.columns: # convert to int
        standings[col] = standings[col].fillna(0).astype(int)
    return standings


def finish_one_season(incoming_standings, remain):
    rem_standings = sim_rem_games(remain)
    full_standings = incoming_standings+rem_standings
    return full_standings

def sim_1_season(incoming_standings, remain, i):
    standings = finish_one_season(incoming_standings, remain)
    standings['iter'] = i
    standings = standings.reset_index().rename(columns={'index': 'team'}).set_index(['team', 'iter'])
    return standings

def sim_n_seasons(incoming_standings, remain, n):
    return pd.concat([sim_1_season(incoming_standings, remain, i) for i in range(n)])


def gather_results():
    sim_results = pd.concat([pd.read_feather(f'output/{filename}') for filename in os.listdir('output/')], axis=0)
    sim_results = sim_results.set_index(['run_id', 'team'])
    return sim_results
    
def main(num_seasons: int = 100, save_output: bool = True, id: str = 'foo', show_summary: bool = True):
    print(f'Simulating {num_seasons} seasons as ID {id}')
    (played, remain) = get_games()
    cur_standings = compute_standings(played)
    sim_results = sim_n_seasons(cur_standings, remain, num_seasons)
    sim_results['job_id'] = id

    if save_output:
        sim_results = process_sim_results(sim_results.reset_index())
        sim_results.reset_index().to_feather(f'output/{id}.feather')

if __name__ == "__main__":
    typer.run(main) 