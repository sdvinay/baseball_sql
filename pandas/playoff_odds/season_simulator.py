import typer

import playoff_odds as po

def main(num_trials: int = 100):
    (played, remain) = po.get_games()
    cur_standings = po.compute_standings(played)
    sim_results = po.sim_n_seasons(cur_standings, remain, num_trials)
    summary = po.summarize_sim_results(sim_results)
    print(summary.sort_values('champ_shares', ascending=False).to_string())

if __name__ == "__main__":
    typer.run(main) 