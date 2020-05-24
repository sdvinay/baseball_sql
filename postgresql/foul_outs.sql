-- look at trends in foul outs over time

drop table t_fouls;
create table t_fouls as 
select event_cd, retrosheet_game.game_dt as game_dt, extract(year from game_dt) as yr, retrosheet_game.park_id as park_id
from retrosheet_event
inner join retrosheet_game
on retrosheet_game.game_id = retrosheet_event.game_id
where retrosheet_event.foul_fl=true;

select event_cd, count(event_cd) as num from t_fouls
group by event_cd;

select yr, count(*) as num from t_fouls 
where event_cd = 2 group by yr order by yr;