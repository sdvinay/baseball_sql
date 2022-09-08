# Functions that implement the logic for monte carlo playoff odds

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

# find playoff teams
def add_playoff_seeds(standings, randoms):
    standings['wpct'] = standings['W'] / (standings['W'] + standings['L'])

    # Merge in the div/lg data
    teams = get_league_structure()
    standings['div'] = teams['div']
    standings['lg'] = teams['lg']

    # Rather than model out all the tie-breakers, I'm assuming that they are all random (not exactly true, but close enough),
    # and so I'm just generating a random number for each team, and we break ties by comparing that random num for each of the tied teams.
    # This is *so* much simpler and faster than modeling all the different scenarios.
    # It might be worth modeling them out with 1-2 days left in the season, but for most of the season, I way prefer using the random num to break ties
    rands = randoms[0:len(standings)]
    rands.index = standings.index
    standings['rand'] = rands

    # Now sort, and break ties using the rand
    sorted = standings.sort_values(by=['wpct', 'rand'], ascending=False)

    # div_rank is nice to have, but somewhat expensive to compute
    #standings['div_rank'] = sorted.groupby('div').cumcount()+1
    #standings['div_win'] = standings['div_rank'] == 1

    # Set div_win False as default, then set it True for div winners
    standings['div_win'] = False
    standings.loc[sorted.groupby('div').head(1).index, 'div_win'] = True
    standings['lg_rank'] = standings.sort_values(by=['div_win', 'wpct', 'rand'], ascending=False).groupby('lg').cumcount()+1
    return standings.sort_values(['lg', 'lg_rank'])


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

    divs = {line.strip().split(': ')[0]: line.split(': ')[1].split(' ') for line in div_text.strip().split('\n')}
    teams = pd.DataFrame(pd.concat([pd.Series({team: div for team in teams}) for (div, teams) in divs.items()]).rename('div'))
    teams['lg'] = teams['div'].str[0]
    return teams


# Weight each playoff seed, for various purposes
weights = {}
# Championship weights by seed position
weights['champ_shares'] = dict(enumerate([.135, .13, .07, .065, .05, .05], 1))
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
    return summary


# Repeatable random inputs
random_inputs = {}
NUM_RANDOMS_PER_ITERATION = 1200
def get_randoms(iteration: int) -> pd.Series:
    if iteration not in random_inputs:
        # Generate a random number for each game
        randoms = pd.Series(np.random.rand(NUM_RANDOMS_PER_ITERATION))
        random_inputs[iteration] = randoms
    
    return random_inputs[iteration]


def sim_rem_games(remain: pd.DataFrame, randoms: pd.Series):
    # Figure out the winners and losers
    rands = randoms[0:len(remain)]
    rands.index = remain.index
    winners = pd.Series(np.where(rands<remain['rating_prob1'], remain['team1'], remain['team2']))
    losers = pd.Series(np.where(rands>remain['rating_prob1'], remain['team1'], remain['team2']))

    # Compute and return the standings
    standings = pd.concat([winners.value_counts().rename('W'), losers.value_counts().rename('L')], axis=1)
    for col in standings.columns: # convert to int
        standings[col] = standings[col].fillna(0).astype(int)
    return standings


def finish_one_season(incoming_standings, remain, randoms):
    rem_standings = sim_rem_games(remain, randoms)
    full_standings = incoming_standings+rem_standings
    full_standings = add_playoff_seeds(full_standings, randoms)
    return full_standings

def sim_1_season(incoming_standings, remain, i):
    randoms = get_randoms(i)
    standings = finish_one_season(incoming_standings, remain, randoms)
    standings['iter'] = i
    standings = standings.reset_index().rename(columns={'index': 'team'}).set_index(['team', 'iter'])
    return standings

def sim_n_seasons(incoming_standings, remain, n):
    return pd.concat([sim_1_season(incoming_standings, remain, i) for i in range(n)])

def sim_one_way(incoming_standings, game_id, prob, num_iterations, remain):
    orig_prob = remain.loc[game_id, 'rating_prob1']
    remain.loc[game_id, 'rating_prob1'] = prob
    sim_results = sim_n_seasons(incoming_standings, remain, num_iterations)
    remain.loc[game_id, 'rating_prob1'] = orig_prob
    results = summarize_sim_results(sim_results)
    wp1 = results['champ_shares'].rename(f'{prob}')
    return wp1


def sim_both_ways(incoming_standings, game_id, num_iterations, remain):
    results = pd.concat([sim_one_way(incoming_standings, game_id, prob, num_iterations, remain) for prob in [0, 1]], axis=1)

    team1 = remain.loc[game_id, 'team1']
    diff = (results['1'] - results['0']).rename(game_id)
    return diff


def main(num_trials: int = 100, save_output: bool = True, id: str = 'foo'):
    print(f'Simulating {num_trials} seasons as ID {id}')
    (played, remain) = get_games()
    cur_standings = compute_standings(played)
    sim_results = sim_n_seasons(cur_standings, remain, num_trials)
    summary = summarize_sim_results(sim_results)
    print(summary.sort_values('champ_shares', ascending=False).to_string())

    if save_output:
        sim_results.reset_index().to_feather(f'output/{id}.feather')

if __name__ == "__main__":
    typer.run(main) 