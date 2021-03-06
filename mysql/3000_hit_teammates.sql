use retrosheet;

drop table t_3000h_players;
create table t_3000h_players as
	select people.retro_id as retro_id, career_h
	from ( select player_id, sum(h) as career_h from baseballdatabank.batting group by player_id) h
	inner join baseballdatabank.people on h.player_id=people.player_id
	where career_h >= 3000;
select * from t_3000h_players;

-- this includes post-season and ASGs. No way to filter (that I can figure out) to reg season
drop table t_running_h_total;
create table t_running_h_total as
with
dailies as
(	select distinct player_id, game_id, game_dt, game_ct, team_id, b_h
	from retrosheet.daily
	where player_id in (select retro_id from t_3000h_players)
)
select player_id, game_id, team_id, game_dt, game_ct, sum(b_h) over
			(partition by player_id order by game_dt, game_ct) as running_h_total
from dailies
order by game_dt, game_ct
;

-- verify we're not seeing double-counted games
-- total should be 3044 because of ASG and post-season
select * from t_running_h_total where player_id='clemr101';

-- see when each player crossed 3000 H
select player_id, min(game_dt) as dt
from t_running_h_total
where running_h_total>=3000
group by player_id
order by dt;


-- Now find games with at least one player at 3000 H
with
games_with_3000K as
(	select game_id, team_id, count(player_id) as num_in_gm, game_dt, year(game_dt) as yr
	from t_running_h_total
	where running_h_total >= 3000
	group by game_id, team_id, game_dt
)

select team_id, yr, count(game_id) as num_games
from games_with_3000K
where num_in_gm>1
group by team_id, yr
order by yr;
