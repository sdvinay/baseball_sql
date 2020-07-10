-- When have Cy Young winners faced off in the WS?
-- Used to make this reddit comment:
-- https://www.reddit.com/r/baseball/comments/hh1u3z/former_cy_young_award_winners_in_the_world_series/fw89yb3/

with cy_winners as
(
    -- start with the winners
    with winners as
    (
          select player_id, min(year_id) as first_win
            from baseballdatabank_awards_players
           where award_id='Cy Young Award'
        group by player_id
    )

        -- add the name and retro_id
    select c.*, p.retro_id, p.name_first, p.name_last
      from winners as c
inner join baseballdatabank_people as p
        on c.player_id = p.player_id
)

, ws_games as
(
    select home_team, visiting_team, date, extract(year from date) as yr
         , visitor_starting_pitcher_id, home_starting_pitcher_id, visiting_team_game_number as game_num
      from retrosheet_gamelog
     where extract(month from date) >= 10
       and visiting_team_league <> home_team_league
       and visiting_team_game_number < 10
)

    select g.yr, g.game_num, g.date, concat(g.visiting_team, ' @ ', g.home_team) as teams
         , concat(pv.name_first, ' ', pv.name_last, ' (', pv.first_win, ')') as visiting_pit
         , concat(ph.name_first, ' ', ph.name_last, ' (', ph.first_win, ')') as home_pit
      from ws_games as g
inner join cy_winners as pv on g.visitor_starting_pitcher_id=pv.retro_id
inner join cy_winners as ph on    g.home_starting_pitcher_id=ph.retro_id
        -- play with the last 'and' clause to get the different variations
        -- (e.g., whether past Cy winner, current year, future, etc)
       and ((g.yr> pv.first_win) and (g.yr> ph.first_win)) -- previous winners
--     and ((g.yr>=pv.first_win) and (g.yr>=ph.first_win)) -- previous winners and current year
--     and ((g.yr< pv.first_win) or  (g.yr< ph.first_win)) -- future winners
