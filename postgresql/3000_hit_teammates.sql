drop table t_3000h_players;
create table t_3000h_players as 
	select people.retro_id as retro_id, career_h
	from  ( select player_id, sum(h) as career_h from baseballdatabank.batting group by player_id) h
    inner join baseballdatabank.people on h.player_id=people.player_id
	where career_h >= 3000;
select * from t_3000h_players;

# this includes post-season and ASGs.  No way to filter (that I can figure out) to reg season
drop table t_running_h_total;
create table t_running_h_total as
select retrosheet.daily.player_id, retrosheet.daily.game_id, retrosheet.daily.team_id, sum(retrosheet.daily.b_h) over
            (partition by retrosheet.daily.player_id order by retrosheet.daily.game_dt) as running_h_total
from retrosheet.daily
where retrosheet.daily.player_id in (select retro_id from t_3000h_players)
;



select * from t_running_h_total where player_id='clemr101'
;

# need to count distinct player_id because of duplicate rows in daily
# this still includes post-season and ASG hits in the totals
select team_id, yr, count(distinct game_id) as num_games from 
(	select t_running_h_total.game_id, team_id, count(distinct player_id) as num_in_gm, year(retrosheet.game.game_dt) as yr
	from t_running_h_total inner join retrosheet.game 
	on t_running_h_total.game_id = game.game_id
	where running_h_total >= 3000
	group by t_running_h_total.game_id, team_id
) x
where num_in_gm>2
group by team_id, yr
order by yr;