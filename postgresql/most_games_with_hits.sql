with dailies as (select distinct player_id, game_dt, game_id, b_h from retrosheet_daily where b_h>=1) 

  select player_id, extract(year from game_dt) as yr, count(game_id) as num 
    from dailies
group by player_id, extract(year from game_dt)
  having count(game_id)>100
order by num desc;