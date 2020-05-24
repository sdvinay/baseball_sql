drop table t_3000h_players;
create table t_3000h_players as 
	select baseballdatabank_people.retro_id as retro_id, career_h
	from  ( select player_id, sum(h) as career_h from baseballdatabank_batting group by player_id) h
    inner join baseballdatabank_people on h.player_id=baseballdatabank_people.player_id
	where career_h >= 3000;
select * from t_3000h_players;


-- this includes post-season and ASGs.  No way to filter (that I can figure out) to reg season
drop table t_running_h_total;
create table t_running_h_total as
with
dailies as
(	select distinct player_id, game_id, game_dt, game_ct, team_id, b_h
	from retrosheet_daily
	where player_id in (select retro_id from t_3000h_players)
)
select player_id, game_id, team_id, game_dt, game_ct, sum(b_h) over
            (partition by player_id order by game_dt, game_ct) as running_h_total
from dailies
order by game_dt, game_ct
;



-- verify we're not seeing double-counted games
-- total should be 3044 because of ASG and post-season
select * from t_running_h_total where player_id='clemr101'
;

-- this still includes post-season and ASG hits in the totals
select team_id, yr, count(game_id) as num_games from 
(	select t_running_h_total.game_id, team_id, count(player_id) as num_in_gm, extract (year from retrosheet_game.game_dt) as yr
	from t_running_h_total inner join retrosheet_game 
	on t_running_h_total.game_id = retrosheet_game.game_id
	where running_h_total >= 3000
	group by t_running_h_total.game_id, team_id, retrosheet_game.game_dt
) x
where num_in_gm>1
group by team_id, yr
order by yr;

