-- Find hitting streaks
--  Algorithm: number each batting game by player, then filter on games with hits and number those games
--    The difference between the two game numbers is the index of the hitting streak
--    Group by this difference to aggregate streaks


-- Create a temp table of hitting streaks, since this is the time-consuming step (~120s for the entire dataset, 826729 streaks)
drop table t_hitting_streaks;
create table t_hitting_streaks as
(
with dailies as
            (
              select game_id, game_dt, game_ct, player_id, b_h, b_ab, b_pa,
                     ROW_NUMBER() OVER (partition by player_id ORDER BY game_dt, game_ct) AS game_num
                from retrosheet_daily
               where b_pa>0 -- and extract(year from game_dt)=1940
                     and team_id not in ('ALS', 'NLS', 'AL1', 'AL2', 'NL1', 'NL2')
            ),
     dailies_with_hits as
            (
              select *, ROW_NUMBER()  OVER (partition by player_id ORDER BY game_dt, game_ct) AS game_with_hit_num
                from dailies
               where b_h>0
            ),
     dailies_with_streak_nums as
            (
              select *, game_num-game_with_hit_num as streak_num
                from dailies_with_hits
            )
    select player_id, min(game_dt) as start_dt, max(game_dt) as end_dt, count(distinct game_id) as length,
           sum(b_h) as total_h, sum(b_ab) as total_ab, sum(b_pa) as total_pa
      from dailies_with_streak_nums
  group by player_id, streak_num
);

-- longest hitting streaks
    select p.name_first, p.name_last, hs.*
      from t_hitting_streaks as hs
inner join baseballdatabank_people as p
        on hs.player_id = p.retro_id
     where length > 30
  order by length desc
;

-- highest BA during long streaks
    select p.name_first, p.name_last, hs.*, round(total_h::decimal/total_ab, 3) as streak_ba
      from t_hitting_streaks as hs
inner join baseballdatabank_people as p
        on hs.player_id = p.retro_id
     where length > 30
  order by streak_ba desc
;


-- most long streaks
with
multiple_long_streaks as
(
        select hs.*, count(*) over (partition by player_id) as num_streaks
          from (select * from t_hitting_streaks where length>=20) hs
),
summary_of_long_streaks as
(
        select player_id, max(num_streaks) as num_streaks, max(length) as longest_streak,
               min(start_dt) as first_start_dt, max(start_dt) as last_start_dt
          from multiple_long_streaks as mls
      group by player_id
)
--    select * from summary_of_long_streaks order by num_streaks desc;

    select p.name_first, p.name_last, sls.*
      from summary_of_long_streaks as sls
inner join baseballdatabank_people as p
        on sls.player_id = p.retro_id
     where num_streaks>1
  order by num_streaks desc, longest_streak desc
