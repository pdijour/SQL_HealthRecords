/* 

Database Querying in Health Final Project 

Server Name: esmpmdbpr4
 DB Name: CAMP_DM_Projection

 Complex Query Checklist - Inspect each step
	.	Visualize the question. Use the ERD 
	.	Identify the minimal fields and tables needed for query
	.	Identify filters
	.	Determine joining key
			Do counts on both tables before join and after join
	.	Determine what is the level of aggregation for the question. 
			Is this per patient 
			per patient-encounter
			patient-encounter-measurement
	.	Add calculations, groupers on fields

Inspect each step

Inspect the data using Select top 10 of * from the join of these tables
	Inspect counts at each step
Try to make it easy to read
	Use comments
	
Use indentations
	Use capitalization
	Use aliases

Name: Phoebe Dijour
JHED: pdijour1
*/
 
/* 1. How many patients have Type I or Type II diabetes 
  Hint: Use ICD10 Code
*/

--Exploration of symptoms table
--SELECT TOP 10 *
--FROM symptoms AS s

SELECT COUNT(DISTINCT osler_id)
FROM symptoms AS s
WHERE diagnosis_code_icd10 LIKE 'E11%' --Type 2 Diabetes
	OR diagnosis_code_icd10 LIKE 'E10%'; --Type 1 Diabetes
--Answer: 56101

/* 2. How many patients have an A1C > 6.5 and have Type II ICD10 */

--Exploration of labs table for A1C results
--SELECT TOP 10 *
--FROM labs AS l
--WHERE lab_name LIKE '%A1C%'

-- Sub-select approach
SELECT COUNT(DISTINCT osler_id)
FROM labs AS l
WHERE lab_name LIKE '%A1C%'
	AND result > 6.5
	AND osler_id IN --Sub-select for Type II ICD10 code
		(SELECT s.osler_id
		FROM symptoms AS s
		WHERE diagnosis_code_icd10 LIKE 'E11%'); --Type II ICD10
--Answer: 19267

-- Join approach
SELECT COUNT(DISTINCT l.osler_id)
FROM labs AS l
INNER JOIN symptoms AS s --Join symptoms table
ON l.osler_id = s.osler_id
WHERE lab_name LIKE '%A1C%'
	AND result > 6.5
	AND diagnosis_code_icd10 LIKE 'E11%'; --Type II ICD10
--Answer: 19267

/* 
3. How many Type 1 diabetics have an Rx for insulin? 
Hint: Use ICD10 Code and Pharmacutical Class
*/

--Exploration of meds table for insulin
--SELECT TOP 10 *
--FROM meds
--WHERE pharmaceutical_class LIKE '%insulins%'


--Sub-select approach
SELECT COUNT(DISTINCT osler_id)
FROM meds AS m
WHERE pharmaceutical_class LIKE '%insulins%' --Patients who have Rx for insulin
	AND osler_id IN
		(SELECT s.osler_id
		FROM symptoms AS s
		WHERE diagnosis_code_icd10 LIKE 'E10%'); --Type I ICD10 diabetes
--Answer: 335

--Join approach
SELECT COUNT(DISTINCT m.osler_id)
FROM meds AS m
INNER JOIN symptoms AS s ON m.osler_id = s.osler_id
WHERE pharmaceutical_class LIKE '%insulins%' --Patients who have Rx for insulin
	AND diagnosis_code_icd10 LIKE 'E10%'; --Type I ICD10 diabetes
--Answer: 335

	
/* 
4. How many patients with Type 2 Diabetes are taking metformin? 
Hint: Use ICD10 Code and Medication names of
*/

--Exploration of meds table for metformin
--SELECT TOP 10 *
--FROM meds
--WHERE medication_name LIKE '%metformin%'

--Sub-select approach
SELECT COUNT(DISTINCT osler_id)
FROM meds AS m
WHERE medication_name LIKE '%metformin%' --Patients who have Rx for metformin
	AND osler_id IN
		(SELECT s.osler_id
		FROM symptoms AS s
		WHERE diagnosis_code_icd10 LIKE 'E11%'); --Type II ICD10
