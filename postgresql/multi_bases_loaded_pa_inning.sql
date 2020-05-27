-- Players with multiple bases-loaded PA in one inning
--   e.g., who has had the opportunity to do a Tatis?


-- find all instances of multiple bases-loaded PA in one inning
-- this takes ~5 seconds, so create a temp table for these
drop table t_multi_bl_pa;
create table t_multi_bl_pa as 
with multi_bl_pa as ( -- this query finds the instances
	select game_id, inn_ct, bat_home_id, bat_id,
		min(event_id) as first_event, max(event_id) as last_event
	from retrosheet_event 
	where start_bases_cd=7 -- start_bases_cd=7 means bases loaded
	group by game_id, inn_ct, bat_home_id, bat_id -- same half-inning, same batter
	having (max(event_id)-min(event_id))>8  -- a gap of >8 in event_id means distinct PAs
)
-- this adds the game dt and teams
select multi_bl_pa.*, game_dt, away_team_id, home_team_id 
from multi_bl_pa
inner join retrosheet_game 
on retrosheet_game.game_id = multi_bl_pa.game_id;

-- how frequently does this happen?
select * from t_multi_bl_pa order by game_dt;
select * from t_multi_bl_pa where extract(year from game_dt)>=1999 order by game_dt;


-- find players who had multiple bl_multi's in their career
select name_first, name_last, num, earliest, latest 
from (	-- this query finds the instances
	select bat_id, count(game_id) as num, min(game_dt) as earliest, max(game_dt) as latest
	from t_multi_bl_pa
	group by bat_id
	having count(game_id)>1
) by_batter
inner join baseballdatabank_people -- this adds the players' names
on baseballdatabank_people.retro_id = by_batter.bat_id
order by num desc, latest;

-- find bl_multi's where the batter homered in the first PA
-- (It's actually the first *event*, so it's possible we could miss an instance)
with gs_then_bl_in_inning as ( -- this query finds the instances
	select t_multi_bl_pa.*
	from t_multi_bl_pa
	inner join retrosheet_event
	on t_multi_bl_pa.game_id = retrosheet_event.game_id and t_multi_bl_pa.first_event = retrosheet_event.event_id
	where retrosheet_event.event_cd=23 -- event code 23 is a HR
)
select name_first, name_last, game_dt, inn_ct, -- this formats the output
	case when bat_home_id=true then home_team_id else away_team_id end as tm,
	case when bat_home_id=true then away_team_id else home_team_id end as opp
from gs_then_bl_in_inning
inner join baseballdatabank_people
on baseballdatabank_people.retro_id = gs_then_bl_in_inning.bat_id
order by game_dt;
