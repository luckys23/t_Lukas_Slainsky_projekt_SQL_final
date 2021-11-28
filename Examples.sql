-- Vybrat vše z tabulky
SELECT 
	*
FROM t_lukas_slatinsky_projekt_sql_final tlspsf ;



-- Výběr počtu potvrzených případů na milion obyvatel v závislosti na počasí 
-- (průměrná denní teplota; nárazový vítr; počet hodin, kdy pršelo; vlhkost vzduchu)
-- tam, kde víme průměrnou teplotu
SELECT DISTINCT 
	`date` ,
	country ,
	conf_per_mil ,
	avg_temp ,
	max_gust ,
	hours_rain ,
	humidity 
FROM t_lukas_slatinsky_projekt_sql_final tlspsf
WHERE avg_temp IS NOT NULL ;



-- Výběr celkového počtu potvrzených případů na milion obyvatel a provedených testů na milion obyvatel
-- Pozn. U některých zemí nejsou k dispozici údaje o testování
WITH base AS (
	SELECT 
		country ,
		population 
	FROM t_lukas_slatinsky_projekt_sql_final tlspsf 
	GROUP BY population , country 
	ORDER BY country
), base_2 AS (
	SELECT DISTINCT 
		`date` ,
		country ,
		confirmed ,
		tests_performed 
	FROM t_lukas_slatinsky_projekt_sql_final tlspsf4 
), a AS (
	SELECT 
		country ,
		sum(confirmed) AS confirmed_total ,
		sum(tests_performed) AS tests_total
	FROM base_2
	GROUP BY country 
)
SELECT
	base.country , 
	round( ( a.confirmed_total / base.population ) * 1000000 , 2 ) AS conf_per_mil ,
	round( ( a.tests_total / base.population ) * 1000000 , 2 ) AS tests_per_mil
FROM base
LEFT JOIN a 
	   ON base.country = a.country


-- Celkový počet nakažených pro jednotlivé země v daném období
WITH 
	vyber AS (
		SELECT DISTINCT 
			`date` ,
			country ,
			confirmed 
		FROM t_lukas_slatinsky_projekt_sql_final tlspsf 
)
SELECT 
	country ,
	sum(confirmed)
FROM vyber 
GROUP BY country ;



-- Pořadí zemí dle poměru celkového počtu nakažených oproti populaci v dané zemi v daném časovém období
-- aneb kolik procent populace v daném státu se již nakazilo
WITH 
	vyber AS (
		SELECT DISTINCT 
			`date` ,
			country ,
			confirmed ,
			population 
		FROM t_lukas_slatinsky_projekt_sql_final tlspsf 
)
SELECT 
	ROW_NUMBER() OVER (ORDER BY affected_population_perc DESC) AS affected_rank ,
	country ,
	sum(confirmed) AS confirmed ,
	population ,
	round ( sum(confirmed) / population * 100 , 2 ) AS affected_population_perc 
FROM vyber 
GROUP BY country
ORDER BY affected_population_perc DESC ;



-- Výběr 10 zemí s nejvyšším celkovým počtem nakažených v daném období
WITH 
	vyber AS (
		SELECT DISTINCT 
			`date` ,
			country ,
			confirmed 
		FROM t_lukas_slatinsky_projekt_sql_final tlspsf 
)
SELECT 
	ROW_NUMBER() OVER (ORDER BY confirmed DESC) AS conf_rank ,
	country ,
	sum(confirmed) AS confirmed
FROM vyber 
GROUP BY country
ORDER BY confirmed DESC 
LIMIT 10 ;



-- Výběr vývoje počtu nakažených a provedených testů v České republice 
-- spolu s rozdílem nakažených a provedených testů oproti předchozímu dni
WITH base AS (
	SELECT DISTINCT 
		`date` ,
		country 
	FROM t_lukas_slatinsky_projekt_sql_final tlspsf 
	WHERE country LIKE 'cze%'
), a AS (
	SELECT DISTINCT 
		`date` ,
		confirmed ,
		tests_performed 
	FROM t_lukas_slatinsky_projekt_sql_final tlspsf2 
 	WHERE country LIKE 'cze%'
 	GROUP BY `date` 
), b AS (
	SELECT DISTINCT 
		`date` ,
		lag (confirmed) OVER (ORDER BY `date`) AS conf_diff ,
		lag (tests_performed) OVER (ORDER BY `date`) AS tests_diff
	FROM t_lukas_slatinsky_projekt_sql_final tlspsf3 
 	WHERE country LIKE 'cze%'
 	GROUP BY `date` 
)
SELECT
	base.`date` ,
	a.confirmed ,
	a.confirmed - b.conf_diff AS conf_diff ,
 	a.tests_performed ,
 	a.tests_performed - b.tests_diff AS tests_diff 
