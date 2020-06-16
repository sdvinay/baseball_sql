-- How many HOFers played in each season?
with HOFers as
(   select distinct(player_id)
      from baseballdatabank_hall_of_fame
     where inducted='Y' and category='Player'
),
HOFers_by_year as
(   select year_id, count(distinct a.player_id) as hofer_ct
      from HOFers as h
inner join baseballdatabank_appearances as a
        on h.player_id=a.player_id
  group by a.year_id
),
batting as
(   select year_id, player_id, ab+bb as pa, h, hr, r, rbi, sb
         , player_id in (select * from HOFers) as hof_fl
      from baseballdatabank_batting
),
batting_totals as
(   select year_id, hof_fl, sum(pa) as pa, sum(h) as h, sum(hr) as hr, sum(r) as r, sum(rbi) as rbi, sum(sb) as sb
      from batting
  group by rollup(year_id, hof_fl)
),
pitching as
(   select year_id, player_id, ip_outs, gs, w, so, sv
         , player_id in (select * from HOFers) as hof_fl
      from baseballdatabank_pitching
),
pitching_totals as
(   select year_id, hof_fl, sum(ip_outs) as ip_outs, sum(gs) as gs, sum(w) as w, sum(so) as so, sum(sv) as sv
      from pitching
  group by rollup(year_id, hof_fl)
),
hof_pcts_batting as
(   select t.year_id
         , h.pa::decimal/t.pa as pa_hof_pct, h.h::decimal/t.h as h_hof_pct
         , h.hr::decimal/t.hr as hr_hof_pct, h.sb::decimal/t.sb as sb_hof_pct
      from batting_totals as t
inner join batting_totals as h
        on t.year_id=h.year_id
       and t.hof_fl is null and h.hof_fl=true
),
hof_pcts_pitching as
(   select t.year_id
         , h.ip_outs::decimal/t.ip_outs as ipouts_hof_pct
         , h.w::decimal/t.w as w_hof_pct, h.gs::decimal/t.gs as gs_hof_pct
         , h.so::decimal/t.so as so_hof_pct, h.sv::decimal/t.sv as sv_hof_pct
      from pitching_totals as t
inner join pitching_totals as h
        on t.year_id=h.year_id
       and t.hof_fl is null and h.hof_fl=true
)

    select b.*, p.*
      from hof_pcts_batting as b
inner join hof_pcts_pitching as p
        on b.year_id=p.year_id
  order by b.year_id
;


select * from HOFers_by_year;
select avg(hofer_ct) from HOFers_by_year where year_id between 1890 and 1995
