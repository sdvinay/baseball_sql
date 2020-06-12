
with wins as -- all wins since 1975, including the pitcher's ID and the opponent's team ID
(      select game_id, game_dt, game_ct, win_pit_id, extract (year from game_dt) as year_id,
              (case when home_score_ct>away_score_ct then away_team_id else home_team_id end) as opp_tm_id
         from retrosheet_game
        where extract(year from game_dt) >= 1975
),
wins_annotated as  -- add the franchise ID
(      select w.*, t.franch_id as opp_franch_id
         from wins as w
   inner join baseballdatabank_teams as t
           on w.opp_tm_id=t.team_id_retro and w.year_id=t.year_id
),
beat_30tms_pitchers as -- find the pitchers who've beaten all 30 teams
(      select win_pit_id from wins_annotated
     group by win_pit_id
       having count(distinct opp_franch_id)=30
),
first_win_vs_tm as -- find each pitcher's first win against each team
(      select  *
          from (select *,
                       row_number() over (partition by win_pit_id, opp_franch_id order by game_dt, game_ct) as win_vs_tm
                  from wins_annotated
                 where win_pit_id in (select * from beat_30tms_pitchers)
               ) x
         where win_vs_tm=1
),
last_first_wins as -- the last one for each pitcher is the day they joined the club
(      select win_pit_id, max(game_dt) as date_30th_franchise_beaten
         from first_win_vs_tm
     group by win_pit_id
)
-- format the output
    select rpad(concat(p.name_first, ' ', p.name_last), 21, '.') as name, bp.date_30th_franchise_beaten
      from last_first_wins as bp
inner join baseballdatabank_people as p
        on p.retro_id = bp.win_pit_id
  order by bp.date_30th_franchise_beaten

;
