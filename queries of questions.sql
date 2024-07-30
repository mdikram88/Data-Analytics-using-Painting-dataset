-- 1) Fetch all the painting name, artist name which are not displayed on any museums?

SELECT w.name as "Painting", a.full_name as Artist
FROM work as w INNER JOIN artist as a
ON w.artist_id = a.artist_id
WHERE w.museum_id IS NULL;


-- 2) Are there museuems without any paintings?

SELECT *
FROM museum as m
WHERE m.museum_id NOT IN   (
							SELECT DISTINCT w.museum_id
							FROM work as w
							ORDER BY w.museum_id
							)

-- 3) How many paintings have an asking price of more, less than and equal to their regular price? 

SELECT
	COUNT(CASE WHEN sale_price > regular_price THEN 1 END) as "# painting with sale_price > regular_price",
	COUNT(CASE WHEN sale_price < regular_price THEN 1 END) as "# painting with sale_price < regular_price",
	COUNT(CASE WHEN sale_price = regular_price THEN 1 END) as "# painting with sale_price = regular_price",
	COUNT(*) as "Total Number of painting"
FROM product_size



-- 4) Identify the painting artist and museum name whose asking price is less than 50% of its regular price

SELECT w.name as Painting, a.full_name as Artist, m.name as Museum
FROM (
		SELECT DISTINCT work_id
		FROM product_size
		WHERE sale_price < 0.5*regular_price
	 ) as ps INNER JOIN work as w
ON ps.work_id = w.work_id INNER JOIN artist as a
ON a.artist_id = w.artist_id INNER JOIN museum as m
ON m.museum_id = w.museum_id


-- 5) Which canva size costs the 2nd most?

SELECT c.label as Label, ps.sale_price as "Sale Price"
FROM (
		SELECT *, rank() OVER (ORDER BY sale_price DESC)
		FROM product_size
	 ) as ps INNER JOIN canvas_size as c
ON ps.size_id = c.size_id
WHERE ps.rank = 2;
	 
	 
-- 6) Identify the museums with invalid city information in the given dataset
SELECT *
FROM museum
WHERE city ~ '^[^A-Za-z]+'


-- 7) Museum_Hours table has 1 invalid entry. Identify it and remove it.
DELETE FROM museum_hours 
WHERE ctid NOT IN (SELECT MIN(mh.ctid)
					FROM museum_hours as mh
					GROUP BY mh.museum_id, mh.day );
					

-- 8) Fetch the top 10 most famous painting subject

SELECT s.subject, COUNT(DISTINCT w.name) as "# painting" ,rank() OVER (ORDER BY COUNT(DISTINCT w.name) DESC) as ranking
FROM work as w INNER JOIN subject as s
ON s.work_id = w.work_id
GROUP BY s.subject
LIMIT 10;


-- 9) Identify the museums which are open on both Sunday and Monday. Display museum name, city.
-- Firstly replacing typo 'thusday' to 'thursday'

UPDATE museum_hours
SET day = 'Thursday'
WHERE day = 'Thusday';

SELECT m.name, m.city
FROM (
		SELECT DISTINCT (museum_id)
		FROM museum_hours
		WHERE LOWER(day) IN ('saturday', 'sunday')
	 ) as mh INNER JOIN museum as m
ON m.museum_id = mh.museum_id;

	

-- 10) How many museums are open every single day?

SELECT m.name as "Museum"
FROM (
		SELECT museum_id, COUNT(DISTINCT day::text) as days
		FROM museum_hours
		GROUP BY museum_id
		HAVING COUNT(DISTINCT day) = 7
	 ) as mh INNER JOIN museum as m
ON m.museum_id = mh.museum_id


-- 11) Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)


SELECT m.name as "Museum", m.city as "City", w.n_painting as "# of Paintings" 
FROM (
		SELECT museum_id, COUNT(DISTINCT name) as n_painting,rank() OVER (ORDER BY COUNT(DISTINCT name) DESC) as ranking
		FROM work
		WHERE museum_id IS NOT NULL
		GROUP by museum_id
	 ) as w INNER JOIN museum as m
ON m.museum_id = w.museum_id
	
WHERE w.ranking <=5
ORDER BY ranking;


-- 12) Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done presented in the musuem)

SELECT a.full_name as "Artist", a.nationality as "Nationality", w.n_painting as "# of Paintings" 
FROM (
		SELECT artist_id, COUNT(DISTINCT name) as n_painting, rank() OVER (ORDER BY COUNT(DISTINCT name) DESC) as ranking
		FROM work
		WHERE museum_id IS NOT NULL
		GROUP BY artist_id
	 ) as w INNER JOIN artist as a
ON w.artist_id =  a.artist_id
WHERE ranking <=5
ORDER BY ranking;


