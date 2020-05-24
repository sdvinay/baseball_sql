use retrosheet;

drop table t_fouls;
create table t_fouls as 
select event.event_cd, game.game_dt as game_dt, year(game_dt) as yr, game.park_id as park_id
from event
inner join game
on game.game_id = event.game_id
where event.foul_fl>0;

select event_cd, count(event_cd) as num from t_fouls
group by event_cd;

select yr, count(*) as num
from t_fouls 
where event_cd = 2
group by yr
order by yr;