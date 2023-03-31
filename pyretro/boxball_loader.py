from enum import Flag, auto

import os.path
from typing import List, Sequence

import datetime
import pandas as pd
import numpy as np

# for caching, we need consistent hash keys, via pickle/hashlib
import pickle
import hashlib

BASE_DATA_DIR = '/Users/vinay/dev/baseball_sql/data'
RETROSHEET_DIR = f'{BASE_DATA_DIR}/retrosheet/2022'
BASEBALL_DATABANK_DIR = f'{BASE_DATA_DIR}/baseballdatabank/2022'

class GameType(Flag):
    RS = auto()
    PS = auto()
    ASG = auto()
    ALL = RS | PS | ASG
    
class PlayerRole(Flag):
    BAT = auto()
    PIT = auto()
    FLD = auto()
    
class PlayerType(Flag):
    PITCHER = auto()
    POSITION = auto()
    ALL = PITCHER | POSITION


class Seasons(List):
    def __init__(self, first_yr: int, last_yr: int = None) -> None:
        seq = range(first_yr, last_yr+1) if last_yr else [first_yr] 
        super().__init__(seq)

    MIN_YEAR = 1800
    MAX_YEAR = 2022

class Eras:
        All = Seasons(Seasons.MIN_YEAR, Seasons.MAX_YEAR)
        ALNL = Seasons(1901, Seasons.MAX_YEAR)
        Integration = Seasons(1947, Seasons.MAX_YEAR)
        Expansion = Seasons(1961, Seasons.MAX_YEAR)
        PitchCount = Seasons(1988, Seasons.MAX_YEAR)
        Interleague = Seasons(1997, Seasons.MAX_YEAR)
        ThirtyTeams = Seasons(1998, Seasons.MAX_YEAR)
        ThirtyTeams162 = Seasons(1998, 2019)
        
        def since(year: int) -> Seasons:
            return Seasons(year, Seasons.MAX_YEAR)


class CoalesceMode(Flag):
    PLAYER_CAREER = auto()
    PLAYER_SEASON = auto()
    PLAYER_SEASON_LEAGUE = auto()
    PLAYER_SEASON_TEAM = auto()
    PLAYER_SEASON_STINT = auto()
    PLAYER_CAREER_FRANCHISE = auto()
    PLAYER_CAREER_LEAGUE = auto()
    SEASON_TEAM = auto()
    NONE = PLAYER_SEASON_STINT

CoalesceMode_Groupby = {
    CoalesceMode.PLAYER_CAREER: ['player_id'],
    CoalesceMode.PLAYER_SEASON: ['player_id', 'yr'],
    CoalesceMode.PLAYER_SEASON_LEAGUE: ['player_id', 'yr', 'lg_id'],
    CoalesceMode.PLAYER_SEASON_TEAM: ['player_id', 'yr', 'team_id', 'franch_id'],
    CoalesceMode.PLAYER_CAREER_FRANCHISE: ['player_id', 'franch_id'],
    CoalesceMode.PLAYER_CAREER_LEAGUE: ['player_id', 'lg_id'],
    CoalesceMode.SEASON_TEAM: ['yr', 'team_id', 'lg_id', 'franch_id']
}


def fixup_event_data(df: pd.DataFrame) -> pd.DataFrame:
    pa = df
    pa = pa.rename(columns={'h_fl': 'tb_ct'})
    pa['h_fl'] = np.where(pa['tb_ct']>0, 1, 0)
    pa['ob_fl'] = np.where(pa['event_cd'].isin([14, 16, 20, 21, 22, 23]), 1, 0)
    pa['yr'] = pa['date'].dt.year
    return pa

def get_cache_filename(type, hash_key):
    s = pickle.dumps(hash_key)
    hash_val = hashlib.sha224(s).hexdigest()
    cache_filepath = f'{BASE_DATA_DIR}/cache/{type}_{hash_val}.parquet'
    return cache_filepath
    

