(
	select distinct
		regexp_replace(i.value, '^.+#','') as ISBN
		, b.title
		, b.primaryCreatorName
	from econtent.overdrive_api_product_identifiers i
	left join econtent.overdrive_api_products b on i.productId = b.id
	left join econtent.overdrive_api_product_availability a on b.id = a.productId
	left join econtent.overdrive_api_product_formats f on b.id = f.productId
	where f.textId like 'audiobook%'
	-- we use b.deleted instead of a.copiesOwned 'cause we want to provide access and deleted indicates it ain't findable in Pika.
	-- Let them eat Hoopla if we don't point them to OverDrive, even if there's copies really to be had in OverDrive
	-- for the record on 2018 09 18 there are 485 titles that are deleted = 1 and copiesOwned > 0
	and b.deleted != 1
	and (
			i.type = 'ISBN'
		        -- ISBN regexp below stolen from https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch04s13.html . 2018 12 12 : Only catches 2 more than (^[0-9]{9}[0-9Xx]$|^97[89][0-9]{10}$)
			or regexp_replace(i.value, '^.+#','') regexp '^(?:ISBN(?:-1[03])?:? )?(?=[0-9Xx]{10}$|(?=(?:[0-9]+[- ]){3})[- 0-9Xx]{13}$|97[89][0-9]{10}$|(?=(?:[0-9]+[- ]){4})[- 0-9]{17}$)(?:97[89][- ]?)?[0-9]{1,5}[- ]?[0-9]+[- ]?[0-9]+[- ]?[0-9Xx]$'
	)
	order by ISBN
) UNION DISTINCT (
-- RETRIEVE otherFormatIdentifiers, see https://trello.com/c/UE5A8Xk5
-- CAVEAT: this code is for mariadb 10.2+, i.e., it will work on galacto (not catalog!) as of 2018 10 23
-- CAVEAT: indeces will only grab otherFormatIdentifiers up to the 4th [3]; see also https://stackoverflow.com/questions/39906435/convert-json-array-in-mysql-to-rows#42153230
	select distinct
		json_value(m.rawData, concat('$.otherFormatIdentifiers[', idx, '].value')) as ISBN
		, b.title
		, b.primaryCreatorName
	from econtent.overdrive_api_product_metadata m
	join (
		select 0 as idx union
		select 1 as idx union
		select 2 as idx union
		select 3
	) as indeces
	left join econtent.overdrive_api_products b on m.productId = b.id
	where b.deleted != 1
		and json_value(m.rawData, '$.mediaType') = 'Audiobook'
		and json_query(m.rawData, concat('$.otherFormatIdentifiers[', idx, ']')) is not null
		and json_value(m.rawData, concat('$.otherFormatIdentifiers[', idx, '].type')) = 'ISBN'
		and json_value(m.rawData, concat('$.otherFormatIdentifiers[', idx, '].value')) != 'n/a'
	order by ISBN
)
order by primaryCreatorName, title, ISBN
;
