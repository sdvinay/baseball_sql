import pandas as pd

def get_games_impl():
    # Read in the 538 dataset, which has a row for each game in the current season (played or unplayed)
    #gms = pd.read_csv('https://projects.fivethirtyeight.com/mlb-api/mlb_elo_latest.csv')
    gms = pd.read_csv('../../data/538/mlb-elo/mlb_elo_latest.csv')

    # Split out the games that have been played vs those remaining
    played_cols = ['team1', 'team2', 'score1', 'score2']
    remain_cols = ['team1', 'team2', 'rating_prob1', 'rating1_pre', 'rating2_pre']
    played = gms.dropna(subset=['score1'])[played_cols] # games that have a score
    remain = gms.loc[gms.index.difference(played.index)][remain_cols].rename(columns={'rating_prob1': 'win_prob'}) # all other games
    ratings = get_ratings_impl(remain)
    return (played, remain, ratings)

def get_ratings_impl(games):
    def get_one_set_of_ratings(i):
        cols_in = [f'team{i}', f'rating{i}_pre']
        cols_out = ['team', 'rating']
        df = games[cols_in]
        df.columns = cols_out
        return df
    ratings = pd.concat([get_one_set_of_ratings(i) for i in (1,2)])
    ratings = ratings.drop_duplicates().set_index('team')['rating']
    return ratings.sort_values(ascending=False)

(cur, remain, ratings) = get_games_impl()

def get_games():
    return (cur, remain)

def get_ratings():
    return ratings


# This is the source data for the mapping of teams to divisions/leagues
def get_league_structure_impl():
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

league_structure = get_league_structure_impl()
