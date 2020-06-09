
-- how complete is the gwrbi reporting by year?
  select yr, count(gwrbi_appears) as gm_ct, sum(gwrbi_appears) as gwrbi_ct
    from
         (
            select extract(year from date) as yr,
                   (case when (game_winning_rbi_id is not null) then 1 else 0 end) as gwrbi_appears
              from retrosheet_gamelog
         ) gwrbi
group by yr
;

-- how complete is the gwrbi reporting during the Ruth/Gehrig era?
  select game_winning_rbi_id as batter, count(*) as gwrbi_ct
    from retrosheet_gamelog
   where extract(year from date) between 1920 and 1934
         and (case when home_runs_score>visitor_runs_scored then home_team else visiting_team end)='NYA'
group by game_winning_rbi_id
;

-- GWRBI career leaders
with
gwrbi_official as
(            --retrosheet_game has official gwrbi only

              select gwrbi_bat_id as batter, count(distinct game_id) as gwrbi_official_ct
                from retrosheet_game
               where gwrbi_bat_id is not null
            group by gwrbi_bat_id
            ),
gwrbi_all as
            (--retrosheet_gamelog has gwrbi, regardless of whether it's official
              select game_winning_rbi_id as batter, count(*) as gwrbi_ct
                from retrosheet_gamelog
               where game_winning_rbi_id is not null
            group by game_winning_rbi_id
            ),
career_rbis as
            (
              select player_id, sum(rbi) as career_rbi
                from baseballdatabank_batting
               where rbi is not null
            group by player_id
            )
    select p.name_first, p.name_last, p.player_id, gwrbi_ct, r.career_rbi
      from gwrbi_all as gw
inner join baseballdatabank_people p
        on p.retro_id=gw.batter
inner join career_rbis as r
        on gw.batter=r.player_id
  order by gwrbi_ct desc
           limit 100
;
-- why does Aaron have "official" GWRBI?
select * from retrosheet_game where gwrbi_bat_id='aaroh101';

              select extract(year from date) as yr, count(*) as gwrbi_ct
                from
            group by extract(year from date);

select * from retrosheet_gamelog where game_winning_rbi_id='pujoa001' and extract(year from date)=2006;
select * from retrosheet_gamelog where game_winning_rbi_id='hernk001' and extract(year from date)=1985;
select * from retrosheet_gamelog where game_winning_rbi_id='maysw101' and extract(year from date)=1962;

