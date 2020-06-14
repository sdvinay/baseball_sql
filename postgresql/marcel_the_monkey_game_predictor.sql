-- Predicting the winner of a game using basic methods

with results as
(   select game_id, away_team_id, home_team_id, away_score_ct, home_score_ct, game_dt, game_ct
         , extract(year from game_dt) as yr
         , (case when home_score_ct>away_score_ct then 1 else 0 end) as home_win
      from retrosheet_game
     where extract(year from game_dt)>=2000
 ),
team_results as
(   select tr.*, t.franch_id as franch_id
      from ( select game_id, away_team_id as team_id, game_dt, game_ct, 1-home_win as win, yr
               from results
            UNION
             select game_id, home_team_id as team_id, game_dt, game_ct, home_win as win, yr
               from results
           ) tr
inner join baseballdatabank_teams as t
        on tr.team_id=t.team_id_retro and tr.yr=t.year_id

),
team_game_prediction_factors as
(
-- Calculate each type of prediction factor, then UNION them into one common table
    with numbered_game_results as
        (   select *
                 , row_number() over (partition by franch_id     order by game_dt, game_ct) as game_num
                 , sum(win)     over (partition by franch_id     order by game_dt, game_ct) as wins_running_total
                 , row_number() over (partition by franch_id, yr order by game_dt, game_ct) as season_game_num
              from team_results
        ),

    team_inseason_records as
        (   select x.*
                 , coalesce(x.inseason_wins::decimal/
                            (case when x.inseason_gms=0 then 1  else inseason_gms end), 0) as inseason_wpct
              from (    select r.*, r.game_num-prev.game_num as inseason_gms
                             , ((r.wins_running_total-r.win)-(prev.wins_running_total-prev.win)) as inseason_wins
                          from numbered_game_results as r
                    inner join numbered_game_results as prev
                            on r.team_id=prev.team_id
                           and r.yr=prev.yr
                           and prev.season_game_num=1
                   ) x
        ),
     team_results_with_prevyr_records as
        (   select tr.*, (prev.w::decimal/prev.g::decimal) as prevyr_wpct
              from team_results as tr
        inner join baseballdatabank_teams as prev
                on tr.franch_id = prev.franch_id and tr.yr = prev.year_id+1
        ),
     records_prev_162 as
        (   select x.*
                 , coalesce(x.prev162_wins::decimal/
                            (case when x.prev162_gms=0 then 1 else prev162_gms end), 0)::decimal as prev162_wpct
              from (    select r.*
                             , r.game_num-prev.game_num as prev162_gms
                             , r.wins_running_total-prev.wins_running_total-r.win as prev162_wins
                          from numbered_game_results as r
                    inner join numbered_game_results as prev
                            on r.franch_id=prev.franch_id
                           and prev.game_num = (case when r.game_num > 162 then r.game_num-162 else 1 end)
                   ) x
        )

    select game_id, team_id, game_dt, game_ct, inseason_wpct as prediction_factor, 'inseason_wpct' as prediction_type
      from team_inseason_records
   UNION
    select game_id, team_id, game_dt, game_ct, prevyr_wpct as prediction_factor, 'prevyr_wpct' as prediction_type
      from team_results_with_prevyr_records
   UNION
    select game_id, team_id, game_dt, game_ct, prev162_wpct as prediction_factor, 'prev162_wpct' as prediction_type
      from records_prev_162

) ,
results_with_predictions as
(
with prediction_factors_both_teams as
            ( -- collect the predictions of each team into one row per game
                select trh.game_id, trh.prediction_type as prediction_type
                     , trh.prediction_factor as home_pred_factor
                     , tra.prediction_factor as away_pred_factor
                  from results as r
            inner join team_game_prediction_factors as trh
                    on r.game_id = trh.game_id and r.home_team_id=trh.team_id
            inner join team_game_prediction_factors as tra
                    on r.game_id = tra.game_id and r.away_team_id=tra.team_id
                   and trh.prediction_type=tra.prediction_type
            )

            -- Now compare the prediction_factors and see if the prediction was correct
    select r.*, pf.prediction_type as prediction_type
         , (case when pf.home_pred_factor>=pf.away_pred_factor then home_win else 1-home_win end) as prediction_correct
      from results as r
inner join prediction_factors_both_teams as pf
        on r.game_id=pf.game_id
UNION -- HFA is so simple that we just compute it here, rather than creating interim prediction factors
    select r.*, 'hfa' as prediction_type
         , home_win as prediction_correct
      from results as r
)


--how do the different marcel methods do (grouped by month)?
  select x.*
       , (predictions_correct::decimal)/(total_gms::decimal) as prediction_wpct
    from (select extract (month from game_dt) as mo, prediction_type, count(1) as total_gms
               , sum(prediction_correct) as predictions_correct
            from results_with_predictions
        group by rollup(prediction_type, extract (month from game_dt))
         ) x
order by mo, prediction_type
;


