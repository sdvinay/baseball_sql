-- Most batting outs in a season

-- AB-H is simple and consistent across baseball history, but missing some types of outs

-- I think including SF/SH/GIDP is the best way to capture "batting outs" (would be even better if we could subtract ROE)
-- But some categories are incomplete historically, so comparing across eras may be problematic

-- baseball-reference includes CS in their "outs" leaders, but not other baserunning outs.  Meh.


with inputs as
(select player_id, year_id, ab, h, coalesce(sh,0) as sh, coalesce(sf,0) as sf,  coalesce(gidp,0) as gidp, coalesce(cs, 0) as cs
   from baseballdatabank_batting)


  select inputs.*, ab-h as simple_outs, ab-h+sf+sf+gidp as batting_outs, ab-h+sh+sf+gidp+cs as baseball_reference_outs
    from inputs
order by simple_outs desc limit 200;
