-- TABLE SCHEMA columns
create table columns(
	id integer not null,
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
	active boolean,
    primary key(id)
);

-- TABLE SCHEMA locations
create table locations(
	id integer not null,
	_sync_flags integer not null  default 0,
	location_name varchar(255),
	location_address varchar(255),
	location_address2 varchar(255),
	location_city varchar(255),
	location_state varchar(255),
	location_zip varchar(255),
	location_type varchar(255),
	last_visit timestamp,
	planogram_id integer,
	flags integer,
	lat float,
	long float,
	account varchar(255),
	route varchar(255),
	location_make varchar(255),
	location_model varchar(255),
	machine_serial varchar(255),
	cardreader_serial varchar(255),
    primary key(id)
);


-- TABLE SCHEMA products
create table products(
	id integer not null,
	_sync_flags integer not null  default 0,
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
	wh_order integer,
    primary key(id)
);




-- TABLE SCHEMA machine_column_sales
create table machine_column_sales(
	id integer not null,
	_sync_flags integer not null  default 0,
	machine_column varchar(255),
	location_id integer,
	last_sale_cash_amount float,
	last_sale_unit_count float,
	units_sold_since integer,
	cash_amount_since float,
	last_sale_date timestamp,
    primary key(id)
);


-- TABLE SCHEMA pack_requests
create table pack_requests(
    id integer not null,
	_sync_flags integer not null  default 0,
	location_id integer,
	stock_request_id integer,
    primary key(id)
);


-- TABLE SCHEMA notes
create table notes(
    id integer not null,
	_sync_flags integer not null  default 0,
	content text,
    primary key(id)
);


-- TABLE SCHEMA order_delivery_requests
create table order_delivery_requests(
    id integer not null,
	_sync_flags integer not null  default 0,
	source_category_name varchar(255),
	type integer,
	owner_id integer,
	flags integer,
    primary key(id)
);



-- TABLE SCHEMA location_products
create table location_products(
    id integer not null,
	_sync_flags integer not null  default 0,
	product_id integer,
	location_id integer,
	unit_count integer,
    primary key(id)
);






-- TABLE SCHEMA packs
create table packs(
	id integer not null,
	_sync_flags integer not null  default 0,
	location_id integer,
	restock_id integer,
    primary key(id)
);

-- TABLE SCHEMA pack_entries
create table pack_entries(
    id integer not null,
	_sync_flags integer not null  default 0,

	product_id integer,
	location_id integer,
	column_id integer,
	pack_id integer,
	restock_id integer,
	unit_count integer,
    primary key(id)
);

-- TABLE SCHEMA stock_requests
create table restocks(
    id integer not null,
	_sync_flags integer not null  default 0,
	location_id integer,
    primary key(id)
);


-- TABLE SCHEMA restock_entries
create table restock_entries(
    id integer not null,
	_sync_flags integer not null  default 0,
	location_id integer,
	column_id integer,
	product_id integer,
	restock_id integer,
	unit_count integer,
    primary key(id)
);


create table _schema_info(
	schema_name varchar(255) not null,
	local_revision_num integer not null default 0,
	id_counter integer not null default -1,
	primary key(schema_name)
);

create table _schema_changelog(
    schema_name varchar(255) not null,
    record_id integer not null,
    checksum varchar(255) not null,
    operation tinyint not null,
    created_at timestamp not null default current_timestamp,
    data text,
    unique(checksum)
);

create table _schema_row_id(
    schema_name varchar(255) not null,
    local_id integer not null,
    remote_id integer not null default 0,
    primary key(schema_name, local_id)
);