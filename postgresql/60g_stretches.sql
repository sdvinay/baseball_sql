-- With the shortened 2020 season, let's see what players can do in 60-game stretches

-- create a temp table of stats over 60g stretches, that we can then play with
-- it takes 55sec now
      drop table t_60g_stretches;
    create table t_60g_stretches as
    select player_id, game_dt as end_dt
         , row_number() over (partition by player_id order by game_dt, game_ct) as start_game_num
         , lag(game_dt, 59) over (partition by player_id order by game_dt, game_ct) as start_dt
         , sum(b_h)         over (partition by player_id order by game_dt, game_ct asc rows 59 preceding) as h
         , sum(b_ab)        over (partition by player_id order by game_dt, game_ct asc rows 59 preceding) as ab
         , sum(b_pa)        over (partition by player_id order by game_dt, game_ct asc rows 59 preceding) as pa
         , count(b_pa)      over (partition by player_id order by game_dt, game_ct asc rows 59 preceding) as gms
      from retrosheet_daily
     where extract(year from game_dt) >=1990
;
    select * from t_60g_stretches limit 20

;
-- find qualifying stretches (this still takes 16sec)
with qual_stretches as
(
    select *, h::decimal/ab as ba
      from t_60g_stretches
     where gms=60
       and pa>=3.1*60
)


select s.player_id, concat(p.name_first, ' ', p.name_last), start_dt, end_dt, h, ab, pa, round(ba,4) as ba
  from (   select *
                , row_number() over (partition by player_id order by ba desc, start_dt asc) as row_num
             from qual_stretches) s
inner join baseballdatabank_people as p
        on p.retro_id = s.player_id
     where s.row_num = 1
  order by s.ba desc
     limit 100

;
