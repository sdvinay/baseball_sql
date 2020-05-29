-- How have players with 3 PAs in an inning done?
-- What are the best 3-PA innings, and the worst?

-- Collect all the event rows that correspond to 3 PAs in one inning
  drop table t_3pas_in_one_inning;
create table t_3pas_in_one_inning as

    with -- inn_pa_ct>=18 indicates third time through the order that inning
   games as (select distinct(game_id) from retrosheet_event where inn_pa_ct>=18),
 batters as (select distinct(bat_id)  from retrosheet_event where inn_pa_ct>=18),
            -- start with a superset of all the events from batters in these games,
            -- and the fields we care about
superset as (select game_id, inn_ct, bat_id, event_id, bat_home_id, event_outs_ct, ab_fl, h_fl
               from retrosheet_event 
              where game_id in (select game_id from games)
                and bat_id in (select bat_id from batters)
            )

select * -- and now narrow to the events that actually count in the 3PA innings 
  from (  select min(event_id) over (partition by game_id, inn_ct, bat_id) as first_event,
                 max(event_id) over (partition by game_id, inn_ct, bat_id) as last_event,
                 superset.*
            from superset
       ) as foo
 where (last_event-first_event)>16
;

select * from t_3pas_in_one_inning;

with
three_pas_in_an_inning as ( -- get totals for each batter in their half inning of glory
	  select game_id, inn_ct, bat_home_id, bat_id,
             sum(event_outs_ct) as outs_made, 
             count(case when ab_fl then 1 end) as ab,
             count(case when h_fl>0 then 1 end) as h, 
             sum(h_fl) as tb -- h_fl is really the count of TB, not a hit flag (ugh)
        from t_3pas_in_one_inning as t 
    group by game_id, inn_ct, bat_home_id, bat_id -- same half inning, same batter
),
three_pas_in_an_inning_annotated as ( -- add the game_dt and teams
      select t.*, game_dt, away_team_id, home_team_id 
        from three_pas_in_an_inning as t
  inner join retrosheet_game as g
          on g.game_id = t.game_id
)
        -- now add the player info and format the output
    select p.name_first, p.name_last, t.game_dt, t.inn_ct,
           case when bat_home_id=true then home_team_id else away_team_id end as tm,
           case when bat_home_id=true then away_team_id else home_team_id end as opp,
           t.outs_made, t.ab, t.h, t.tb
      from three_pas_in_an_inning_annotated as t
inner join baseballdatabank_people as p
        on p.retro_id = t.bat_id
  order by game_dt;