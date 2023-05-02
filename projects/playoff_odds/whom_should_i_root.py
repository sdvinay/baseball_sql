import pandas as pd
import season_simulator as sim

def sim_one_way(incoming_standings, game_id, prob, num_iterations, remain):
    orig_prob = remain.loc[game_id, 'rating_prob1']
    remain.loc[game_id, 'rating_prob1'] = prob
    sim_results = sim.sim_n_seasons(incoming_standings, remain, num_iterations)
    remain.loc[game_id, 'rating_prob1'] = orig_prob
    results = sim.summarize_sim_results(sim_results)
    wp1 = results['champ_shares'].rename(f'{prob}')
    return wp1


def sim_both_ways(incoming_standings, game_id, num_iterations, remain):
    results = pd.concat([sim_one_way(incoming_standings, game_id, prob, num_iterations, remain) for prob in [0, 1]], axis=1)

    team1 = remain.loc[game_id, 'team1']
    diff = (results['1'] - results['0']).rename(game_id)
    return diff

