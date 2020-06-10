-- Find the players who have hit 3-HR games in both leagues, in the order in which they achieved the feat


with
thgs as -- all three-homer-games (THG)
(       select distinct player_id, team_id, game_id from retrosheet_daily where b_hr>=3
),
thgs_annotated as -- add the lg_id and game_dt
(       select t.*, g.game_dt as game_dt,
               (case when g.home_team_id=t.team_id then g.home_team_league_id else g.away_team_league_id end) as lg_id
          from thgs as t
    inner join retrosheet_game as g on g.game_id=t.game_id
),
thg_first_in_leagues as
(  -- Find each player's first THG in each league (by numbering them by player/league first)
        select *
          from (select a.*,
                       row_number() over( partition by player_id, lg_id order by game_dt) as thg_in_lg
                  from thgs_annotated as a
               ) x
         where thg_in_lg=1

),
players_both_lgs as
( -- Find players with two first-THG-in-a-league
        select player_id, min(game_dt) as first_league_dt, max(game_dt) as second_league_dt
          from thg_first_in_leagues
      group by player_id
        having count(thg_in_lg)=2
)

-- Add the name and format the output
    select first_league_dt, second_league_dt, concat(p.name_first, ' ', p.name_last) as player
      from players_both_lgs as pbl
inner join baseballdatabank_people as p
        on p.retro_id=pbl.player_id
  order by second_league_dt
;
