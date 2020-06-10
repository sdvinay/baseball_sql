-- Find the players who have hit 3-HR games in both leagues, in the order in which they achieved the feat


with
thgs as
(       select distinct player_id, team_id, game_id from retrosheet_daily where b_hr>=3
),
thgs_annotated as -- add the lg_id and game_dt
(       select t.*, g.game_dt as game_dt,
               (case when g.home_team_id=t.team_id then g.home_team_league_id else g.away_team_league_id end) as lg_id
          from thgs as t
    inner join retrosheet_game as g on g.game_id=t.game_id
),
thgs_lg_cts as
(  -- can't do COUNT DISTINCT in a window function, so we have to do this two-step hack to add columns
   -- to find the first 3HR-game hit in a new league
        select *,
               sum(new_lg) over (partition by player_id) as lg_ct
          from (select a.*,
                       (case when (row_number() over( partition by player_id, lg_id) = 1) then 1 else 0 end) as new_lg
                  from thgs_annotated as a
               ) x
),
players_both_lgs as
(
        select player_id, max(game_dt) as achieved_dt
          from thgs_lg_cts
         where lg_ct>1 and new_lg=1
      group by player_id
)

-- Add the name and format the output
    select achieved_dt, concat(p.name_first, ' ', p.name_last) as player
      from players_both_lgs as pbl
inner join baseballdatabank_people as p
        on p.retro_id=pbl.player_id
  order by achieved_dt


;
