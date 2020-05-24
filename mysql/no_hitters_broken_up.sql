# Find no-hitters broken up
#   Start by finding the first hit of every team-game
#      (this is the computationally expensive part, so store the results in t_first_hits)
#   Then we can aggregate by batter, pitcher, etc

drop table t_first_hits;
create table t_first_hits as
    select game_id, bat_home_id, event_id, inn_ct
    from  # find the first hit of every team-game by using a window for each team-game
    (   select game_id, bat_home_id, event_id, inn_ct, min(event_id) over
            (partition by game_id, bat_home_id) as first_hit
        from event
        where  game_id in (select game_id from retrosheet.game where year(game_dt)>1900)
            and h_fl>0  # h_fl is actually total bases, not a flag
    ) hits  # this sub-query will return *all* hits, with a field for first_hit
    where event_id=first_hit
;

# create a temp table for no-hitters blown (including the pitcher giving up the hit)
drop table t_nonos_blown;
create table t_nonos_blown as
    select bat_id, pit_id, t_first_hits.game_id as game_id, t_first_hits.inn_ct as inn_ct
    from event inner join t_first_hits
        on event.game_id=t_first_hits.game_id and event.event_id = t_first_hits.event_id
;

describe t_nonos_blown;

# summarize and format the pitchers that have blown multiple in the 9th or later
select name_first, name_last, num, least_recent, most_recent
from  # group by pitcher, and get the dates from retrosheet.game
(   select pit_id, min(game_dt) as least_recent, max(game_dt) as most_recent, count(*) as num
    from t_nonos_blown inner join retrosheet.game
        on t_nonos_blown.game_id=retrosheet.game.game_id
    where t_nonos_blown.inn_ct>8
    group by pit_id
) x
inner join baseballdatabank.people # get the first and last names
    on baseballdatabank.people.retro_id=x.pit_id
where num>1
order by num desc, most_recent, name_last
;

# summarize and format the batters that have broken up multiple in the 9th or later
select name_first, name_last, num, least_recent, most_recent, x.bat_id
from  # group by pitcher, and get the dates from retrosheet.game
(   select bat_id, min(game_dt) as least_recent, max(game_dt) as most_recent, count(*) as num
    from t_nonos_blown inner join retrosheet.game
        on t_nonos_blown.game_id=retrosheet.game.game_id
    where t_nonos_blown.inn_ct>8
    group by bat_id
) x
inner join baseballdatabank.people # get the first and last names
    on baseballdatabank.people.retro_id=x.bat_id
where num>1
order by num desc, most_recent, name_last
;

select *
from t_nonos_blown
where bat_id='clarh101' and inn_ct>8;