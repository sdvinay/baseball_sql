
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

-- Compute park factors (WIP)
with triples as 
(	  select game_id, park_id, home_team_id, away_team_id, away_3b_ct, home_3b_ct, extract(year from game_dt) as yr
	    from retrosheet_game
	   where extract(year from game_dt)>=2010
),
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
parks_aggregated as
(
      select team_id, park_id, sum(gms_h) as gms_h, sum(triples_h) as triples_h, sum(gms_a) as gms_a, 
             sum(triples_a) as triples_a, min(yr) as yr_start, max(yr) as yr_last
        from team_seasons
       where gms_h>10 and gms_a>0 and triples_a>0
    group by team_id, park_id
)
  select *, round((triples_h::decimal/gms_h::decimal)/(triples_a::decimal/gms_a::decimal), 2) as pf
    from parks_aggregated
order by pf desc
