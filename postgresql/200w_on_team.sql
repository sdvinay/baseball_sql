-- Find all pitchers with 200 W for a team, along with the date on which they got their 200th win

with
-- start with a list of pitchers who achieved the feat
won200_pitchers as
(
    with
    won200_raw as
    (           select player_id, t.franch_id, sum(p.w) as wins_tm_ct
                  from baseballdatabank_pitching as p
            inner join baseballdatabank_teams as t
                    on p.team_id=t.team_id and p.year_id=t.year_id
              group by player_id, t.franch_id
                having sum(p.w)>=200
    )
        select p.retro_id, p.player_id, p.name_first, p.name_last, w.franch_id, w.wins_tm_ct
          from won200_raw as w
    inner join baseballdatabank_people as p
            on p.player_id = w.player_id
),
-- now find the season with the 200th win
season_200th as
(
    with running_win_totals as -- by first putting together season-by-season running wins totals
    (
        with seasons_all as
        (       select player_id, p.team_id, p.year_id, p.w, t.franch_id from baseballdatabank_pitching as p
            inner join baseballdatabank_teams as t
                    on p.team_id=t.team_id and p.year_id=t.year_id
                 where p.player_id in (select player_id from won200_pitchers)
              order by player_id, year_id
        ),
        seasons_with_franch as
        (
                select s.*, p.retro_id, p.name_first, p.name_last, p.wins_tm_ct from seasons_all as s
            inner join won200_pitchers as p
                    on s.player_id = p.player_id and s.franch_id = p.franch_id
        ),
        running_totals as
        (
                select *,
                       sum(w) over (partition by player_id order by year_id) as w_running_total
                  from seasons_with_franch
        )
        -- and add the previous season's total, to help us find the specific game in the right season
        select *, lag(w_running_total, 1) over (partition by player_id order by year_id) as prev_total
          from running_totals
    
    )

    select *, 200-prev_total as wins_needed
      from running_win_totals
     where w_running_total >= 200 and prev_total < 200
),
win_200th as
(
      with wins_in_season_200th as
           (select s.*, g.date, g.double_header,
                   row_number() over (partition by player_id order by date, double_header) as win_in_season
              from season_200th as s
        inner join retrosheet_gamelog as g
                on s.retro_id = g.winning_pitcher_id and s.year_id=extract(year from g.date)
           )
    select * from wins_in_season_200th where win_in_season=wins_needed
),
results as
(
-- put together the pitcher info with the date from the 200th win (or the year if we don't have the date)
    select p.name_first, p.name_last, p.franch_id, p.wins_tm_ct,
           p.year_id as year_200th, w.date as date_200th_incomplete,
           case when w.date is null then concat(cast(p.year_id as varchar(10)), '-??-??') else cast(w.date as varchar(10)) end as date_200th
      from season_200th as p
 left join win_200th as w
        on w.player_id = p.player_id
  order by wins_tm_ct desc
)
-- and (sigh) concat it all into one string for copy-paste
select concat(rpad(concat(name_first, ' ', name_last), 21, '.'), franch_id, '   ', wins_tm_ct, '  ', date_200th)
  from results
;