# Cache event data
def load_event_data(seasons: Seasons, requested_columns: Sequence[str], pa_only=True, game_types=GameType.RS) -> pd.DataFrame:
    required_cols = ['game_id', 'date', 'yr', 'game_type', 'bat_event_fl', 'h_fl', 'event_cd', 'ab_fl']
    columns = list(set(required_cols+requested_columns))
    hash_key = (tuple([seasons, tuple(sorted(columns))]))
    cache_filepath = get_cache_filename('event', hash_key)
    if os.path.isfile(cache_filepath):
        ev = pd.read_parquet(cache_filepath)
    else:
        def load_event_data_season(season: int, columns: Sequence[str]) -> pd.DataFrame:
            ev_yr = pd.read_parquet(f'{RETROSHEET_DIR}/event_yearly/event_{season}.parquet')[columns]
            return ev_yr
        ev = pd.concat([load_event_data_season(yr, columns) for yr in seasons])
        ev.to_parquet(cache_filepath)

    ev = ev[ev['bat_event_fl']] if pa_only else ev
    ev = filter_on_game_types(ev, game_types)
    return ev

def load_appearances() -> pd.DataFrame:
    return pd.read_parquet(f'{BASEBALL_DATABANK_DIR}/appearances.parquet')

def load_people() -> pd.DataFrame:
    return pd.read_parquet(f'{BASEBALL_DATABANK_DIR}/people.parquet')

def load_managers() -> pd.DataFrame:
    return pd.read_parquet(f'{BASEBALL_DATABANK_DIR}/managers.parquet')

def load_hall_of_famers() -> pd.DataFrame:
    df = pd.read_csv(f'{BASE_DATA_DIR}/bbref/hof.csv')

    # The 'Name' field actually contains both a name and ID, so split those out
    spl = df['Name'].str.split('\\', expand=True)
    df['bbref_id'] = spl[1]
    df['Name'] = spl[0]

    return df

dailies_cols_standard = ['game_id', 'game_dt', 'game_ct', 'appearance_dt', 'team_id',
       'player_id', 'slot_ct', 'seq_ct', 'home_fl', 'opponent_id',
       'park_id', 'yr', 'game_type', 'team_game_number']
                         
dailies_cols_bat = ['b_g', 'b_pa', 'b_ab', 'b_r', 'b_h', 'b_tb', 'b_2b',
       'b_3b', 'b_hr', 'b_hr4', 'b_rbi', 'b_gw', 'b_bb', 'b_ibb', 'b_so',
       'b_gdp', 'b_hp', 'b_sh', 'b_sf', 'b_sb', 'b_cs', 'b_xi', 'b_g_dh',
       'b_g_ph', 'b_g_pr']

dailies_cols_pit = ['p_g', 'p_gs', 'p_cg', 'p_sho', 'p_gf', 'p_w',
       'p_l', 'p_sv', 'p_out', 'p_tbf', 'p_ab', 'p_r', 'p_er', 'p_h',
       'p_tb', 'p_2b', 'p_3b', 'p_hr', 'p_hr4', 'p_bb', 'p_ibb', 'p_so',
       'p_gdp', 'p_hp', 'p_sh', 'p_sf', 'p_xi', 'p_wp', 'p_bk', 'p_ir',
       'p_irs', 'p_go', 'p_ao', 'p_pitch', 'p_strike']

