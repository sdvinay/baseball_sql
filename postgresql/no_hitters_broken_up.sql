-- Find no-hitters broken up
--   Start by finding the first hit of every team-game
--      (this is the computationally expensive part, so store the results in t_first_hits)
--   Then we can aggregate by batter, pitcher, etc

drop table t_first_hits;
create table t_first_hits as
with
games as (select game_id from retrosheet_game where extract(year from game_dt)>1900)

    select game_id, bat_home_id, bat_id, pit_id, event_id, inn_ct
    from  -- find the first hit of every team-game by using a window for each team-game
    (   select game_id, bat_home_id, bat_id, pit_id, event_id, inn_ct, min(event_id) over
            (partition by game_id, bat_home_id) as first_hit
        from retrosheet_event
        where  game_id in (select game_id from games)
            and h_fl>0  -- h_fl is actually total bases, not a flag
    ) hits  -- this sub-query will return *all* hits, with a field for first_hit
    where event_id=first_hit
;
select * from t_first_hits;

-- summarize and format the pitchers that have blown multiple in the 9th or later
select name_first, name_last, num, least_recent, most_recent
from  -- group by pitcher, and get the dates from retrosheet_game
(   select pit_id, min(game_dt) as least_recent, max(game_dt) as most_recent, count(*) as num
    from t_first_hits inner join retrosheet_game
        on t_first_hits.game_id=retrosheet_game.game_id
    where t_first_hits.inn_ct>8
    group by pit_id
) x
inner join baseballdatabank_people -- get the first and last names
    on baseballdatabank_people.retro_id=x.pit_id
where num>1
order by num desc, most_recent, name_last
;

-- summarize and format the batters that have broken up multiple in the 9th or later
select name_first, name_last, num, least_recent, most_recent, x.bat_id
from  -- group by pitcher, and get the dates from retrosheet_game
(   select bat_id, min(game_dt) as least_recent, max(game_dt) as most_recent, count(*) as num
    from t_first_hits inner join retrosheet_game
        on t_first_hits.game_id=retrosheet_game.game_id
    where t_first_hits.inn_ct>7
    group by bat_id
) x
inner join baseballdatabank_people -- get the first and last names
    on baseballdatabank_people.retro_id=x.bat_id
where num>1
order by num desc, most_recent, name_last
;

select *
from t_first_hits
where bat_id='clarh101' and inn_ct>8;