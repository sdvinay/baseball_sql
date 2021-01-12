-- Somebody on Jomboy's show said that every WS since 1987 has included a teammate of Jason Giambi
-- Is this true?  Is this rare?

with ws_players as
(   select player_id, team_id, year_id from baseballdatabank_batting_post where round ='WS' and year_id>1950)
, giambi_teammates as
(   select distinct(b.player_id)
      from baseballdatabank_batting as b
inner join baseballdatabank_batting as g
        on b.team_id = g.team_id and b.year_id=g.year_id and g.player_id='giambja01'
)

-- enumerate the teammates
--select *  from ws_players as p where p.player_id in (select * from giambi_teammates) order by year_id;

-- get a count by year
  select year_id, count(player_id) as num_giambi_teammates
    from ws_players as p
   where p.player_id in (select * from giambi_teammates)
group by year_id
order by year_id;
