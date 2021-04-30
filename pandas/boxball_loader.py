import pandas as pd
from enum import Flag, auto
import os.path
import numpy as np


# Cache event data
def load_event_data(start_yr, end_yr, columns):
    hash_key = hash(tuple([start_yr, end_yr, tuple(columns)]))
    cache_filepath = f'../data/cache/event_{hash_key}.parquet'
    if os.path.isfile(cache_filepath):
        pa = pd.read_parquet(cache_filepath)
    else:
        required_cols = ['game_id', 'bat_event_fl', 'h_fl', 'event_cd']
        gm = pd.read_parquet('../data/mine/gamelog_enhanced.parquet')
        gms = gm[(gm['yr']>=start_yr) & (gm['yr']<=end_yr)][['game_id', 'date']]
        ev = pd.read_parquet('../data/retrosheet/event.parquet')[required_cols+columns]
        #pa = ev[(ev['game_id'].isin(gms.game_id) & (ev['bat_event_fl']))]
        pa = ev[ev['game_id'].isin(gms.game_id)]
        pa = pd.merge(left=gms, right=pa, on='game_id')
        pa = pa.rename(columns={'h_fl': 'tb_ct'})
        pa['h_fl'] = np.where(pa['tb_ct']>0, 1, 0)
        pa['ob_fl'] = np.where(pa['event_cd'].isin([14, 16, 20, 21, 22, 23]), 1, 0)
        pa['yr'] = pa['date'].apply (lambda dt: dt.year)
        pa.to_parquet(cache_filepath)
    return pa

def load_appearances():
    return pd.read_parquet('../data/baseballdatabank/appearances.parquet')

class GameType(Flag):
    RS = auto()
    PS = auto()
    ASG = auto()
    ALL = RS | PS | ASG
    
class PlayerRole(Flag):
    BAT = auto()
    PIT = auto()
    FLD = auto()
    


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


def get_cols_from_roles(player_roles):
    player_role_mapper = {PlayerRole.BAT: dailies_cols_bat, 
            PlayerRole.PIT: dailies_cols_pit, PlayerRole.FLD: dailies_cols_fld}
    cols = dailies_cols_standard + [role_cols for role, role_cols in player_role_mapper.items() if role & player_roles]
    return cols

# filter rows based on the requested game_types
def filter_on_game_types(df, game_types):
    game_type_mapper = {GameType.RS: 'RS', GameType.PS: 'PS', GameType.ASG: 'ASG'}
    gtstrs = [gtstr for gt, gtstr in game_type_mapper.items() if gt & game_types]
    gms = df[df['game_type'].isin(gtstrs)]
    return gms

# filter rows based on the requested years
def filter_on_years(df, years):
    return df[(df['yr'].isin(years))]

def load_gamelogs(game_types, years):
    df = pd.read_parquet('../data/mine/gamelog_enhanced.parquet')

    # filter rows based on the requested game_types
    rows = filter_on_game_types(filter_on_years(df, years), game_types)

    return rows


def load_dailies(game_types):
    df = pd.read_parquet('../data/mine/daily.parquet')
    
    # filter rows based on the requested game_types
    rows = filter_on_game_types(df, game_types)

    return rows

def load_dailies_bat():
        cols = dailies_cols_standard+dailies_cols_bat
        return load_dailies()[cols]
