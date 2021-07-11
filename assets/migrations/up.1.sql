-- TABLE SCHEMA columns



create table if not exists columns(
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
create table if not exists  locations(
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
create table if not exists  products(
	id integer not null,
	name varchar(255),
	costbasis float,
	pricepercase float,
	casesize integer,
	source_category_name varchar(255),
	category_name varchar(255),
	roc float,
	inventory_unit_count integer,
	required_unit_count integer,
	archived boolean,
	wh_order integer,
    primary key(id)
);

-- TABLE SCHEMA location_products
create table if not exists  productlocation(
    id integer not null,
	product_id integer,
	location_id integer,
	unitcount integer,
    primary key(id)
);





-- TABLE SCHEMA machine_column_sales
create table if not exists  machine_column_sales(
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
create table if not exists  pack_requests(
    id integer not null,
	_sync_flags integer not null  default 0,
	location_id integer,
	stock_request_id integer,
    primary key(id)
);


-- TABLE SCHEMA notes
create table if not exists  notes(
    id integer not null,
	_sync_flags integer not null  default 0,
	content text,
    primary key(id)
);


-- TABLE SCHEMA order_delivery_requests
create table if not exists  order_delivery_requests(
    id integer not null,
	_sync_flags integer not null  default 0,
	source_category_name varchar(255),
	type integer,
	owner_id integer,
	flags integer,
    primary key(id)
);









-- TABLE SCHEMA packs
create table if not exists  packs(
	id integer not null,
	_sync_flags integer not null  default 0,
	location_id integer,
	restock_id integer,
    primary key(id)
);

-- TABLE SCHEMA pack_entries
create table if not exists  pack_entries(
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
create table if not exists  restocks(
    id integer not null,
	_sync_flags integer not null  default 0,
	location_id integer,
    primary key(id)
);


-- TABLE SCHEMA restock_entries
create table if not exists  restock_entries(
    id integer not null,
	_sync_flags integer not null  default 0,
	location_id integer,
	column_id integer,
	product_id integer,
	restock_id integer,
	unit_count integer,
    primary key(id)
);


create table if not exists  _schema_info(
	schema_name varchar(255) not null,
	local_revision_num integer not null default 0,
	id_counter integer not null default -1,
	primary key(schema_name)
);

create table if not exists  _sync_pending_remote_mutations(
    unique_id varchar(255) not null,
    schema_name varchar(255) not null,
    object_id integer not null,
    mutation_type tinyint not null,
    data text,
    error_messages text,
    status tinyint not null default 0,
    rev_num integer not null,
    unique(schema_name, object_id, rev_num)
);

create table if not exists  _sync_object_resolved_ids(
    schema_name varchar(255) not null,
    local_id integer not null,
    remote_id integer not null default 0,
    primary key(schema_name, local_id)
);

create table if not exists  _sync_object_snapshots(
    schema_name varchar(255) not null,
    record_id integer not null,
    rev_num integer not null,
    data text not null,
    primary key(schema_name, record_id)
);