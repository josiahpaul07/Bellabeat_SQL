SELECT 
 COUNT(DISTINCT Id)
 FROM `white-form-355300.Bellabeat.sleepDay_merged`
;

SELECT 
 COUNT(DISTINCT Id)
 FROM `white-form-355300.Bellabeat.dailyActivity`
;

SELECT 
  Id,
  ActivityDate,
  COUNT(*) as num_of_id
FROM 
  `white-form-355300.Bellabeat.dailyActivity`
GROUP BY
  Id, ActivityDate
HAVING 
  num_of_id > 1

-- no data to display / no duplicates in daily_activity
;
  
  
SELECT 
  Id,
  SleepDay,
  COUNT(*) as num_of_id
FROM 
  `white-form-355300.Bellabeat.sleepDay_merged`
GROUP BY
  Id, SleepDay
HAVING 
  num_of_id > 1

-- displays 3 duplicates

;
CREATE or REPLACE TABLE `white-form-355300.Bellabeat.sleepDay_merged_new`
AS SELECT *, PARSE_DATE('%m %d %Y',  SleepDayNew) AS formattedDate,
FROM
(
  SELECT *, 
  ROW_NUMBER() 
  OVER (PARTITION BY Id, SleepDay)
  row_number,
REPLACE(SleepDay, '/', ' ') AS SleepDayNew,
  FROM `white-form-355300.Bellabeat.sleepDay_merged`
)
WHERE row_number = 1
;

--checking if there are rows with nulls in totalstep column
SELECT 
  Id, 
  Count(*) as num_of_zero_steps
FROM `white-form-355300.Bellabeat.dailyActivity` 
WHERE 
  TotalSteps = 0
GROUP BY Id
ORDER BY num_of_zero_steps
;

--cleaning the empty data column and changing the date format afterfards storing it in a new table
CREATE TABLE `white-form-355300.Bellabeat.dailyActivity_new`
AS SELECT *,
PARSE_DATE('%m %d %Y',  ActivityDateNew) AS formattedDate,
FROM (
  SELECT *, REPLACE(ActivityDate, '/', ' ') AS ActivityDateNew
  FROM `white-form-355300.Bellabeat.dailyActivity` 
)
WHERE 
  TotalSteps <> 0
;

--Check for null data
SELECT *
FROM `white-form-355300.Bellabeat.dailyActivity`
WHERE Id IS NULL
-- no data display
;

SELECT *
FROM `white-form-355300.Bellabeat.sleepDay_merged_new`
WHERE Id IS NULL
-- no data display
;

--categorizing the total step into a qualitative performance and grading individuals on which range they fall under
SELECT COUNT(*) AS numOfActivity,
CASE
  WHEN TotalSteps < 5000 THEN 'Sedentary'
  WHEN TotalSteps BETWEEN 5001 AND 7500 THEN 'Lightly Active'
  WHEN TotalSteps BETWEEN 7501 AND 10000 THEN 'Fairly Active'
  WHEN TotalSteps > 10000 THEN 'Very Active'
  END AS user_level
FROM `white-form-355300.Bellabeat.dailyActivity_new`
GROUP BY user_level
;

--______________________
SELECT VeryActiveMinutes,
FairlyActiveMinutes,
LightlyActiveMinutes,
SedentaryMinutes,
case
WHEN VeryActiveMinutes >= 15 then 'Good'
WHEN FairlyActiveMinutes >= 30 then 'Good'
ELSE 'bad'
END as ActiveDistanceLevel
 FROM `white-form-355300.Bellabeat.dailyActivity`
;

--getting to see the number of users categorized in day of week
WITH
-- Merging  two tables
  daily_activity_sleep  AS (
    SELECT
    TotalSteps,
    TotalMinutesAsleep,
    daily_activity_new.Id AS id,
    daily_activity_new.formattedDate AS date
  FROM `white-form-355300.Bellabeat.dailyActivity_new` AS daily_activity_new
  INNER JOIN 
    `white-form-355300.Bellabeat.sleepDay_merged_new` AS daily_sleep_new
  ON
  daily_activity_new.Id = daily_sleep_new.Id  AND
   daily_activity_new.formattedDate = daily_sleep_new.formattedDate
   )

--Find the average of Total steps and Total minute asleep per week
SELECT 
  day_of_week, 
  ROUND(AVG(TotalSteps),2) as ave_totalsteps_perday,
  ROUND(AVG(TotalMinutesAsleep),2) AS ave_minutesasleep_perday
FROM
  (
  SELECT *,
  FORMAT_DATE('%A', DATE(date)) AS day_of_week
  FROM daily_activity_sleep
  )

GROUP BY day_of_week
;

--daily usage 
  SELECT `usage` AS `usage`, `total_percentage` AS `total_percentage`, `labels` AS `labels`
  FROM (
WITH
  --Merging two tables with two primary key
  daily_activity_and_sleep AS (
    SELECT
    daily_activity.Id as Id,
    COUNT(*) as num_of_use
    FROM `white-form-355300.Bellabeat.dailyActivity_new` as daily_activity
    INNER JOIN `white-form-355300.Bellabeat.sleepDay_merged_new` as daily_sleep
    ON daily_activity.Id = daily_sleep.Id AND daily_activity.formattedDate = daily_sleep.formattedDate
    GROUP BY Id
  ),
  #Filtering user usage based on daily sleep and activity of a users
  usages AS (
    SELECT 
  Id, 
  SUM(num_of_use) AS day_used, 
  CASE 
    WHEN SUM(num_of_use) BETWEEN 1 AND 10 THEN 'low use'
    WHEN SUM(num_of_use) BETWEEN 11 AND 20 THEN 'moderate use'
    WHEN SUM(num_of_use) BETWEEN 21 AND 31 THEN 'high use'
  END AS usage
FROM daily_activity_and_sleep
GROUP BY Id
  ),
  -- Counting the number of usage
  usage_summary AS (
    SELECT 
      usage, 
      COUNT(*) AS total
    FROM usages
    GROUP BY usage
  ),
  -- Getting the average of number of usage and total usage
  usage_percentage AS (
    SELECT 
      usage, 
      total, 
      total_usage, 
      CAST(total AS FLOAT64) / total_usage AS total_percentage
   -- Selecting it FROM usage summary, and finding the total usage 
    FROM (
      SELECT 
        usage, 
        total, 
        SUM(total) OVER () AS total_usage
      FROM usage_summary
    ) 
  )
SELECT 
  usage, 
  total_percentage, 
  CONCAT(CAST(ROUND(total_percentage * 100, 1) AS INT64), '% (', CAST(total AS INT64), ')') AS labels
FROM usage_percentage
)
  LIMIT 500
;

--Creating new subquery for daily used

WITH minutes_worn AS (
   SELECT *,
   CASE 
    WHEN minutes_worn_percentage = 100 THEN 'All day'
    WHEN minutes_worn_percentage >= 50 AND minutes_worn_percentage < 100 THEN 'More than half day'
    WHEN minutes_worn_percentage > 0 AND minutes_worn_percentage < 50 THEN 'Less than half day'
   END as worn

  FROM (
     SELECT *, 
      (VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes +
SedentaryMinutes) as total_worn_minutes,
  (VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes +
SedentaryMinutes) / 1440 * 100 as minutes_worn_percentage
     FROM `white-form-355300.Bellabeat.dailyActivity_new`
   )

  )

SELECT *
FROM minutes_worn
