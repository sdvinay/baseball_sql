import pandas as pd

def get_games_impl():
    # Read in the 538 dataset, which has a row for each game in the current season (played or unplayed)
    gms = pd.read_csv('https://projects.fivethirtyeight.com/mlb-api/mlb_elo_latest.csv')
    #gms = pd.read_csv('../data/538/mlb-elo/mlb_elo_latest.csv')

    # Split out the games that have been played vs those remaining
    played = gms.dropna(subset=['score1']) # games that have a score
    remain = gms.loc[gms.index.difference(played.index)] # all other games
    ratings = get_ratings_impl(remain)
    return (played[['team1', 'team2', 'score1', 'score2']], remain[['team1', 'team2']], ratings)

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

