-- gather a supserset of event rows that include all the 3 PAs in one inning events
  drop table t_3pas_in_one_inning;
create table t_3pas_in_one_inning as

with   
  games as (select distinct(game_id) from retrosheet_event where inn_pa_ct>=18),
batters as (select distinct(bat_id) from retrosheet_event where inn_pa_ct>=18)

select * 
  from retrosheet_event 
 where game_id in (select game_id from games)
   and bat_id in (select bat_id from batters)
;

select * from t_3pas_in_one_inning;

with three_pas_in_an_inning as ( -- these are the actual 3PA innings
	  select game_id, inn_ct, bat_home_id, bat_id,
	  	     sum(event_outs_ct) as outs_made, 
	  	     count(case when ab_fl then 1 end) as ab,
	  	     count(case when h_fl>0 then 1 end) as h, 
	  	     sum(h_fl) as tb
	    from t_3pas_in_one_inning as t 
	group by game_id, inn_ct, bat_home_id, bat_id -- same half inning, same batter
	  having (max(event_id)-min(event_id))>16 -- assume events separated by 16 are three distinct PAs
),
three_pas_in_an_inning_annotated as ( -- add the game_dt and teams
    select t.*, game_dt, away_team_id, home_team_id 
      from three_pas_in_an_inning as t
inner join retrosheet_game as g
        on g.game_id = t.game_id
)
    select p.name_first, p.name_last, t.game_dt, t.inn_ct, -- add the player info and format output
           case when bat_home_id=true then home_team_id else away_team_id end as tm,
           case when bat_home_id=true then away_team_id else home_team_id end as opp,
           t.outs_made, t.ab, t.h, t.tb
      from three_pas_in_an_inning_annotated as t
inner join baseballdatabank_people as p
        on p.retro_id = t.bat_id
  order by game_dt;