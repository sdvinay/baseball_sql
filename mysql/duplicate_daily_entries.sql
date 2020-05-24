use retrosheet;

drop table t_daily_dups;
create table t_daily_dups as
select * from
(	select game_id, max(game_dt) as game_dt, count(*) as cnt from retrosheet.daily 
	group by game_id, player_id
) counts
where cnt>1
;
describe t_daily_dups;
select year(game_dt) as yr, count(*) as num from t_daily_dups
group by year(game_dt)
order by num desc;