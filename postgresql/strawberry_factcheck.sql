-- Fact-checking Darryl Strawberry's wikipedia page
-- https://en.wikipedia.org/wiki/Darryl_Strawberry#Career_accomplishments


/* He is one of only three players in MLB history to have played for all four of the 
former and current New York-based MLB teams- the Mets, Yankees, Dodgers and Giants. 
The others are Ricky Ledée and José Vizcaíno.
*/
select distinct player_id from baseballdatabank_batting where team_id='LAN' INTERSECT
select distinct player_id from baseballdatabank_batting where team_id='SFN' INTERSECT
select distinct player_id from baseballdatabank_batting where team_id='NYA' INTERSECT
select distinct player_id from baseballdatabank_batting where team_id='NYN';


/* He is one of only five Major League Baseball players to hit two pinch-hit grand slams 
in the same season. The others are Davey Johnson of the Philadelphia Phillies, Mike Ivie 
of the San Francisco Giants, Ben Broussard of the Cleveland Indians, and Brooks Conrad 
of the Atlanta Braves.[18]
*/

with 
ph_slams as (select bat_id, game_id  from retrosheet_event where ph_fl is true and rbi_ct=4),
multi_ph_slam_seasons as
(     select bat_id, extract(year from game_dt) as yr, count(retrosheet_game.game_dt) as num 
        from ph_slams
  inner join retrosheet_game 
          on ph_slams.game_id = retrosheet_game.game_id
    group by bat_id, extract(year from game_dt)
      having count(*)>1
)
-- Now get the name and format the output
    select p.name_first, p.name_last, bat_id, yr, num 
      from multi_ph_slam_seasons
inner join baseballdatabank_people as p
        on p.retro_id = multi_ph_slam_seasons.bat_id
;

/* He had two three-home run games in his career, both of which came against Chicago teams 
and were almost 11 years to the day between each other. The first came against the Cubs on 
August 5, 1985, and the second was on August 6, 1996, against the White Sox. 
*/
select game_dt, opponent_id, b_hr from retrosheet_daily where player_id='strad001' and b_hr>=3;