dailies_cols_fld = ['f_p_g', 'f_p_gs',
       'f_p_out', 'f_p_tc', 'f_p_po', 'f_p_a', 'f_p_e', 'f_p_dp',
       'f_p_tp', 'f_c_g', 'f_c_gs', 'f_c_out', 'f_c_tc', 'f_c_po',
       'f_c_a', 'f_c_e', 'f_c_dp', 'f_c_tp', 'f_c_pb', 'f_c_xi', 'f_1b_g',
       'f_1b_gs', 'f_1b_out', 'f_1b_tc', 'f_1b_po', 'f_1b_a', 'f_1b_e',
       'f_1b_dp', 'f_1b_tp', 'f_2b_g', 'f_2b_gs', 'f_2b_out', 'f_2b_tc',
       'f_2b_po', 'f_2b_a', 'f_2b_e', 'f_2b_dp', 'f_2b_tp', 'f_3b_g',
       'f_3b_gs', 'f_3b_out', 'f_3b_tc', 'f_3b_po', 'f_3b_a', 'f_3b_e',
       'f_3b_dp', 'f_3b_tp', 'f_ss_g', 'f_ss_gs', 'f_ss_out', 'f_ss_tc',
       'f_ss_po', 'f_ss_a', 'f_ss_e', 'f_ss_dp', 'f_ss_tp', 'f_lf_g',
       'f_lf_gs', 'f_lf_out', 'f_lf_tc', 'f_lf_po', 'f_lf_a', 'f_lf_e',
       'f_lf_dp', 'f_lf_tp', 'f_cf_g', 'f_cf_gs', 'f_cf_out', 'f_cf_tc',
       'f_cf_po', 'f_cf_a', 'f_cf_e', 'f_cf_dp', 'f_cf_tp', 'f_rf_g',
       'f_rf_gs', 'f_rf_out', 'f_rf_tc', 'f_rf_po', 'f_rf_a', 'f_rf_e',
       'f_rf_dp', 'f_rf_tp']

# add franchise IDs to a DF, matching on 'year_id'
#   and either 'team_id' (for baseball_databank) or 'team' (for retrosheet)
def add_franchise_ids(df) -> pd.DataFrame:
    teams = load_teams()
    
    teams_bd = teams[['yr', 'team_id', 'franch_id']]
    merged_bd = pd.merge(left=df, right=teams_bd)
    if len(merged_bd) == len(df):
        return merged_bd

    teams_retro = teams[['yr', 'team_id_retro', 'franch_id']] \
				  .rename(columns={'team_id_retro': 'team'})
    merged_retro = pd.merge(left=df, right=teams_retro)
    if len(merged_retro) == len(df):
        return merged_retro
    else:
        return None


def get_cols_from_roles(player_roles: PlayerRole):
    player_role_mapper = {PlayerRole.BAT: dailies_cols_bat, 
            PlayerRole.PIT: dailies_cols_pit, PlayerRole.FLD: dailies_cols_fld}
    cols = dailies_cols_standard + [role_cols for role, role_cols in player_role_mapper.items() if role & player_roles]
    return cols

# filter rows based on the requested game_types
def filter_on_game_types(df, game_types: GameType) -> pd.DataFrame:
    game_type_mapper = {GameType.RS: 'RS', GameType.PS: 'PS', GameType.ASG: 'ASG'}
    gtstrs = [gtstr for gt, gtstr in game_type_mapper.items() if gt & game_types]
    filtered = df[df['game_type'].isin(gtstrs)]
    return filtered

# filter rows based on the requested years
def filter_on_years(df, seasons: Seasons) -> pd.DataFrame:
    return df[(df['yr'].isin(seasons))]

# filter rows based on the requested player_type
def filter_on_player_types(df, player_types: PlayerType) -> pd.DataFrame:
    if player_types == PlayerType.ALL:
        return df

    non_pitchers = get_non_pitchers()
    non_pit_rows = df['player_id'].isin(get_non_pitchers())
    if player_types == PlayerType.POSITION:
        non_pits = df[df['player_id'].isin(get_non_pitchers())]
        return non_pits

    if player_types == PlayerType.PITCHER:
        pits = df[~df['player_id'].isin(get_non_pitchers())]
        return pits


def load_gamelogs(game_types: GameType, seasons: Seasons) -> pd.DataFrame:
    df = pd.read_parquet(f'{BASE_DATA_DIR}/mine/gamelog_enhanced.parquet')

    # filter rows based on the requested game_types
    rows = filter_on_game_types(filter_on_years(df, seasons), game_types)

    return rows


# identify non-pitchers

def get_non_pitchers() -> pd.DataFrame:
    apps = load_appearances()
    career_apps = apps.groupby('player_id')[['g_all', 'g_p']].sum()
    non_pitchers = career_apps[(career_apps['g_all']>2*career_apps['g_p'])].index
    return non_pitchers

