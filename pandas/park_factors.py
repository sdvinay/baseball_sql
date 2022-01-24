import pandas as pd
import boxball_loader as bbl


years = range(2010, 2020)
stats = ['pa', 'runs_scored', 'hr', 's', 'd', 't', 'k', 'bb', 'ab']

agg_cols = stats + ['g', 'length_in_outs']

def get_gamelogs(years):
    # Narrow to years and regular-season games
    df = bbl.load_gamelogs(bbl.GameType.RS, years)

    # Add plate appearances and singles as stats we care about
    for HA in ['home', 'visitor']:
        df[f'{HA}_pa'] = df[f'{HA}_ab'] + df[f'{HA}_bb'] + df[f'{HA}_hbp'] + df[f'{HA}_sh'] + df[f'{HA}_sf']
        df[f'{HA}_s'] = df[f'{HA}_h'] - df[f'{HA}_d'] - df[f'{HA}_t'] - df[f'{HA}_hr']

    # These are the columns we care about
    standard_cols = ['yr', 'game_type', 'home_team', 'visiting_team', 'park_id', 'length_in_outs']
    stat_cols = [f'{HA}_{stat}' for HA in ['home', 'visitor'] for stat in stats]
    cols = standard_cols+stat_cols
    
    gl = df[cols].copy()
    gl['g'] = 1

    # For the stats, compute both teams' totals in each game
    for stat in stats:
        gl[stat] = gl['home_'+stat]+gl['visitor_'+stat]
    
    # Fix a bug in the Retrosheet data for the 2020 Rangers
    gl.loc[(gl['home_team']=='TEX')&(gl['yr']==2020), 'park_id'] = 'ARL03'
    
    return gl

# Find each teams-season's primary park (the park in which they played the most home games)
def find_primary_parks(gl):
    hgbp = gl.groupby(['yr', 'home_team', 'park_id'])['g'].sum() # home games per park
    primary_parks = hgbp[hgbp.groupby(['yr', 'home_team']).transform(max) == hgbp].reset_index(level=-1)['park_id']
    return primary_parks


# For each team-season, compute the totals in their home games and their road games
def compute_home_road_totals(gl):

    home_game_totals = gl.rename(columns={'home_team': 'tm'}).groupby(['yr', 'tm', 'park_id'])[agg_cols].sum().reset_index(level=-1)
    away_game_totals = gl.rename(columns={'visiting_team': 'tm'}).groupby(['yr', 'tm'])[agg_cols].sum()

    return home_game_totals, away_game_totals


def get_pfs(years, min_games = 0):
    gl = get_gamelogs(years)
    primary_parks = find_primary_parks(gl)

    # Choose only the games where the home team was playing in its primary park (discard the rest)
    g = pd.merge(left=gl, right=primary_parks.reset_index())

    home_game_totals, away_game_totals = compute_home_road_totals(g)

    # Merge home and away totals into one DF
    away_game_totals['park_id'] = home_game_totals['park_id']
    home_game_totals['HA'] = 'H'
    away_game_totals['HA'] = 'A'
    tm_seasons = pd.concat([df.reset_index().set_index(['yr', 'tm', 'park_id', 'HA']) for df in [home_game_totals, away_game_totals]] ) \
        .sort_values(by=['yr', 'tm', 'park_id', 'HA'])
    
    # Sum from team-seasons to park totals
    park_totals = tm_seasons.groupby(['park_id', 'HA']).sum()

    # Enforce min_games minimum
    park_totals = park_totals[park_totals['g'] > min_games]

    # Convert to rates relative to PA
    park_rates = park_totals[agg_cols].divide(park_totals['pa'], axis=0)

    # divide home rates by away rates to get observed park factors
    pr = park_rates.reset_index(level=-1)
    pfs = pr[pr['HA']=='H'][agg_cols]/pr[pr['HA']=='A'][agg_cols]

    return pfs