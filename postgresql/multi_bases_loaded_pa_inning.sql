-- Players with multiple bases-loaded PA in one inning
--   e.g., who has had the opportunity to do a Tatis?


-- find all instances of multiple bases-loaded PA in one inning
-- this takes ~5 seconds, so create a temp table for these
drop table t_multiple_basesloaded_pas;
create table t_multiple_basesloaded_pas as 
with multiple_basesloaded_pas as ( -- this query finds the instances
	select game_id, inn_ct, bat_home_id, bat_id,
		min(event_id) as first_event, max(event_id) as last_event
	from retrosheet_event 
	where start_bases_cd=7 -- start_bases_cd=7 means bases loaded
	group by game_id, inn_ct, bat_home_id, bat_id -- same half-inning, same batter
	having (max(event_id)-min(event_id))>8  -- a gap of >8 in event_id means distinct PAs
)
-- this adds the game dt and teams
select mbp.*, game_dt, away_team_id, home_team_id 
from multiple_basesloaded_pas as mbp
inner join retrosheet_game 
on retrosheet_game.game_id = mbp.game_id;

-- how frequently does this happen?
select * from t_multiple_basesloaded_pas order by game_dt;
select * from t_multiple_basesloaded_pas where extract(year from game_dt)>=1999 order by game_dt;


-- find players who had multiple bl_multi's in their career
select p.name_first, p.name_last, num, earliest, latest 
from (	-- this query finds the instances
	select bat_id, count(game_id) as num, min(game_dt) as earliest, max(game_dt) as latest
	from t_multiple_basesloaded_pas
	group by bat_id
	having count(game_id)>1
) as multiple_mbps
inner join baseballdatabank_people as p -- this adds the players' names
on p.retro_id = multiple_mbps.bat_id
order by num desc, latest;

-- find bl_multi's where the batter homered in the first PA
-- (It's actually the first *event*, so it's possible we could miss an instance)
with gs_then_bl_in_inning as ( -- this query finds the instances
	select t_multiple_basesloaded_pas.*
	from t_multiple_basesloaded_pas
	inner join retrosheet_event
	on t_multiple_basesloaded_pas.game_id = retrosheet_event.game_id and t_multiple_basesloaded_pas.first_event = retrosheet_event.event_id
	where retrosheet_event.event_cd=23 -- event code 23 is a HR
)
select p.name_first, p.name_last, game_dt, inn_ct, -- this formats the output
	case when bat_home_id=true then home_team_id else away_team_id end as tm,
	case when bat_home_id=true then away_team_id else home_team_id end as opp
from gs_then_bl_in_inning
inner join baseballdatabank_people as p
on p.retro_id = gs_then_bl_in_inning.bat_id
order by game_dt;
