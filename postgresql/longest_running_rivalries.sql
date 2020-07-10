-- Opponents who have played each other every year for the longest

with opponents as
(
    select extract(year from date) as yr, home_team, visiting_team
      from retrosheet_gamelog
  group by extract(year from date)      , home_team, visiting_team
)
, matchups as (
-- convert to franchise IDs,
-- and concatenate into a matchup (in alphabetical order)
    select distinct o.yr
                  , case when th.franch_id<tv.franch_id then concat(th.franch_id, '-', tv.franch_id)
                                                        else concat(tv.franch_id, '-', th.franch_id)
                    end as matchup
      from opponents as o
inner join baseballdatabank_teams as th on     o.home_team=th.team_id_retro and o.yr=th.year_id
inner join baseballdatabank_teams as tv on o.visiting_team=tv.team_id_retro and o.yr=tv.year_id
)
, streak_finder as (
-- identify which years are consecutive -- they'll have the same (yr-row_number())
    select m.*
         , yr-row_number() over (partition by matchup order by yr) as streak_id
      from matchups as m
)
, streaks as (
    select matchup, min(yr) as start_yr, max(yr) as end_yr, count(yr) as length
      from streak_finder
  group by matchup, streak_id
)
  select *
    from streaks
   where end_yr=2019
order by length desc
;
