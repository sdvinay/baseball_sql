-- Which teams have gotten most of their starts from their top 5 starters?

with player_seasons as -- all player-seasons, ranked among their team
(   select player_id, team_id, year_id, gs,
           row_number() over (partition by team_id, year_id order by gs desc) as rank_on_tm
      from baseballdatabank_pitching
     where year_id>=1947 and gs>0
)
, top5_gs as -- team-season total for top 5
(   select team_id, year_id, sum(gs) as gs_top_5
      from player_seasons
     where rank_on_tm<=5
  group by team_id, year_id
)
, total_gs as -- team-season total for whole team
(   select team_id, year_id, sum(gs) as gs_total
      from player_seasons
  group by team_id, year_id
)
-- order by pct from top 5
    select top5.*, tot.gs_total, top5.gs_top_5::decimal/tot.gs_total::decimal as pct_top5
      from top5_gs as top5
inner join total_gs as tot
        on top5.team_id = tot.team_id and top5.year_id = tot.year_id
  order by pct_top5 desc