-- 13) Display the 3 most popular canva sizes
SELECT c.label as "Canvas Label", wps.ct as "# of Paintings"
FROM (
		SELECT size_id, rank() OVER (ORDER BY COUNT(DISTINCT ps.work_id) DESC) as ranking, COUNT(DISTINCT ps.work_id) as ct
		FROM work as w INNER JOIN product_size as ps
		ON w.work_id = ps.work_id
		GROUP BY size_id
	  ) wps INNER JOIN canvas_size as c
ON wps.size_id = c.size_id
WHERE wps.ranking <=3
ORDER BY ranking;


-- 14) Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?
	 
SELECT m.name as "Museum", m.state as "State", mh.open, mh.close, mh.day as "Day", mh.timediff as "Duration"
FROM	(
			SELECT *, to_timestamp(close, 'HH:MI AM') - to_timestamp(open, 'HH:MI AM') as timediff, rank() OVER (ORDER BY to_timestamp(close, 'HH:MI AM') - to_timestamp(open, 'HH:MI AM') DESC) as ranking
			FROM museum_hours
		) as mh INNER JOIN museum as m
ON mh.museum_id = m.museum_id
WHERE mh.ranking = 1
ORDER BY mh.ranking;


-- 15) Which museum has the most no of most popular painting style?
WITH subquery AS (SELECT museum_id, COUNT(DISTINCT name) as ct
				FROM work 
				WHERE museum_id IS NOT NULL AND style IN (
								SELECT style
								FROM work
								GROUP BY style
								ORDER BY COUNT(DISTINCT name) DESC
								LIMIT 1
								)
				GROUP BY museum_id
				ORDER BY COUNT(DISTINCT name) DESC
				LIMIT 1
)

SELECT m.name as "Museum", s.ct as "# of paintings"
FROM subquery as s INNER JOIN museum as m
ON s.museum_id = m.museum_id


-- 16) Identify the artists whose paintings are displayed in multiple countries
SELECT a.full_name as "Artist", a.style as "Style", a.nationality as "Nationality", wm.ct as "# Countries"
FROM (
		SELECT artist_id, COUNT(country) as ct
		FROM work as w INNER JOIN museum as m
		ON w.museum_id = m.museum_id
		GROUP BY artist_id, country
		HAVING COUNT(country) > 1
	 ) wm INNER JOIN artist as a
ON wm.artist_id = a.artist_id
ORDER BY wm.ct DESC;


-- 17) Display the country and the city with most no of museums. Output 2 seperate columns to mention the city and country. If there are multiple value, seperate them with comma.
WITH cte_country AS 
		(SELECT country, COUNT(1)
		, rank() OVER(ORDER BY COUNT(1) DESC) AS rnk
		FROM museum
		GROUP BY country),
	cte_city AS
		(SELECT city, COUNT(1)
		, rank() OVER(ORDER BY COUNT(1) DESC) AS rnk
		FROM museum
		GROUP BY city)
		
SELECT STRING_AGG(DISTINCT country.country,', '), STRING_AGG(city.city,', ')
FROM cte_country country
CROSS JOIN cte_city city
WHERE country.rnk = 1
AND city.rnk = 1;


-- 18) Identify the artist and the museum where the most expensive and least expensive painting is placed. Display the artist name, sale_price, painting name, museum name, museum city and canvas label

WITH cte AS 
	(SELECT * , rank() OVER(ORDER BY sale_price DESC) AS rnk , rank() OVER(ORDER BY sale_price ) AS rnk_asc
	FROM product_size )
	
SELECT a.full_name as "Artist", ct.sale_price, w.name as "Painting", m.name as "Museum", STRING_AGG(c.label, ', ') as "Canvas"
FROM (
		SELECT DISTINCT work_id, sale_price, size_id
		FROM cte
		WHERE rnk = 1 OR rnk_asc = 1	
	 ) as ct INNER JOIN work as w
ON w.work_id = ct.work_id INNER JOIN artist as a
ON w.artist_id = a.artist_id INNER JOIN museum as m 
ON w.museum_id = m.museum_id INNER JOIN canvas_size as c
ON ct.size_id = c.size_id
WHERE w.museum_id IS NOT NULL
GROUP BY a.full_name, ct.sale_price, w.name, m.name


-- 19) Which country has the 5th highest no of paintings?
SELECT wm.country, wm.ct as "# of paintings"
FROM (
		SELECT m.country, COUNT(DISTINCT w.name) as ct, dense_rank() OVER (ORDER BY COUNT(DISTINCT w.name) DESC) as ranking
		FROM work as w INNER JOIN museum as m
		ON w.museum_id = m.museum_id
		GROUP BY m.country
	 ) wm
WHERE wm.ranking = 5;