--Answer: 9750

--Join approach
SELECT COUNT(DISTINCT m.osler_id)
FROM meds AS m
INNER JOIN symptoms AS s ON m.osler_id = s.osler_id
WHERE medication_name LIKE '%metformin%'
	AND diagnosis_code_icd10 LIKE 'E11%';
--Answer: 9750

/* 
5. How many patients with high blood pressure (one reading over 140 systolic or 90 diastolic) have a hypertension dx (I10)? 
Hint: Use symptoms table and diagnosis Code, watch Clinical Correlation 2 video for more insights
Hypertension is I10
*/

--Join on osler_id
SELECT COUNT(DISTINCT s.osler_id)
FROM symptoms AS s
INNER JOIN vitals_bp
ON s.enc_num = vitals_bp.enc_num
WHERE
	(PARSENAME(REPLACE(bp_systolic_diastolic,'/','.'),2) > 140 --Get the second number, which is systolic
	OR
	PARSENAME(REPLACE(bp_systolic_diastolic,'/','.'),1) > 90) --Get the first number, which is diastolic
	AND
	diagnosis_code_icd10 = 'I10'; --Hypertension dx
--Answer: 21154

--Join on enc_num
SELECT COUNT(DISTINCT s.osler_id)
FROM symptoms AS s
INNER JOIN vitals_bp
ON s.osler_id = vitals_bp.osler_id
WHERE
	(PARSENAME(REPLACE(bp_systolic_diastolic,'/','.'),2) > 140 --Get the second number, which is systolic
	OR
	PARSENAME(REPLACE(bp_systolic_diastolic,'/','.'),1) > 90) --Get the first number, which is diastolic
	AND
	diagnosis_code_icd10 = 'I10'; --Hypertension dx
--Answer: 17742

/* 
6. List top 5 medications by number of patients for patients with hypertension? 
   Sort results with highest to lowest patient counts.
Hint: Use symptoms and meds tables; watch Clinical Correlation 2 video for more insights
*/

SELECT TOP 5 medication_name, COUNT(DISTINCT m.osler_id) AS 'Number of Patients'
FROM meds AS m
INNER JOIN symptoms AS s
ON m.enc_num = s.enc_num
WHERE diagnosis_code_icd10 = 'I10' --Hypertension Dx
GROUP BY medication_name --Group medications together
ORDER BY COUNT(DISTINCT m.osler_id) DESC; --Top 5 most-used medications
--Answer: Metformin 500 MG (2470), Metformin 1,000 MG (2250), Atorvastatin 40 MG (2187), Amlodipine 10 MG (1986), Amlodipine 5 MG (1968)


/*
7.	How many patients are compliant/non-compliant with their Glycemic Targets? 
Hint: A1C < 7.2 is Compliant and A1C > 7.2 = Non-Compliant; A1C measured at least twice?
*/

SELECT
	CASE --Basekts for compliant/non-compliant patients with Glycemic Targets
		WHEN result > 7.2 THEN 'non-compliant'
		WHEN result <= 7.2 THEN 'compliant'
	END AS compliance,
	COUNT(DISTINCT osler_id) AS 'Number of Patients'
FROM labs AS l
WHERE lab_name LIKE '%A1C%' 
	AND result IS NOT NULL 
	AND osler_id IN
		(SELECT osler_id
		FROM labs as l
		WHERE lab_name LIKE '%A1C%' AND result IS NOT NULL
		GROUP BY osler_id
		HAVING COUNT(DISTINCT enc_num) > 1) --A1C measured at least twice
GROUP BY
	CASE
		WHEN result > 7.2 THEN 'non-compliant'
		WHEN result <= 7.2 THEN 'compliant'
	END;
--compliant: 18072, non-compliant: 14296

/* 
8. How many patients went from normal to to diabetic via A1C 
Hint: A1C of 7.2 or lower is considered normal 
*/
 
