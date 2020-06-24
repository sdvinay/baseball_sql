-- how much does a missed season hurt the chances of various players to reach milestones?


with hit_seasons as (
    select b.player_id, year_id, h, b.year_id-p.birth_year as age, p.birth_year
      from baseballdatabank_batting as b
inner join baseballdatabank_people as p
        on b.player_id = p.player_id
)

-- Castro had 470 hits between ages 27 and 29
-- Castro had 925 hits between ages 24 and 29
-- Markakis had 808 hits between ages 31 and 35 
-- Markakis had 867 hits between ages 30 and 34
, similar_hitters as (
    select player_id, max(birth_year) as birth_year, sum(h) as hits_recent
      from hit_seasons
     where age between 30 and 34
       and birth_year < 1978 -- 12 years younger than Castro
  group by player_id
    having sum(h) between 807 and 927
  order by sum(h) desc
)
--select * from similar_hitters;
, remaining_careers as (
    select player_id, sum(h) as hits_after
      from hit_seasons
     where age > 34
       and player_id in (select player_id from similar_hitters)
  group by player_id
)
   select s.*, c.hits_after
     from similar_hitters as s
left join remaining_careers as c
       on c.player_id = s.player_id
--  where hits_after >= 645

;
