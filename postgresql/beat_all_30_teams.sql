
with wins as
(      select game_id, game_dt, game_ct, win_pit_id, extract (year from game_dt) as year_id,
              (case when home_score_ct>away_score_ct then away_team_id else home_team_id end) as opp_tm_id
         from retrosheet_game
        where extract(year from game_dt) >= 1975
),
wins_annotated as
(      select w.*, t.franch_id as opp_franch_id
         from wins as w
   inner join baseballdatabank_teams as t
           on w.opp_tm_id=t.team_id_retro and w.year_id=t.year_id
),
beat_30tms_pitchers as
(      select win_pit_id from wins_annotated
     group by win_pit_id
       having count(distinct opp_franch_id)=30
)

    select p.name_first, p.name_last, bp.*
      from beat_30tms_pitchers as bp
inner join baseballdatabank_people as p
        on p.retro_id = bp.win_pit_id

;
