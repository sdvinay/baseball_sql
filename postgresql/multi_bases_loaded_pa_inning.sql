-- Players with multiple bases-loaded PA in one inning
--   e.g., who has had the opportunity to do a Tatis?


-- find all instances of multi bases-loaded PA in one inning
-- this takes ~15 seconds, so create a temp table for these
drop table t_multi_bl_pa;
create table t_multi_bl_pa as
select bl_multi.*, game_dt, away_team_id, home_team_id 
from (	
	select game_id, bat_home_id, inn_ct, bat_id, count(distinct event_id) as num, 
		min(event_id) as first_event, max(event_id) as last_event
	from retrosheet_event 
	where start_bases_cd=7 -- start_bases_cd=7 means bases loaded
	group by game_id, bat_home_id, inn_ct, bat_id
	having (max(event_id)-min(event_id))>8  -- look for a gap of >8 in event_id, to get distinct PAs
) bl_multi
inner join retrosheet_game on retrosheet_game.game_id = bl_multi.game_id;

-- how frequently does this happen?
select * from t_multi_bl_pa order by game_dt;
select * from t_multi_bl_pa where extract(year from game_dt)>=1999 order by game_dt;


-- find players who had multiple bl_multi's in their career
select name_first, name_last, num, earliest, latest 
from (	
	select bat_id, count(game_id) as num, min(game_dt) as earliest, max(game_dt) as latest
	from t_multi_bl_pa
	group by bat_id
) by_batter
inner join baseballdatabank_people
on baseballdatabank_people.retro_id = by_batter.bat_id
order by num desc, latest;

-- find bl_multi's where the batter homered in the first PA (actually, event)
with gs_then_bl_in_inning as (
	select t_multi_bl_pa.*
	from t_multi_bl_pa
	inner join retrosheet_event
	on t_multi_bl_pa.game_id = retrosheet_event.game_id and t_multi_bl_pa.first_event = retrosheet_event.event_id
	where retrosheet_event.event_cd=23 -- event code 23 is a HR
)
select name_first, name_last, game_dt, inn_ct,
	case when bat_home_id=true then home_team_id else away_team_id end as tm,
	case when bat_home_id=true then away_team_id else home_team_id end as opp
from gs_then_bl_in_inning
inner join baseballdatabank_people
on baseballdatabank_people.retro_id = gs_then_bl_in_inning.bat_id
order by game_dt;
