-- week 4 ans 
-- 1. Are there any specific provinces, or towns where some sources are more abundant?
select l.province_name,l.town_name ,v.visit_count,
 l.location_id, w.type_of_water_source ,w.number_of_people_served,
 l.location_type ,v.time_in_queue , wp.results
from visits v
left join well_pollution wp
on wp.source_id=v.source_id
inner join location l
on v.location_id=l.location_id
inner join water_source w
on w.source_id=v.source_id
where v.visit_count=1 
-- v.visit_count>=1 
-- and v.location_id = 'AkHa00103' 
;
-- pivot taple total water source for each province_name 
WITH province_totals AS (-- This CTE calculates the population of each province
SELECT
province_name,
SUM(people_served) AS total_ppl_serv
FROM
combined_analysis_table
GROUP BY
province_name
)

SELECT
ct.province_name,
-- These case statements create columns for each type of source.
-- The results are aggregated and percentages are calculated
ROUND((SUM(CASE WHEN source_type = 'river'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS river,

ROUND((SUM(CASE WHEN source_type = 'shared_tap'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS shared_tap,

ROUND((SUM(CASE WHEN source_type = 'tap_in_home'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home,
ROUND((SUM(CASE WHEN source_type = 'tap_in_home_broken'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home_broken,
ROUND((SUM(CASE WHEN source_type = 'well'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS well
FROM
combined_analysis_table ct
JOIN
province_totals pt ON ct.province_name = pt.province_name
GROUP BY
ct.province_name 
ORDER BY
ct.province_name desc;


-- pivot taple total water source for each town_name 
WITH town_totals AS (-- This CTE calculates the population of each province
SELECT
province_name,
town_name
,
SUM(people_served) AS total_ppl_serv
FROM
combined_analysis_table
GROUP BY
province_name,town_name
)

SELECT
ct.province_name, pt.town_name,
-- These case statements create columns for each type of source.
-- The results are aggregated and percentages are calculated
ROUND((SUM(CASE WHEN source_type = 'river'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS river,

ROUND((SUM(CASE WHEN source_type = 'shared_tap'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS shared_tap,

ROUND((SUM(CASE WHEN source_type = 'tap_in_home'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home,
ROUND((SUM(CASE WHEN source_type = 'tap_in_home_broken'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS tap_in_home_broken,
ROUND((SUM(CASE WHEN source_type = 'well'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS well
FROM
combined_analysis_table ct
JOIN
town_totals pt ON ct.province_name = pt.province_name
GROUP BY
ct.province_name ,pt.town_name
ORDER BY
ct.province_name  desc ;

