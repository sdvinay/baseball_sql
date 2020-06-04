
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
)
select home_team_id, park_id, yr, count(game_id) as gms, sum(home_3b_ct) as home_3b, sum(away_3b_ct) as away_3b
from triples
group by home_team_id, park_id, yr