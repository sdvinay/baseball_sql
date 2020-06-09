-- Find games where multiple players who've already reached 3000 hits played together
--   Inspired by Oct 7, 2001, when Rickey Henderson got his 3000th hit in Tony Gwynn's
--   final game.  In the post-game ceremony, they said it was the first time in NL
--   history that two teammates played in a game with 3000 hits.
-- Retrosheet dailies include post-season and ASG.  AFAIK no way to filter to reg season
--   So this will be a little over-inclusive.

drop table t_3000h_players;

create table t_3000h_players as
with
players_with_3000 as
(	select * from
	(	select player_id, sum(h) as career_h
		from baseballdatabank_batting
		group by player_id
	) x
	where career_h >= 3000
)
-- join with baseballdatabank_people to get retro_id
select baseballdatabank_people.retro_id as retro_id, career_h
from players_with_3000
inner join baseballdatabank_people on players_with_3000.player_id=baseballdatabank_people.player_id
;

select * from t_3000h_players order by career_h desc;


-- compute the running hits total by game for all players with 3K
drop table t_running_h_total;
create table t_running_h_total as
with
dailies as -- select limited dailies for players with 3K
(	select distinct player_id, game_id, game_dt, game_ct, team_id, b_h
	from retrosheet_daily
	where player_id in (select retro_id from t_3000h_players)
)
select player_id, game_id, team_id, game_dt, game_ct,
	-- this window function acts from the beginning of the partition to the current row,
	-- so the sum(b_h) is a running total
	sum(b_h) over (partition by player_id order by game_dt, game_ct) as running_h_total
from dailies
order by game_dt, game_ct
;

-- verify we're not seeing double-counted games
-- total hits should be 3044 because of ASG and post-season (should be 2473 rows)
select * from t_running_h_total where player_id='clemr101';

-- see when each player crossed 3000 H
select player_id, min(game_dt) as dt_3000th
from t_running_h_total
where running_h_total>=3000
group by player_id
order by dt_3000th;


-- Enumerate each player's games once they'd reached 3000, and aggregate
with
games_with_3000K as
(	select game_id, team_id, count(player_id) as num_in_gm, extract (year from game_dt) as yr
	from t_running_h_total
	where running_h_total >= 3000
	group by game_id, team_id, game_dt
)

select team_id, yr, count(game_id) as num_games, max(num_in_gm) as max_3000s_in_gm
from games_with_3000K
where num_in_gm>1
group by team_id, yr
order by yr;

