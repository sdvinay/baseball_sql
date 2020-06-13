-- Inspired by Ripken passing Everett Scott 30 years ago today, thinking about players playing every game in a season.
-- Who are the leaders in seasons where they've played in all of their team's games?

with player_season_counts as 
(          select p.player_id, count(p.year_id) as season_ct, min(p.year_id) as first, max(p.year_id) as last
             from baseballdatabank_batting as p
       inner join baseballdatabank_teams as t
               on p.year_id=t.year_id and p.team_id = t.team_id
            where p.g=t.g and p.year_id>=1900
         group by p.player_id
)
    select concat(p.name_first, ' ', p.name_last) as player_name, psc.season_ct, psc.first, psc.last, (psc.last-psc.first-season_ct+1) as gaps
      from player_season_counts as psc
inner join baseballdatabank_people as p
        on psc.player_id = p.player_id
  order by season_ct desc, last desc