INSERT INTO project_progress (
    source_id, 
    Address, 
    Town, 
    Province, 
    Source_type, 
    Improvement, 
    Source_status
)
SELECT
    wr.source_id,
    l.address,
    l.town_name,
    l.province_name,
    wr.type_of_water_source,
    CASE 
        WHEN wel.results = 'Contaminated: Chemical' THEN 'Install RO Filter'
        WHEN wel.results = 'Contaminated: Biological' THEN 'Install UV and RO Filter'
        WHEN wr.type_of_water_source = 'river' THEN 'Drill well'
        WHEN wr.type_of_water_source = 'shared_tap' AND v.time_in_queue >= 30 
            THEN CONCAT('Install ', FLOOR(v.time_in_queue / 30), ' taps nearby')
        WHEN wr.type_of_water_source = 'tap_in_home_broken' THEN 'Diagnose infrastructure'
        ELSE 'General Maintenance' 
    END AS improvement,
    -- هنا التعديل: بدلاً من إدخال نص طويل، سندخل 'In progress' أو 'Backlog' 
    -- حسب ما هو معرف في الـ Constraint الخاص بالمشروع
    'In progress' AS Source_status 
FROM
    water_source wr
LEFT JOIN
    well_pollution wel ON wr.source_id = wel.source_id
INNER JOIN
    visits v ON wr.source_id = v.source_id
INNER JOIN
    location l ON l.location_id = v.location_id
WHERE
    v.visit_count = 1 
    AND (
        wel.results != 'Clean'
        OR wr.type_of_water_source IN ('tap_in_home_broken', 'river')
        OR (wr.type_of_water_source = 'shared_tap' AND v.time_in_queue >= 30)
    );
    
   -- How many UV filters do we have to install in total?


select  Improvement,count(*) as count
from project_progress
group by Improvement 
having Improvement= 'Install UV and RO Filter'or Improvement= 'Install RO Filter'
order by count(*) desc;

-- data validation to the origin data 
SELECT 
    results, 
    COUNT(*) 
FROM 
    well_pollution
WHERE 
    results IN ('Contaminated: Biological', 'Contaminated: Chemical')
GROUP BY 
    results;
    
    -- Data Auditing
    SELECT 
    (SELECT COUNT(*) FROM well_pollution WHERE results = 'Contaminated: Biological') AS Original_Count,
    (SELECT COUNT(*) FROM project_progress WHERE Improvement = 'Install UV and RO Filter') AS Progress_Count;
    -- there are an dublicate in our data in taple project_progress
     -- we will fix that first delete data from taple 
     SET SQL_SAFE_UPDATES = 0;
     delete from  project_progress;
     -- 2- insert distincit data
     SET SQL_SAFE_UPDATES = 1;
     
     INSERT INTO project_progress (
    source_id, 
    Address, 
    Town, 
    Province, 
    Source_type, 
    Improvement, 
    Source_status
)
SELECT DISTINCT -- كلمة DISTINCT هنا تمنع تكرار نفس الصف
    wr.source_id,
    l.address,
    l.town_name,
    l.province_name,
    wr.type_of_water_source,
    CASE 
        WHEN wel.results = 'Contaminated: Chemical' THEN 'Install RO Filter'
        WHEN wel.results = 'Contaminated: Biological' THEN 'Install UV and RO Filter'
        WHEN wr.type_of_water_source = 'river' THEN 'Drill well'
        WHEN wr.type_of_water_source = 'shared_tap' AND v.time_in_queue >= 30 
            THEN CONCAT('Install ', FLOOR(v.time_in_queue / 30), ' taps nearby')
        WHEN wr.type_of_water_source = 'tap_in_home_broken' THEN 'Diagnose infrastructure'
        ELSE 'General Maintenance' 
    END AS improvement,
    'In progress' -- الحالة الافتراضية كما اتفقنا
FROM
    water_source wr
LEFT JOIN
    well_pollution wel ON wr.source_id = wel.source_id
INNER JOIN
    visits v ON wr.source_id = v.source_id
INNER JOIN
    location l ON l.location_id = v.location_id
WHERE
    v.visit_count = 1 -- نضمن أنها الزيارة الأولى فقط
    AND (
        wel.results != 'Clean'
        OR wr.type_of_water_source IN ('tap_in_home_broken', 'river')
        OR (wr.type_of_water_source = 'shared_tap' AND v.time_in_queue >= 30)
    );
    
