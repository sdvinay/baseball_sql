import pandas as pd
import boxball_loader as bbl

def create_bbref_boxscore_url(game_id):
    return f'https://www.baseball-reference.com/boxes/{game_id[0:3]}/{game_id}.shtml'

def get_player_names_df(df: pd.DataFrame, idx_fld: str):
    ppl = bbl.load_people()
    ppl['name'] = ppl['name_first']+ ' ' + ppl['name_last']
    merged = pd.merge(left=df, right=ppl[[idx_fld, 'name']]
                      , left_index=True, right_on=idx_fld)
    return merged.set_index(idx_fld)['name']

def get_player_names_col(s: pd.Series, idx_fld: str):
    ppl = bbl.load_people()
    ppl['name'] = ppl['name_first']+ ' ' + ppl['name_last']
    left = s.reset_index()
    right = ppl[[idx_fld, 'name']]
    merged = pd.merge(left, right, how='left', left_on=s.name, right_on=idx_fld).set_index('index')
    return merged['name']

def get_player_names_idx(i: pd.Index, idx_fld: str):
    s = pd.Series(i).rename(idx_fld)
    nms = get_player_names_col(s, idx_fld)
    nms.index = i
    return nms


# This function will group a DF of PAs by some field(s) (e.g., inning, time through lineup),
# and return a DF with computed totals and rate stats
def summarize_events(pa, groupby):
    groups = pa.groupby(groupby)

    # These stats already have a column in the event table
    column_map = {'bat_event_fl': 'pa', 'ob_fl': 'ob', 'ab_fl': 'ab', 'h_fl': 'h', 'tb_ct': 'tb'}
    columns = list(column_map.keys())
    optimistic_columns = ['event_re', 're_predicted']
    columns += [col for col in optimistic_columns if col in pa.columns]
    sums = groups[columns].sum().rename(columns=column_map)

    # These stats are counts of the event code
    event_cd_mapper = {3: 'k', 14: 'bb', 15: 'ibb', 23: 'hr'}
    event_cds = [k for k in event_cd_mapper.keys() if k in pa['event_cd'].unique()]
    counts = groups['event_cd'].value_counts().unstack()[event_cds].rename(columns=event_cd_mapper)
    for col in event_cd_mapper.values():
        if col not in counts.columns:
            counts[col] = 0
        counts[col] = counts[col].fillna(0).astype(int)

    # Combine and add rate stats
    stats = pd.concat([sums, counts], axis=1)
    stats['ba'] = stats['h']/stats['ab']
    stats['obp'] = stats['ob']/stats['pa']
    stats['slg'] = stats['tb']/stats['ab']
    stats['woba'] = get_woba(stats)
    for stat in ['k', 'bb', 'hr']:
        stats[f'{stat}%'] = stats[stat]/stats['pa']
    for col in optimistic_columns:
        if col in stats.columns:
            stats[col+'_avg'] = stats[col]/stats['pa']
    return stats

def get_woba(stats):
    woba_weights = {'ob': .702, 'ibb': -.702, 'tb': .37, 'h': -.21}
    return sum([stats[stat]*woba_weights[stat] for stat in woba_weights.keys()])/(stats['pa'] - stats['ibb'])

def add_batting_rate_stats(df):
    df['pa'] = df['ab'] + df['bb'] + df['hbp'] + df['sf']
    df['outs'] = df['ab'] - df['h'] + df['cs'] + df['sf']
    df['tb'] = df['h'] + df['_2b'] + 2*df['_3b'] + 3*df['hr']
    df['ob'] = df['h'] + df['bb'] + df['hbp']
    df['ba'] = df['h'] / df['ab']
    df['obp'] = df['ob'] / df['pa']
    df['slg'] = df['tb'] / df['ab']
    df['ops'] = df['obp'] + df['slg']
    df['r27'] = df['r'] / df['outs'] * 27
    df['woba'] = get_woba(df)
    return df
