# Most batting outs in a season

# AB-H is simple and consistent across baseball history, but missing some outs
select *, ab-h as simple_outs from baseballdatabank.batting 
order by simple_outs desc limit 20;

# I think this is the best way to capture "batting outs" (would be better if we could subtract ROE)
# but some categories are incomplete historically, so we have less certainty about the output
select *, ab-h+sh+sf+gidp as batting_outs from baseballdatabank.batting 
order by batting_outs desc limit 20;

# baseball-reference includes CS in their "outs" leaders, but not other baserunning outs.  Meh.
select *, ab-h+sh+sf+gidp+cs as baseball_reference_outs from baseballdatabank.batting 
order by baseball_reference_outs desc limit 20;