def load_gamelog_teams(game_types: GameType, seasons: Seasons) -> pd.DataFrame:
    df = pd.read_parquet(f'{BASE_DATA_DIR}/mine/gl_teams.parquet')

    # filter rows based on the requested game_types
    rows = filter_on_game_types(filter_on_years(df, seasons), game_types)

    return rows

def load_people() -> pd.DataFrame:
    df = pd.read_parquet(f'{BASEBALL_DATABANK_DIR}/people.parquet')
    return df


def load_teams() -> pd.DataFrame:
    df = pd.read_parquet(f'{BASEBALL_DATABANK_DIR}/teams.parquet')
    return df.rename(columns={'year_id': 'yr'})

def load_annual_stats(stat_type: str, seasons: Seasons = Eras.All, player_types=PlayerType.ALL, coalesce_type=CoalesceMode.NONE, drop_cols = []) -> pd.DataFrame:
    parquet_file = f'{BASEBALL_DATABANK_DIR}/{stat_type}.parquet'
    df = pd.read_parquet(parquet_file)
    df = df.rename(columns={'year_id': 'yr'})
    df = filter_on_years(df, seasons)
    df = filter_on_player_types(df, player_types)
    if stat_type == 'pitching':  # Fix defect in BFP data for some Federal League pitchers
        df.loc[(df['bfp']==0)&(df['lg_id']=='FL'), 'bfp'] = np.NaN
    if len(drop_cols) > 0:
        df = df.dropna(subset = drop_cols)
    cols = df.columns[5:]
    df = add_franchise_ids(df)
    for col in cols:
        if df[col].isna().sum() == 0:
            df[col] = df[col].astype(int)
    if coalesce_type != CoalesceMode.NONE:
        df = df.groupby(CoalesceMode_Groupby[coalesce_type])[cols].sum()

    return df


def load_batting(seasons: Seasons = Eras.All, player_types=PlayerType.ALL, coalesce_type=CoalesceMode.NONE, drop_cols=[]) -> pd.DataFrame:
    return load_annual_stats('batting', seasons, player_types, coalesce_type, drop_cols)


def load_pitching(seasons: Seasons = Eras.All, player_types=PlayerType.ALL, coalesce_type=CoalesceMode.NONE, drop_cols=[]) -> pd.DataFrame:
    return load_annual_stats('pitching', seasons, player_types, coalesce_type, drop_cols)


def load_gamelog_starters(game_types, seasons: Seasons = Eras.All) -> pd.DataFrame:
    df = pd.read_parquet(f'{BASE_DATA_DIR}/mine/gl_starters.parquet')

    # filter rows based on the requested game_types
    rows = filter_on_game_types(filter_on_years(df, seasons), game_types)

    return rows


def load_dailies(game_types: GameType) -> pd.DataFrame:
    df = pd.read_parquet(f'{BASE_DATA_DIR}/mine/daily.parquet')
    
    # filter rows based on the requested game_types
    rows = filter_on_game_types(df, game_types)

    return rows

def load_dailies_bat(game_types: GameType) -> pd.DataFrame:
        cols = dailies_cols_standard+dailies_cols_bat
        return load_dailies(game_types)[cols]

def load_dailies_pit(game_types: GameType) -> pd.DataFrame:
        cols = dailies_cols_standard+dailies_cols_pit
        df = load_dailies(game_types)[cols]
        return df[df['p_g']>0]

def get_event_code_descriptions() -> pd.DataFrame:
    df = pd.read_parquet(f'{RETROSHEET_DIR}/code_event.parquet').set_index('code')
    return df


def load_birthdates(idx_field: str = 'player_id') -> pd.Series:
    birthdate_cols = ['birth_year', 'birth_month', 'birth_day']
    def compute_birthdate(person):
        dt = datetime.datetime(*[int(person[col]) for col in birthdate_cols]).date()
        return pd.to_datetime(dt)

    ppl = load_people().set_index(idx_field)[birthdate_cols].dropna()
    birthdates = ppl.apply(compute_birthdate, axis=1).rename('birthdate')
    return birthdates

