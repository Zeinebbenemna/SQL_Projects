-- Find the unique types of water sources 
SELECT distinct type_of_water_source
FROM water_source ;

-- checking the format of the time in queue column 
SELECT time_in_queue
FROM visits ;

-- Retrieving all records from visists table where the time_in_queue is more than 500 minutes 
SELECT *
FROM visits 
WHERE time_in_queue > 500 ;

-- Check the types of water source that has a time in queue higher than 500 minutes 
SELECT v.source_id ,
v.time_in_queue ,
ws.type_of_water_source ,
ws.number_of_people_served
FROM visits v
JOIN water_source ws
ON v.source_id=ws.source_id 
WHERE time_in_queue > 500 ;

-- Check the types of water source that has a time in queue equal to 0
SELECT v.source_id ,
v.time_in_queue ,
ws.type_of_water_source ,
ws.number_of_people_served
FROM visits v
JOIN water_source ws
ON v.source_id=ws.source_id 
WHERE time_in_queue=0;

-- Find the records where the subject quality score is 10 for home taps and where the source was visited a second time 
SELECT *
FROM water_quality
WHERE subjective_quality_score=10 AND visit_count=2;

-- Checks if the results is Clean but the biological column is > 0.01
SELECT *
FROM well_pollution
WHERE biological > 0.01 AND results = "Clean"
ORDER BY biological DESC ;

-- To fix misclassified water quality records caused by incorrect use of the word “Clean” in descriptions and results
 UPDATE well_pollution 
 SET description = 'Bacteria: E. coli' 
 WHERE description = 'Clean Bacteria: E. coli';
 UPDATE well_pollution
 SET description = 'Bacteria: Giardia Lamblia' 
 WHERE description = 'Clean Bacteria: Giardia Lamblia';
 UPDATE well_pollution
 SET results = 'Contaminated: Biological' 
 WHERE biological > 0.01 AND results = 'Clean';