FROM base
LEFT JOIN a 
	   ON base.date = a.date
LEFT JOIN b
	   ON base.date = b.date

	   
	   
-- Celosvětový počet potvrzených případů vzhledem k celkové světové populaci, uvedeno i v procentech
WITH base AS (
	SELECT 
		country ,
		population 
	FROM t_lukas_slatinsky_projekt_sql_final tlspsf 
	GROUP BY population , country 
	ORDER BY country
), a AS (
	SELECT 
		sum(population) AS world_population ,
		RANK () OVER (ORDER BY world_population) AS id 
	FROM base
), base_2 AS (
	SELECT DISTINCT 
		`date` ,
		country ,
		confirmed 
	FROM t_lukas_slatinsky_projekt_sql_final tlspsf 
), b AS (
	SELECT 
		sum(confirmed) AS world_confirmed ,
		RANK () OVER (ORDER BY world_confirmed) AS id
	FROM base_2
)
SELECT 
	b.world_confirmed ,
	a.world_population ,
	round((b.world_confirmed / a.world_population) * 100 , 2) AS affected_perc 
FROM b
LEFT JOIN a 
	   ON a.id = b.id	   

	   
	   
-- Celkový počet nakažených v daném státě vzhledem k jeho populaci. Poměr vyjádřen i procentuálně.
WITH base AS (
	SELECT DISTINCT 
		`date` ,
		country ,
		confirmed ,
		population ,
		population_density 
	FROM t_lukas_slatinsky_projekt_sql_final tlspsf 
), a AS (
	SELECT 
		country ,
		sum(confirmed) AS confirmed 
	FROM base
	GROUP BY country 
), b AS (
	SELECT DISTINCT 
		country ,
		population ,
		population_density 
	FROM base	
)
SELECT
	a.country ,
	a.confirmed ,
	b.population ,
	(round((a.confirmed / b.population ), 2) * 100) AS affected_population_perc ,
	b.population_density 
FROM a
LEFT JOIN b
	   ON a.country = b.country
	   
	   
	   
-- Celkový počet nakažených na milion obyvatel v daném státě v daném časovém období vzhledem k jeho vyspělosti 
-- (GDP, median age, gini koeficient, dětská úmrtnost, očekávaná délka života v roce 2015, rozdíl očekávané délky života mezi lety 1965 a 2015)
WITH base AS (
	SELECT DISTINCT 
		`date` ,
		country ,
		confirmed ,
		population ,
		GDP_per_cap ,
		median_age_2018 ,
		gini ,
		last_gini ,
		mortality_under5 ,
		last_mortality_u5 ,
		life_expectancy_2015 ,
		life_expectancy_difference 		
	FROM t_lukas_slatinsky_projekt_sql_final tlspsf 
), a AS (
	SELECT 
		country ,
		sum(confirmed) AS confirmed 
	FROM base
	GROUP BY country 
), b AS (
	SELECT DISTINCT 
		country ,
		population ,
		GDP_per_cap ,
		median_age_2018 ,
		gini ,
		last_gini ,
		mortality_under5 ,
		last_mortality_u5 ,
		life_expectancy_2015 ,
		life_expectancy_difference 
	FROM base	
)
SELECT
	a.country ,
	round(((a.confirmed / b.population) * 1000000 ) , 2) AS conf_per_mil ,
	b.GDP_per_cap ,
	b.median_age_2018 ,
	b.gini ,
	b.last_gini ,
	b.mortality_under5 ,
	b.last_mortality_u5 ,
	b.life_expectancy_2015 ,
	b.life_expectancy_difference 
FROM a
LEFT JOIN b
	   ON a.country = b.country	   
	   

