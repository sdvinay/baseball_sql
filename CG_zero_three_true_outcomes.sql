create table t_daily_cgs as
select * from retrosheet.daily where p_cg>0;

create table t_cgs_zero_ttos as 
select * from t_daily_cgs
where (p_bb+p_so+p_hr)=0 
;

select game_id, game_dt, name_first, name_last
from t_cgs_zero_ttos inner join baseballdatabank.people
	on baseballdatabank.people.retro_id=t_cgs_zero_ttos.player_id
where year(game_dt)>1946
order by game_dt desc
;


select year(game_dt) as yr, count(*) as num
from t_cgs_zero_ttos
group by yr
order by yr desc
;