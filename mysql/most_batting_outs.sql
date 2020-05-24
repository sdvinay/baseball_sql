-- Most batting outs in a season

-- AB-H is simple and consistent across baseball history, but missing some types of outs
select *, ab-h as simple_outs from baseballdatabank.batting 
order by simple_outs desc limit 20;

-- I think this is the best way to capture "batting outs" (would be even better if we could subtract ROE)
-- But some categories are incomplete historically, so comparing across eras may be problematic
select *, ab-h+sh+sf+gidp as batting_outs from baseballdatabank.batting 
order by batting_outs desc limit 20;

-- baseball-reference includes CS in their "outs" leaders, but not other baserunning outs.  Meh.
select *, ab-h+sh+sf+gidp+cs as baseball_reference_outs from baseballdatabank.batting 
order by baseball_reference_outs desc limit 20;

