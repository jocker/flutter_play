-- TABLE SCHEMA columns
create table columns(
	id integer not null primary key,
	_sync_flags integer not null  default 0,
	column_name varchar(255) not null ,
	planogram_id integer not null ,
	product_id integer,
	location_id integer,
	display_name varchar(255),
	last_fill integer,
	capacity integer,
	max_capacity integer,
	last_visit timestamp,
	tray_id integer not null ,
	coil_notes varchar(255),
	set_price float,
	sts_coils text,
	active boolean
);

-- TABLE SCHEMA locations
create table locations(
	id integer not null primary key,
	_sync_flags integer not null  default 0,
	name varchar(255),
	address varchar(255),
	address_secondary varchar(255),
	city varchar(255),
	state varchar(255),
	postal_code varchar(255),
	type varchar(255),
	last_visit timestamp,
	planogram_id integer,
	flags integer,
	latitude float,
	longitude float,
	account varchar(255),
	route varchar(255),
	make varchar(255),
	model varchar(255),
	serial varchar(255),
	cardreader_serial varchar(255)
);


-- TABLE SCHEMA products
create table products(
	_sync_flags integer not null  default 0,
	id integer not null primary key,
	name varchar(255),
	cost_basis float,
	price_per_case float,
	case_size integer,
	source_category_name varchar(255),
	category_name varchar(255),
	roc float,
	inventory_unit_count integer,
	required_unit_count integer,
	archived boolean,
	wh_order integer
);




-- TABLE SCHEMA machine_column_sales
create table machine_column_sales(
	_sync_flags integer not null  default 0,
	id integer not null primary key,
	machine_column varchar(255),
	location_id integer,
	last_sale_cash_amount float,
	last_sale_unit_count float,
	units_sold_since integer,
	cash_amount_since float,
	last_sale_date timestamp
);


-- TABLE SCHEMA pack_requests
create table pack_requests(
    id integer not null primary key,
	_sync_flags integer not null  default 0,
	location_id integer,
	stock_request_id integer
);


-- TABLE SCHEMA notes
create table notes(
    id integer not null primary key,
	_sync_flags integer not null  default 0,
	id integer not null ,
	content text
);


-- TABLE SCHEMA order_delivery_requests
create table order_delivery_requests(
    id integer not null primary key,
	_sync_flags integer not null  default 0,
	source_category_name varchar(255),
	type integer,
	owner_id integer,
	flags integer
);



-- TABLE SCHEMA location_products
create table location_products(
    id integer not null primary key,
	_sync_flags integer not null  default 0,
	id integer not null ,
	product_id integer,
	location_id integer,
	unit_count integer
);






-- TABLE SCHEMA packs
create table packs(
	_sync_flags integer not null  default 0,
	id integer not null primary key,
	location_id integer,
	restock_id integer
);

-- TABLE SCHEMA pack_entries
create table pack_entries(
    id integer not null primary key,
	_sync_flags integer not null  default 0,

	product_id integer,
	location_id integer,
	column_id integer,
	pack_id integer,
	restock_id integer,
	unit_count integer
);

-- TABLE SCHEMA stock_requests
create table restocks(
    id integer not null primary key,
	_sync_flags integer not null  default 0,
	location_id integer
);


-- TABLE SCHEMA restock_entries
create table restock_entries(
    id integer not null primary key,
	_sync_flags integer not null  default 0,
	location_id integer,
	column_id integer,
	product_id integer,
	restock_id integer,
	unit_count integer
);

