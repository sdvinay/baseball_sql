import concurrent.futures
import time
import pandas as pd
import typer

import season_simulator as sim

def sim_seasons(id=1):
     sim.main(id = str(id), show_summary=False, num_seasons=1000)
     return id

def main(num_jobs: int = 100):
    start = time.perf_counter()
    with concurrent.futures.ProcessPoolExecutor() as executor:
        pool = executor.map(sim_seasons, range(num_jobs))
        for id in pool:
            print(f'Job {id} completed')

    end = time.perf_counter()
    print(f'Finished in {round(end-start, 2)} second(s)')

    sim_results = pd.concat([pd.read_feather(f'output/{id}.feather') for id in range(num_jobs)], axis=0)
    summary = sim.summarize_sim_results(sim_results)
    print(summary.sort_values('champ_shares', ascending=False).to_string())

if __name__ == '__main__':
    typer.run(main)
