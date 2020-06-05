
-- Triples by park
select x.*, home_3b+away_3b as total_3b, (home_3b+away_3b)*162/games as per162 
from (
	  select park_id, sum(away_3b_ct) as away_3b, sum(home_3b_ct) as home_3b, count(distinct game_id) as games
	    from retrosheet_game
	   where extract(year from game_dt)>=2010
	group by park_id
) x
order by per162 desc
;

-- Do the Dodgers ever beat the Diamondbacks in team triples?
select team_id, _3b, year_id from baseballdatabank_teams
where year_id>=2010 and team_id in ('LAN', 'ARI');

-- Compute long-term park factors

with triples as -- raw game data: extract the columns we want, for the range of years we want
(	  select game_id, park_id, home_team_id, away_team_id, away_3b_ct, home_3b_ct, extract(year from game_dt) as yr
	    from retrosheet_game
	   where extract(year from game_dt)>=2010
),
-- We want to get to each team-season-park's home/road splits.
-- Start with the home split, then the road split, then join them
home_triples as
(     select home_team_id, park_id, yr, count(game_id) as gms, sum(home_3b_ct) as home_3b, sum(away_3b_ct) as away_3b
        from triples
    group by home_team_id, park_id, yr
),
away_triples as
(     select away_team_id, yr, count(game_id) as gms, sum(home_3b_ct) as home_3b, sum(away_3b_ct) as away_3b
        from triples
    group by away_team_id, yr
),
team_seasons as
(     select h.home_team_id as team_id, h.park_id, h.yr, h.gms as gms_h, h.home_3b+h.away_3b as triples_h, 
             a.gms as gms_a, a.home_3b+a.away_3b as triples_a
        from home_triples as h
  inner join away_triples as a
          on h.home_team_id=a.away_team_id and h.yr=a.yr
),
-- Now aggregate across years
parks_aggregated as
(
      select team_id, park_id, sum(gms_h) as gms_h, sum(triples_h) as triples_h, sum(gms_a) as gms_a, 
             sum(triples_a) as triples_a, min(yr) as yr_start, max(yr) as yr_last
        from team_seasons
       where gms_h>10 and gms_a>0 and triples_a>0
    group by team_id, park_id
),
-- And now we can compute PFs
initial_pfs as
(
	  select *, (triples_h::decimal/gms_h::decimal)/(triples_a::decimal/gms_a::decimal) as pf
	    from parks_aggregated
),
-- Let's now iterate on the computation, by looking at each team's road schedule
-- For now, we're looking at the aggregate road schedule for each team over the entire era, not by year in park.  Close enough.
road_game_counts as -- count road games for each team in each park
(
	  select away_team_id, park_id, count(distinct game_id) as road_game_ct
	    from triples 
	group by away_team_id, park_id
),
road_games_with_pfs as -- add in the initial PF for each matchup
(
	  select r.away_team_id, r.park_id, r.road_game_ct, pf 
	    from road_game_counts as r
  inner join initial_pfs
          on r.park_id = initial_pfs.park_id
),
road_weighted_avg_pfs as -- compute the weighted avg for each team's road schedule
(
	  select away_team_id, sum(road_game_ct) as road_game_ct, sum(road_game_ct*pf) as sum_pf, 
	         sum(road_game_ct*pf)/sum(road_game_ct) as weighted_avg_road_pf
	    from road_games_with_pfs
	group by away_team_id
),
adjusted_pfs as -- and adjust the PF based on road weighted avg PF
(
	  select i.*, r.weighted_avg_road_pf, i.pf*r.weighted_avg_road_pf as adjusted_pf 
	    from initial_pfs as i
  inner join road_weighted_avg_pfs as r
          on i.team_id = r.away_team_id
)
-- Now format the output
  select team_id, park_id, gms_h, yr_start, yr_last, round(pf, 2) as pf,
         round(weighted_avg_road_pf, 2) as weighted_avg_road_pf, round(adjusted_pf, 2) as adjusted_pf
    from adjusted_pfs
order by adjusted_pf desc