WITH cte_mindate AS( --CTE to get first A1C result date where patient was normal 
	SELECT DISTINCT osler_id, MIN(result_date) AS min_date
	FROM labs
	WHERE lab_name LIKE '%A1C%' AND result IS NOT NULL AND result <= 7.2
	GROUP BY osler_id, result),
	cte_maxdate AS( --CTE to get last A1C result date where patient was diabetic 
		SELECT DISTINCT osler_id, MAX(result_date) AS max_date
		FROM labs
		WHERE lab_name LIKE '%A1C%' AND result IS NOT NULL AND result > 7.2
		GROUP BY osler_id, result)

SELECT COUNT(DISTINCT m1.osler_id)
FROM cte_mindate AS m1
INNER JOIN cte_maxdate AS m2 ON m1.osler_id = m2.osler_id
WHERE max_date > min_date; --Ensure that last date is after first date
--Answer: 5,022

/*
9. What percentage of patients are at risk of Type 2 Diabetes without being diagnosed?
Hint: Use CTE's to calculate Median Height and Weight
Hint: At Risk for Diabetes should be considered as 1) pre-diabetes or 2) BMI ≥ 30 (Obesity Classification)
*/
--Create CTE tables to calculate median heights and weights and then BMI from these numbers
WITH cte_hgt1 AS( --Table with each row_num for hgt
	SELECT osler_id, 
		height, 
		ROW_NUMBER() OVER (PARTITION BY osler_id ORDER BY height) AS row_num
	FROM vitals_height),
	cte_hgt2 AS( --Table with middle row_num for hgt
		SELECT osler_id,
			(MAX(row_num)+1)/2 AS row_id
		FROM cte_hgt1
		GROUP BY osler_id),
	cte_hgt AS( --Join hgt tables 1 and 2 together to pull out value of middle row_num
		SELECT c1.osler_id, c1.height
		FROM cte_hgt2 c2
		INNER JOIN cte_hgt1 c1
		ON c1.osler_id = c2.osler_id
		WHERE c1.row_num = c2.row_id AND c1.height IS NOT NULL),
	cte_wgt1 AS( --Table with each row_num for wgt
		SELECT osler_id, 
			weight, 
			ROW_NUMBER() OVER (PARTITION BY osler_id ORDER BY weight) AS row_num
		FROM vitals_weight),
	cte_wgt2 AS( --Table with middle row_num for wgt
		SELECT osler_id,
			(MAX(row_num)+1)/2 AS row_id
		FROM cte_wgt1
		GROUP BY osler_id),
	cte_wgt AS( --Join wgt tables 1 and 2 together to pull out value of middle row_num
		SELECT c1.osler_id, c1.weight
		FROM cte_wgt2 c2
		INNER JOIN cte_wgt1 c1
		ON c1.osler_id = c2.osler_id
		WHERE c1.row_num = c2.row_id AND c1.weight IS NOT NULL),
	cte_bmi AS( --Calculate BMI
		SELECT w.osler_id, w.weight, h.height, (w.weight)/POWER(h.height/39.37, 2) AS bmi --Units of bmi = kg/m^2
		FROM cte_hgt h
		INNER JOIN cte_wgt w
		ON h.osler_id = w.osler_id)

--Query to find the number of pre-diabetic patients
SELECT COUNT(DISTINCT l.osler_id) AS 'Number of Patients'
	,100.0*COUNT(DISTINCT l.osler_id)/
		(SELECT COUNT(DISTINCT osler_id)
		FROM symptoms as s) AS 'Percentage' --Divide percentage count of pre-diabetic patients by total patients for percentage
FROM labs as l
LEFT JOIN cte_bmi
ON cte_bmi.osler_id = l.osler_id
WHERE bmi >= 30
	AND result BETWEEN 5.7 AND 6.4 --A1C between 5.7 and 6.4 is considered pre-diabetic
	AND lab_name LIKE '%A1C%';
--Answer: 7482 (10.54%)


/*
10. Fill in the following:
So ___ Workers ___ Home ___ time
*/
-- So Few Workers Go Home On Time!