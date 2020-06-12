-- Predicting the winner of a game using basic methods

with results as
(
    select away_team_id, home_team_id, away_score_ct, home_score_ct, game_dt, game_ct,
           extract(year from game_dt) as yr,
           (case when home_score_ct>away_score_ct then 1 else 0 end) as home_win
      from retrosheet_game
     where extract(year from game_dt)>=2010
 ),
team_results as
(
    select away_team_id as team_id, game_dt, game_ct, 1-home_win as win, yr
      from results
     UNION
    select home_team_id as team_id, game_dt, game_ct, home_win as win, yr
      from results
),
team_records as
(
    select *, coalesce(incoming_wins::decimal/(game_num-1)::decimal, 0) as wpct
      from (select *,
                   lag(wins_running_total, 1) over (partition by team_id, yr order by game_dt, game_dt) as incoming_wins
              from ( select *, row_number() over (partition by team_id order by game_dt, game_dt) as game_num,
                            sum(win)  over (partition by team_id, yr order by game_dt, game_dt) as wins_running_total
                       from team_results
                   ) x
           )y
),
results_with_records as
(
    select x.*, trh.wpct as home_wpct
      from (    select results.*, tra.wpct as away_wpct
                  from results
            inner join team_records as tra
                    on results.away_team_id = tra.team_id
                       and results.game_dt = tra.game_dt and results.game_ct = tra.game_ct
           ) x
inner join team_records as trh
        on x.home_team_id = trh.team_id and x.game_dt = trh.game_dt and x.game_ct = trh.game_ct
),
results_with_predictions as
(
    select *,
           (case when home_wpct+.01>=away_wpct then home_win else 1-home_win end) as prediction_correct
      from results_with_records
)

--how often does the home team win?
select (predictions_correct::decimal)/(total_gms::decimal) as prediction_wpct
from (select count(1) as total_gms, sum(prediction_correct) as predictions_correct
        from results_with_predictions
     ) x
;


