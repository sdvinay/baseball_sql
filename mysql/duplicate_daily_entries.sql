use retrosheet;

drop table t_daily_dups;
create table t_daily_dups as
select * from
(	select game_id, player_id, max(game_dt) as game_dt, count(*) as cnt from retrosheet.daily 
	group by game_id, player_id
) counts
where cnt>1
;
describe t_daily_dups;
select year(game_dt) as yr, count(*) as num from t_daily_dups
group by year(game_dt)
order by num desc;

drop table t_daily_nulls;
create table t_daily_nulls as
select game_id, game_dt, player_id from retrosheet.daily
where b_pa is null
;
describe t_daily_nulls;
drop table t_daily_nulls_summary;
create table t_daily_nulls_summary as
select year(game_dt) as yr, count(*) as num from t_daily_nulls
group by year(game_dt)
order by yr;

drop table t_daily_dups_summary;
create table t_daily_dups_summary as
select year(game_dt) as yr, count(*) as num from t_daily_dups
group by year(game_dt)
order by yr;

select * from t_daily_nulls_summary;
select * from t_daily_dups_summary;