/*If you were to modify the query to include the percentage of people served by only dirty wells as a water source, 
which part of the town_aggregated_water_access CTE would you need to change?

AND ct.results != 'Clean'
*/
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
ROUND((SUM(CASE WHEN source_type = 'well' -- AND ct.results != 'Clean'
THEN people_served ELSE 0 END) * 100.0 / pt.total_ppl_serv), 0) AS well
FROM
combined_analysis_table ct
JOIN
province_totals pt ON ct.province_name = pt.province_name
GROUP BY
ct.province_name
ORDER BY
ct.province_name;


-- 3 Which province should we send drilling equipment to first?
select Province, count(*),Improvement
from project_progress
where Improvement='Drill well'
group by Province, Improvement
order by count(*);


/* Which towns should we upgrade shared taps first?

Ilanga, Bahari, Harare
Zuri, Abidjan, Bello
Zanzibar, Isiqalo, Marang
Majengo, Serowe, Yaounde*/

SELECT 
    town_name, 
    COUNT(*) AS num_of_taps,
    sum(time_in_queue) AS avg_wait_time 
FROM 
    combined_analysis_table
WHERE 
    source_type = 'shared_tap'
GROUP BY 
    town_name
ORDER BY 
    avg_wait_time DESC
    limit 5;

-- What is the maximum percentage of the population using rivers in a single town in the Amanzi province?
WITH TownTotals AS (
    -- حساب إجمالي السكان لكل مدينة داخل أمانزي
    SELECT 
        town_name, 
        SUM(people_served) AS total_town_ppl
    FROM 
        combined_analysis_table
    WHERE 
        province_name = 'Amanzi'
    GROUP BY 
        town_name
),
RiverPerTown AS (
    -- حساب سكان الأنهار لكل مدينة داخل أمانزي
    SELECT 
        town_name, 
        SUM(people_served) AS river_ppl
    FROM 
        combined_analysis_table
    WHERE 
        province_name = 'Amanzi' 
        AND source_type = 'river'
    GROUP BY 
        town_name
)
SELECT 
    rt.town_name,
    ROUND((rt.river_ppl * 100.0 / tt.total_town_ppl), 0) AS river_percentage
FROM 
    RiverPerTown rt
JOIN 
    TownTotals tt ON rt.town_name = tt.town_name
ORDER BY 
    river_percentage DESC;


/* In which province(s) do all towns have less than 50% access to home taps (including working and broken)?

No towns fulfil this requirement.
Kilimani, Hawassa, Sokoto, and Akatsi.
Amanzi, Sokoto, and Akatsi.
Hawassa.*/

WITH TownAccess AS (
    -- 1. نحسب إجمالي السكان ونسبة الوصول لكل مدينة
    SELECT 
        province_name,
        town_name,
        SUM(CASE WHEN source_type IN ('tap_in_home', 'tap_in_home_broken') THEN people_served ELSE 0 END) * 100.0 / SUM(people_served) AS home_tap_access
    FROM 
        combined_analysis_table
    GROUP BY 
        province_name, town_name
),
ProvinceCheck AS (
    -- 2. نحدد المدن اللي "خالفت" الشرط (أكبر من أو يساوي 50%)
    SELECT 
        province_name,
        SUM(CASE WHEN home_tap_access >= 50 THEN 1 ELSE 0 END) AS towns_above_50
    FROM 
        TownAccess
    GROUP BY 
        province_name
)
-- 3. نختار فقط المقاطعات اللي مفيش فيها ولا مدينة فوق الـ 50%
SELECT 
    province_name
FROM 
    ProvinceCheck
WHERE 
    towns_above_50 = 0;
    
    
    SELECT
project_progress.Project_id, 
project_progress.Town, 
project_progress.Province, 
project_progress.Source_type, 
project_progress.Improvement,
Water_source.number_of_people_served,
RANK() OVER(PARTITION BY Province ORDER BY number_of_people_served)
FROM  project_progress 
JOIN water_source 
ON water_source.source_id = project_progress.source_id
WHERE Improvement = "Drill Well"
ORDER BY Province DESC, number_of_people_served;