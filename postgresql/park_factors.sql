-- Compute long-term park factors

-- starting out hard-coded to compute for triples by games (TODO, conditionalize component and opportunity)
-- began an iterative approach to adjust for non-neutral road parks, but still completely hard-coded (TODO a real iterative approach)

with
-- raw game data: extract the columns we want, for the range of years we want
raw_game_totals as
(     select game_id, park_id, home_team_id, away_team_id, away_3b_ct, home_3b_ct, extract(year from game_dt) as yr
        from retrosheet_game
       where extract(year from game_dt)>=2010
),
-- We want to get to each team-season-park's home/road splits.
-- Start with the home split, then the road split, then join them
team_seasons as
(       with home_game_totals as
             (     select home_team_id, park_id, yr, count(game_id) as gms, sum(home_3b_ct) as home_3b, sum(away_3b_ct) as away_3b
                     from raw_game_totals
                 group by home_team_id, park_id, yr
             ),
             away_game_totals as
             (     select away_team_id, yr, count(game_id) as gms, sum(home_3b_ct) as home_3b, sum(away_3b_ct) as away_3b
                     from raw_game_totals
                 group by away_team_id, yr
             )

      select h.home_team_id as team_id, h.park_id, h.yr, h.gms as gms_h, h.home_3b+h.away_3b as instances_h,
             a.gms as gms_a, a.home_3b+a.away_3b as instances_a
        from home_game_totals as h
  inner join away_game_totals as a
          on h.home_team_id=a.away_team_id and h.yr=a.yr
),
-- Now aggregate across years
park_aggregated_totals as
(     select team_id, park_id, sum(gms_h) as gms_h, sum(instances_h) as instances_h, sum(gms_a) as gms_a,
             sum(instances_a) as instances_a, min(yr) as yr_start, max(yr) as yr_last
        from team_seasons
       where gms_h>10 and gms_a>0 and instances_a>0
    group by team_id, park_id
),
-- And now we can compute PFs
initial_pfs as
(
      select *, (instances_h::decimal/gms_h::decimal)/(instances_a::decimal/gms_a::decimal) as pf
        from park_aggregated_totals
),
-- Let's now iterate on the computation, by looking at each team's road schedule
-- For now, we're looking at the aggregate road schedule for each team over the entire era, not by year in park.  Close enough.
road_game_counts as -- count road games for each team in each park
(
      select away_team_id, park_id, count(distinct game_id) as road_game_ct
        from raw_game_totals
    group by away_team_id, park_id
),
adj as  -- need to add this scoping level because of "with recursive" requirements
(
    with recursive adjusted_pfs as -- recursive PF adjustment based on road weighted avg PF
    (
        select team_id, park_id, 0 as iteration, pf as raw_pf, 1.00 as weighted_avg_road_pf, pf
          from initial_pfs as i

        union
        ( with
             road_games_with_pfs as -- add in the initial PF for each matchup
             (
                   select r.away_team_id, r.park_id, r.road_game_ct, pf, iteration
                     from adjusted_pfs as pfs
               inner join road_game_counts as r
                       on r.park_id = pfs.park_id
             ),
             road_weighted_avg_pfs as -- compute the weighted avg for each team's road schedule
             (
                   select away_team_id, sum(road_game_ct) as road_game_ct, sum(road_game_ct*pf) as sum_pf,
                          sum(road_game_ct*pf)/sum(road_game_ct) as weighted_avg_road_pf, iteration
                     from road_games_with_pfs
                 group by away_team_id, iteration
             )

          select i.team_id, i.park_id, r.iteration+1 as iteration, i.pf as raw_pf, r.weighted_avg_road_pf, i.pf*r.weighted_avg_road_pf as adjusted_pf
            from initial_pfs as i
      inner join road_weighted_avg_pfs as r
              on i.team_id = r.away_team_id
           where iteration <=5
        )
    )
    select * from adjusted_pfs
)

-- Now format the output
    select tot.*, iteration, round(raw_pf, 2) as raw_pf,
           round(weighted_avg_road_pf, 2) as weighted_avg_road_pf, round(pf, 3) as pf
      from adj as pf
inner join park_aggregated_totals as tot
        on tot.team_id=pf.team_id and tot.park_id=pf.park_id

  order by iteration desc, pf desc
