CREATE TABLE t_Lukas_Slatinsky_projekt_SQL_final AS 
WITH 
-- základní tabulka covid19_basic_differences
	base AS (
		SELECT 
			`date` ,
			country ,
			confirmed ,
			-- binární promìnná pro víkend/všední den (1/0)
			CASE 
				WHEN WEEKDAY(`date`) IN (5, 6) THEN 1 
				ELSE 0 
			END AS 'weekend' ,
			-- roèní období daného dne (jaro = 0)
			CASE 
				WHEN `date` BETWEEN '2019-12-21' AND '2020-03-19' THEN 3
				WHEN `date` BETWEEN '2020-03-20' AND '2020-06-19' THEN 0
				WHEN `date` BETWEEN '2020-06-20' AND '2020-09-21' THEN 1
				WHEN `date` BETWEEN '2020-09-22' AND '2020-12-20' THEN 2
				WHEN `date` BETWEEN '2020-12-21' AND '2021-03-19' THEN 3
				WHEN `date` BETWEEN '2021-03-20' AND '2021-06-20' THEN 0
			END AS 'season' 
		FROM covid19_basic_differences 
), iso AS (
		SELECT 
			lt2.country AS country1 ,
			lt2.iso3 AS iso3 ,
			c2.country AS country2
		FROM lookup_table lt2
		LEFT JOIN countries c2 
		  ON lt2.iso3 = c2.iso3
		WHERE lt2.province IS NULL 
-- údaje o populaci obyvatel
), pop AS (
		SELECT 
			country ,
			iso3 ,
			population 
		FROM lookup_table
		WHERE province IS NULL 
-- poslední dostupný gini koeficient 
), a_gini AS (
	 SELECT
	 	country ,
	 	gini ,
	 	MAX(`year`) AS maxy
	 FROM economies
	 WHERE gini IS NOT NULL 
	 GROUP BY country 
-- poslední dostupná dìtská úmrtnost
), mort AS (
	SELECT 
		country ,
		mortaliy_under5 ,
		MAX(`year`) AS maxy
	FROM economies
	WHERE mortaliy_under5 IS NOT NULL 
	GROUP BY country
-- gdp na obyvatele v roce 2020 (data pro rok 2021 nejsou dostupná)
), gdpc AS (
	SELECT
		country ,
		ROUND( GDP / population , 2 ) AS GDP_per_cap 
	FROM economies
	WHERE `year` = 2020
-- rozdíl oèekávané doby dožití 1965 - 2015
), le_diff AS (
	SELECT 
		le.country ,
		le.iso3 ,
		le.life_expectancy AS life_expectancy_1965 ,
		le2.life_expectancy AS life_expectancy_2015 ,
		ROUND( le2.life_expectancy - le.life_expectancy , 2 ) AS life_expectancy_difference
	FROM (
	-- rok 1965
		SELECT 
			country ,
			iso3 ,
			life_expectancy ,
			`year` 
		FROM life_expectancy
		WHERE `year` = 1965
	) le
	LEFT JOIN (
	-- rok 2015
		SELECT 
			country ,
			life_expectancy ,
			`year` 
		FROM life_expectancy
		WHERE `year` = 2015
	) le2
	        ON le.country = le2.country
-- podíly jednotlivých náboženství
), rel_perc AS (
	SELECT
		rel.country ,
		rel.religion ,
		ROUND( rel.population / pop.population * 100 , 2 ) AS believer_percentage ,
		rel.population AS rel_pop ,
		pop.population AS total_pop
	FROM (
	-- výbìr státù a jejich náboženství s poètem vìøících v roce 2020 (rok 2021 v tabulce není)
		SELECT
			r.religion ,
			r.population ,
			iso.country1 AS country
		FROM religions r
		LEFT JOIN iso 
		  ON iso.country2 = country
		WHERE r.`year` = 2020
	) rel
	-- pøipojení dat o celkové populaci v daném státì
	LEFT JOIN (
		SELECT 
			country ,
			population
		FROM lookup_table lt 
		WHERE province IS NULL 
	) pop
	  ON rel.country = pop.country 
-- prùmìrná denní teplota
), avg_tmp AS (
	SELECT
	  `date` ,
	  city ,
	  ROUND(AVG(CAST(TRIM(REPLACE(temp, '°c', '')) AS FLOAT)) , 2) AS avg_temp
	FROM weather w 
-- Chybí údaje o pøesném èasu západu a východu slunce pro jednotlivé zemì a dny.
-- Pøesné èasy, které by urèovaly prùmìrný západ a východ slunce se mi nepodaøilo najít.
-- Tudíž jako rozmezí dne byl pro zjednodušení zvolen èas 6:00 - 18:00.
	WHERE `time` BETWEEN '06:00' AND '18:00'
	  AND city IS NOT NULL 
	GROUP BY `date` , city 
-- poèet hodin v daném dni, kdy byly srážky nenulové
), hrs_rain AS (
	SELECT 
		date ,
		city ,
		sum(hrsrain) AS hr_rain
	FROM (
		SELECT 
			`date` ,
			city ,
			`time` ,
			rain ,
			CASE WHEN rain = '0.0 mm' THEN 0
				 ELSE 3 END AS hrsrain
		FROM weather w 
		WHERE city IS NOT NULL 
	) trn 
	GROUP BY `date` , city 	
-- maximální síla vìtru v nárazech bìhem dne
), max_gst AS (
	SELECT 
		`date` ,
		city ,
		MAX(CAST(TRIM(REPLACE(gust , 'km/h', '')) AS FLOAT)) AS gust
	FROM weather w2 
	WHERE city IS NOT NULL 
	GROUP BY `date` , city
-- life_expectancy, mìsto, median_age pro rok 2018, pøedpokládaná délka dožití, hustota obyvatel
), countr AS (
	SELECT 
		country ,
	 	CASE 
		  	WHEN capital_city = 'Athenai' THEN 'Athens'
			WHEN capital_city = 'Bruxelles [Brussel]' THEN 'Brussels'
			WHEN capital_city = 'Bucuresti' THEN 'Bucharest'
			WHEN capital_city = 'Helsinki [Helsingfors]' THEN 'Helsinki'
			WHEN capital_city = 'Kyiv' THEN 'Kiev'
			WHEN capital_city = 'Lisboa' THEN 'Lisbon'
			WHEN capital_city = 'Luxembourg [Luxemburg/L' THEN 'Luxembourg'
			WHEN capital_city = 'Praha' THEN 'Prague'
			WHEN capital_city = 'Roma' THEN 'Rome'
			WHEN capital_city = 'Wien' THEN 'Vienna'
			WHEN capital_city = 'Warszawa' THEN 'Warsaw'
		ELSE capital_city END AS capital_city ,
		life_expectancy ,
		population_density ,
		median_age_2018 ,
		iso3 
	FROM countries
-- testování - poèet testù/den + typ testu
), tests AS (
	SELECT 
		`date` ,
		country ,
		entity ,
		tests_performed 
	FROM covid19_tests 
-- prùmìrná vlhkost vzduchu
), humid AS (
	SELECT 
		`date` ,
		city ,
		AVG(CAST(TRIM(REPLACE(humidity , '%', '')) AS int)) AS humidity 
	FROM weather
	WHERE city IS NOT NULL 
	GROUP BY `date` , city 
)
-- výsledný select
SELECT 
	base.`date` ,
	base.country ,
	base.confirmed ,
	ROUND( base.confirmed / pop.population * 1000000 , 2 ) AS conf_per_mil , 
	tests.entity ,
	tests.tests_performed ,
	ROUND( tests.tests_performed / pop.population * 1000000 , 2 ) AS test_per_mil ,
	pop.population ,
	c.population_density ,
	c.median_age_2018 ,
	gdpc.GDP_per_cap ,
	a_gini.gini ,
	a_gini.maxy AS last_gini ,
	mort.mortaliy_under5 AS mortality_under5 ,
	mort.maxy AS last_mortality_u5 ,
	le_diff.life_expectancy_1965 ,
	le_diff.life_expectancy_2015 ,
	le_diff.life_expectancy_difference ,
 	rel_perc.religion ,
 	rel_perc.believer_percentage ,
	avg_tmp.avg_temp , 					-- v °C
	max_gst.gust AS max_gust , 			-- v km/h
	hrs_rain.hr_rain AS hours_rain ,
	humid.humidity						-- v %
