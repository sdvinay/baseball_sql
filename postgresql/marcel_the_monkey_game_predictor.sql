-- Predicting the winner of a game using basic methods

with results as
(   select away_team_id, home_team_id, away_score_ct, home_score_ct, game_dt, game_ct,
           extract(year from game_dt) as yr,
           (case when home_score_ct>away_score_ct then 1 else 0 end) as home_win
      from retrosheet_game
     where extract(year from game_dt)>=2000
 ),
team_results as
(   select away_team_id as team_id, game_dt, game_ct, 1-home_win as win, yr
      from results
     UNION
    select home_team_id as team_id, game_dt, game_ct, home_win as win, yr
      from results
),
team_inseason_records as
(   select *, coalesce(incoming_wins::decimal/(game_num-1)::decimal, 0) as wpct
      from (select *,
                   lag(wins_running_total, 1) over (partition by team_id, yr order by game_dt, game_dt) as incoming_wins
              from ( select *
                            , row_number() over (partition by team_id, yr order by game_dt, game_ct) as game_num
                            ,     sum(win) over (partition by team_id, yr order by game_dt, game_ct) as wins_running_total
                       from team_results as tr
                   ) x
           )y
),
team_results_with_prevyr_records as
(   select tr.*, (t.w::decimal/t.g::decimal) as prev_wpct
      from team_inseason_records as tr
inner join baseballdatabank_teams as t
        on tr.team_id = t.team_id_retro
           and tr.yr = t.year_id+1
),
results_with_predictors as
(
    select r.*, trh.wpct as home_wpct, tra.wpct as away_wpct, trh.prev_wpct as home_prev_wpct, tra.prev_wpct as away_prev_wpct
      from results as r
inner join team_results_with_prevyr_records as trh
        on r.home_team_id=trh.team_id and r.game_dt=trh.game_dt and r.game_ct=trh.game_ct
inner join team_results_with_prevyr_records as tra
        on r.away_team_id=tra.team_id and r.game_dt=tra.game_dt and r.game_ct=tra.game_ct
),
results_with_predictions as
(
    select *
           , (case when home_wpct>=away_wpct then home_win else 1-home_win end) as wpct_prediction_correct
           , (case when home_prev_wpct>=away_prev_wpct then home_win else 1-home_win end) as wpct_prev_prediction_correct
      from results_with_predictors
)

--how do different marcel methods do?
  select mo, total_gms
         , wpct_predictions_correct, (wpct_predictions_correct::decimal)/(total_gms::decimal) as wpct_prediction_wpct
         , wpct_predictions_correct, (wpct_prev_predictions_correct::decimal)/(total_gms::decimal) as wpct_prev_prediction_wpct
    from (select extract (month from game_dt) as mo, count(1) as total_gms
               , sum(wpct_prediction_correct) as wpct_predictions_correct
               , sum(wpct_prev_prediction_correct) as wpct_prev_predictions_correct
          from results_with_predictions
      group by rollup(extract (month from game_dt))
         ) x
order by mo
;


