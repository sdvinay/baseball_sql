# Most batting outs in a season

select *, ab-h+sh+sf+gidp as outs from baseballdatabank.batting 
order by ab-h+sh+sf+gidp desc
limit 20