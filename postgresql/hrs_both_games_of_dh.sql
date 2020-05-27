-- Players who homered in both ends of a doubleheader the most times
select player_id, count(distinct game_dt) as num_dhs, min(game_dt) as earliest, max(game_dt) as latest from
( -- find doubleheaders where a player HRd in more than 1 game
	select game_dt, player_id, count (distinct game_ct) as num_games
	from retrosheet_daily where game_ct>0 and b_hr>0
	group by game_dt, player_id
	having count (distinct game_ct)>1
) y
group by player_id
order by count(distinct game_dt) desc 
;

-- Players who hit a GS in both ends of a doubleheader the most times
select player_id, count(distinct game_dt) as num_dhs, min(game_dt) as earliest, max(game_dt) as latest from
( -- find doubleheaders where a player HRd in more than 1 game
	select game_dt, player_id, count (distinct game_ct) as num_games
	from retrosheet_daily where game_ct>0 and b_hr4>0 -- this is the only line that's different
	group by game_dt, player_id
	having count (distinct game_ct)>1
) y
group by player_id
order by count(distinct game_dt) desc 
;
