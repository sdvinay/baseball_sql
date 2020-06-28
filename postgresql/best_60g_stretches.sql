-- It takes a while to generate all the 60-game stretches for all players, so do it once
-- and dump them into a temp table for querying
drop   table t_60g_stretches;
create table t_60g_stretches as
select player_id, game_dt as end_dt
     , row_number() over (partition by player_id order by game_dt, game_ct) as start_game_num
     , lag(game_dt, 59) over (partition by player_id order by game_dt, game_ct) as start_dt
     , sum(b_h)  over (partition by player_id order by game_dt, game_ct asc rows 59 preceding) as h
     , sum(b_ab) over (partition by player_id order by game_dt, game_ct asc rows 59 preceding) as ab
     , sum(b_pa) over (partition by player_id order by game_dt, game_ct asc rows 59 preceding) as pa
     , count(b_pa) over (partition by player_id order by game_dt, game_ct asc rows 59 preceding) as gms
  from retrosheet_daily
 where extract(year from game_dt) >=1990
;

-- Find qualifying stretches, and compute BA
with qual_stretches as
(
select *, h::decimal/ab as ba
  from t_60g_stretches
 where gms=60
   and pa>=3.1*60
)
select player_id, count(start_dt) from qual_stretches where ba>=.4 group by player_id;

select s.player_id, concat(p.name_first, ' ', p.name_last), start_dt, end_dt, h, ab, pa, round(ba,4) as ba
from ( select * -- identify each player's career high by using a window function
            , row_number() over (partition by player_id order by ba desc, start_dt asc) as row_num
         from qual_stretches) s
   inner join baseballdatabank_people as p -- to get the name
           on p.retro_id = s.player_id
        where s.row_num = 1 and ba>=.4 -- just take each player's career high, as long as it's .400+
     order by s.ba desc
;

