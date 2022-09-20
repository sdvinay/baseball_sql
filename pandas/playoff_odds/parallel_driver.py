import concurrent.futures
import time
import pandas as pd
import typer
import random

import season_simulator as sim


def print_perf_counter(func):
    '''
    create a timing decorator function
    use
    @print_timing
    just above the function you want to time
    '''
    def wrapper(*arg):
        start = time.perf_counter()
        result = func(*arg)
        end = time.perf_counter()
        print(f'{func.__name__} took {round(end-start, 2)} second(s)')
        return result
    return wrapper

def sim_seasons(num_seasons: int, id: int):
    sim.main(id = str(id), show_summary=False, num_seasons=num_seasons)
    return id


@print_perf_counter
def get_job_size_distribution():
    num_seasons_on_avg = 1000
    num_steps = 9
    step_size = int(num_seasons_on_avg/num_steps)
    one_way_range = int((num_steps-1)/2)*step_size
    lo = num_seasons_on_avg-one_way_range
    hi = num_seasons_on_avg+one_way_range
    print(range(lo, hi))
    num_seasons_distribution = list(range(lo, hi+step_size, step_size))
    random.shuffle(num_seasons_distribution)
    return [num_seasons_on_avg] + num_seasons_distribution


@print_perf_counter
def summarize_data():
    sim_results = sim.gather_results()
    summary = sim.summarize_sim_results(sim_results)
    print(summary.sort_values('champ_shares', ascending=False).to_string())


@print_perf_counter
def parallel_driver(num_jobs):
    num_seasons_distribution = get_job_size_distribution()
    with concurrent.futures.ProcessPoolExecutor() as executor:
        def submit_job(id):
            num_seasons = num_seasons_distribution[id%len(num_seasons_distribution)]
            return executor.submit(sim_seasons, num_seasons, id)

        futures = [submit_job(id) for id in range(num_jobs)]

        for f in concurrent.futures.as_completed(futures):
            print(f'Job {f.result()} completed')


def main(num_jobs: int = 100):
    parallel_driver(num_jobs)
    summarize_data()


if __name__ == '__main__':
    typer.run(main)