FROM base
LEFT JOIN iso
  ON iso.country1 = base.country
-- pøipojení údajù o testování 
LEFT JOIN tests 
  ON tests.country = iso.country1 
 AND tests.`date`  = base.`date` 
-- pøipojení údajù o poètu obyvatel
LEFT JOIN pop
  ON pop.country = iso.country1 
-- pøipojení tabulky countries
LEFT JOIN countr c
   ON c.iso3 = iso.iso3
-- pøipojení údajù o GDP
LEFT JOIN gdpc
  ON gdpc.country = iso.country2
-- pøipojení údajù o gini
LEFT JOIN a_gini
  ON a_gini.country = iso.country2
-- pøipojení údajù o dìtské úmrtnosti
LEFT JOIN mort
  ON mort.country = iso.country2
-- pøipojení údajù o life expectancy v roce 1965 a 2015
LEFT JOIN le_diff
  ON le_diff.iso3 = iso.iso3 
-- pøipojení údajù o procentuálním poètu vìøících
LEFT JOIN rel_perc
  ON rel_perc.country = iso.country1
-- pøipojení údajù o prùmìrné denní teplotì
LEFT JOIN avg_tmp
  ON avg_tmp.`date` = base.`date`
 AND avg_tmp.city = capital_city 
-- pøipojení údajù o maximální rychlosti nárazového vìtru
LEFT JOIN max_gst
  ON max_gst.`date` = base.`date`
 AND max_gst.city = capital_city 
-- pøipojení údajù o dobì, kdy byly srážky nenulové
LEFT JOIN hrs_rain
  ON hrs_rain.`date` = base.`date`
 AND hrs_rain.city = capital_city 
-- pøipojení údajù o prùmìrné vlhkosti vzduchu
LEFT JOIN humid
  ON humid.`date` = base.`date`
 AND humid.city = capital_city 
ORDER BY base.`date` , base.country ASC ;
