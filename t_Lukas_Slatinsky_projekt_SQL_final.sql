CREATE TABLE t_Lukas_Slatinsky_projekt_SQL_final AS 
WITH 
-- základní tabulka covid19_basic_differences
	base AS (
		SELECT 
			`date` ,
			country ,
			confirmed ,
			-- binární proměnná pro víkend/všední den (1/0)
			CASE 
				WHEN WEEKDAY(`date`) IN (5, 6) THEN 1 
				ELSE 0 
			END AS weekend ,
			-- roční období daného dne (jaro = 0)
			CASE 
				WHEN MONTH(`date`) BETWEEN 1 AND 3 THEN 0
				WHEN MONTH(`date`) BETWEEN 4 AND 6 THEN 1
				WHEN MONTH(`date`) BETWEEN 7 AND 9 THEN 2
				WHEN MONTH(`date`) BETWEEN 10 AND 12 THEN 3
			END AS season 
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
-- poslední dostupná dětská úmrtnost
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
-- rozdíl očekávané doby dožití 1965 - 2015
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
	-- výběr států a jejich náboženství s počtem věřících v roce 2020 (rok 2021 v tabulce není)
		SELECT
			r.religion ,
			r.population ,
			iso.country1 AS country
		FROM religions r
		LEFT JOIN iso 
		  ON iso.country2 = country
		WHERE r.`year` = 2020
	) rel
	-- připojení dat o celkové populaci v daném státě
	LEFT JOIN (
		SELECT 
			country ,
			population
		FROM lookup_table lt 
		WHERE province IS NULL 
	) pop
	  ON rel.country = pop.country 
-- průměrná denní teplota
), avg_tmp AS (
	SELECT
	  `date` ,
	  city ,
	  ROUND(AVG(CAST(TRIM(REPLACE(temp, ' °c', '')) AS FLOAT)) , 2) AS avg_temp
	FROM weather w 
-- Chybí údaje o přesném času západu a východu slunce pro jednotlivé země a dny.
-- Přesné časy, které by určovaly průměrný západ a východ slunce se mi nepodařilo najít.
-- Tudíž jako rozmezí dne byl pro zjednodušení zvolen čas 6:00 - 18:00.
	WHERE `time` BETWEEN '06:00' AND '18:00'
	  AND city IS NOT NULL 
	GROUP BY `date` , city 
-- počet hodin v daném dni, kdy byly srážky nenulové
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
-- maximální síla větru v nárazech během dne
), max_gst AS (
	SELECT 
		`date` ,
		city ,
		MAX(CAST(TRIM(REPLACE(gust , 'km/h', '')) AS FLOAT)) AS gust
	FROM weather w2 
	WHERE city IS NOT NULL 
	GROUP BY `date` , city
-- life_expectancy, město, median_age pro rok 2018, předpokládaná délka dožití, hustota obyvatel
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
-- testování - počet testů/den + typ testu
), tests AS (
	SELECT 
		`date` ,
		country ,
		entity ,
		tests_performed 
	FROM covid19_tests 
-- průměrná vlhkost vzduchu
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
-- připojení údajů o testování 
LEFT JOIN tests 
  ON tests.country = iso.country1 
 AND tests.`date`  = base.`date` 
-- připojení údajů o počtu obyvatel
LEFT JOIN pop
  ON pop.country = iso.country1 
-- připojení tabulky countries
LEFT JOIN countr c
   ON c.iso3 = iso.iso3
-- připojení údajů o GDP
LEFT JOIN gdpc
  ON gdpc.country = iso.country2
-- připojení údajů o gini
LEFT JOIN a_gini
  ON a_gini.country = iso.country2
-- připojení údajů o dětské úmrtnosti
LEFT JOIN mort
  ON mort.country = iso.country2
-- připojení údajů o life expectancy v roce 1965 a 2015
LEFT JOIN le_diff
  ON le_diff.iso3 = iso.iso3 
-- připojení údajů o procentuálním počtu věřících
LEFT JOIN rel_perc
  ON rel_perc.country = iso.country1
-- připojení údajů o průměrné denní teplotě
LEFT JOIN avg_tmp
  ON avg_tmp.`date` = base.`date`
 AND avg_tmp.city = capital_city 
-- připojení údajů o maximální rychlosti nárazového větru
LEFT JOIN max_gst
  ON max_gst.`date` = base.`date`
 AND max_gst.city = capital_city 
-- připojení údajů o době, kdy byly srážky nenulové
LEFT JOIN hrs_rain
  ON hrs_rain.`date` = base.`date`
 AND hrs_rain.city = capital_city 
-- připojení údajů o průměrné vlhkosti vzduchu
LEFT JOIN humid
  ON humid.`date` = base.`date`
 AND humid.city = capital_city 
ORDER BY base.`date` , base.country ASC ;
