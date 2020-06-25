-- When has the DH been used in NL parks?

with nl_parks as
( select park_id from retrosheet_park where league='NL')


    select concat(game_dt, '  ', away_team_id, ' @ ', home_team_id, ' (', p.name, ')')
      from retrosheet_game as g
inner join retrosheet_park as p
        on g.park_id = p.park_id
     where g.dh_fl = 'T'
       and g.park_id in (select * from nl_parks)
       and g.park_id not in ('HOU03', 'SJU01', 'MNT01') -- these parks ar classified as NL parks, but haven't always been
       and g.home_team_id not in ('NLS', 'ALS') -- skip ASGs
  order by game_dt

;
-- What teams have played as visitors in their own parks?
-- First attempt to answer this: find teams that have played in the same park as both
--  home and visitor in the same year.  This will get an overly large superset.
select concat (t.away_team_id, ' @ ', t.home_team_id), t.game_dt, p.name
from ( -- find the games
        select distinct ga.away_team_id, ga.home_team_id, ga.park_id, ga.game_dt
          from retrosheet_game ga
    inner join retrosheet_game gh
            on ga.away_team_id = gh.home_team_id
           and ga.park_id = gh.park_id
           and extract(year from ga.game_dt) = extract(year from gh.game_dt)
           and gh.park_id not in ('TOK01')
) t
inner join retrosheet_park as p -- to get the park name
        on t.park_id = p.park_id
  order by game_dt

;
-- What teams have played as visitors in their own parks?
-- Second attempt: identify each team-season's primary park, then find when they play
--  as visitors in that park in that season

with teams_main_parks as
(
    with home_gms_by_park as -- count home games by park
    (    select home_team_id, extract(year from game_dt) as yr, park_id,
                count(distinct game_id) as num_gms_in_park
           from retrosheet_game
       group by home_team_id, extract(year from game_dt), park_id
    )
    , home_gms_with_max as
    (    select *, -- use window function to find the max by team-season
                max(num_gms_in_park) over (partition by home_team_id, yr) as max_gms
           from home_gms_by_park
    )
    select home_team_id as tm, yr, park_id
      from home_gms_with_max
     where num_gms_in_park = max_gms -- pick the max
       and num_gms_in_park>3         -- of >3 (e.g., ignore all-star teams)
)

-- now find road games in those team-season-park combos
    select g.away_team_id, g.home_team_id, g.game_dt, g.park_id, p.name
      from retrosheet_game as g
inner join teams_main_parks as t
        on g.away_team_id = t.tm
       and g.park_id = t.park_id
       and extract(year from g.game_dt) = t.yr
inner join retrosheet_park as p -- and add the park name
        on g.park_id = p.park_id
  order by g.game_dt
