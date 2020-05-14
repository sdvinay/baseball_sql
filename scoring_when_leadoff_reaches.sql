# This is inspired by the Don Denkinger play, 9th inning of game 6 of 1985 WS
# Ken Dayley said the chances of scoring go from "a little" to "a lot" based on the leadoff hitter reaching
# https://www.youtube.com/watch?v=0wpkdrjLb94

drop table t_event_1985_leadoffs;
create table t_event_1985_leadoffs as 
select * from retrosheet.event
where  leadoff_fl>0 and game_id in
(	select game_id from retrosheet.game where year(game_dt) in (1982, 1983, 1984, 1985))
;

describe t_event_1985_leadoffs;
select count(*) from t_event_1985_leadoffs;  # 26*162*9 = 37908


select *, inn_scored/inn_total as freq_scored, runs_scored/inn_total as avg_scored, runs_scored/inn_scored as avg_runs_when_scored 
from
(	select  event_outs_ct=0 as reached, count(*) as inn_total, COUNT(NULLIF(0, (event_runs_ct+fate_runs_ct))) as inn_scored, 
		sum(event_runs_ct+fate_runs_ct) as runs_scored
	from t_event_1985_leadoffs
	group by event_outs_ct
) x
;