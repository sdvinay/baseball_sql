import pandas as pd
import numpy as np

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