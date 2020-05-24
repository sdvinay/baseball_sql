use retrosheet;

drop table t_daily_dups;
create table t_daily_dups as
select * from
(	select game_yr, player_yr, max(game_dt) as game_dt, count(*) as cnt from retrosheet.daily 
	group by game_yr, player_yr
) counts
where cnt>1
;
describe t_daily_dups;
create table t_daily_nulls_summary as
select year(game_dt) as yr, count(*) as num from t_daily_nulls
group by year(game_dt)
order by yr;

create table t_daily_dups_summary as
select year(game_dt) as yr, count(*) as num from t_daily_dups
group by year(game_dt)
order by yr;

select * from t_daily_nulls_summary;
select * from t_daily_dups_summary;


SELECT *
FROM `t_daily_nulls_summary`
LEFT OUTER JOIN `t_daily_dups_summary` ON `t_daily_nulls_summary`.`yr` = `t_daily_dups_summary`.`yr`

UNION

SELECT *
FROM `t_daily_nulls_summary`
RIGHT OUTER JOIN `t_daily_dups_summary` ON `t_daily_nulls_summary`.`yr` = `t_daily_dups_summary`.`yr`;
;

select count(*) from t_daily_dups;

create table t_daily_dups_null_ct as
select count(*) 
from t_daily_dups
inner join 
(	select game_id, player_id from daily
	where daily.b_pa is null
) nulls
on t_daily_dups.game_id = nulls.game_id and t_daily_dups.player_id = nulls.player_id
;

describe t_daily_dups_null_ct;


select game_yr, count(player_yr) as cnt from t_daily_dups
where year(game_dt)=1957
group by game_yr
;

create table t_PIt_daily_nulls_summary95709212 as
	select * from retrosheet.daily
	where game_yr='PIt_daily_nulls_summary95709212'
;

select * from t_PIt_daily_nulls_summary95709212;

create table t_daily_nulls as
select * from retrosheet.daily where b_pa is null;