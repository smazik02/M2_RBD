CREATE TABLE organizations (
    or_id integer,
    or_name character varying(20),
    or_type character varying(10)
);

CREATE TABLE loggers (
    lo_id integer,
    lo_description character varying(100),
    lo_or_id integer,
    lo_lt_id integer
);

CREATE TABLE measurements (
    me_id integer,
    me_time timestamp with time zone,
    me_temperature numeric,
    me_lo_id integer,
    me_or_id integer
);

ALTER TABLE organizations
ADD PRIMARY KEY (or_id);

ALTER TABLE loggers
ADD PRIMARY KEY (lo_or_id, lo_id);

ALTER TABLE measurements
ADD PRIMARY KEY (me_or_id, me_id);

ALTER TABLE loggers
ADD FOREIGN KEY (lo_or_id) REFERENCES organizations(or_id);

ALTER TABLE measurements
ADD FOREIGN KEY (me_or_id) REFERENCES organizations(or_id);

ALTER TABLE measurements
ADD FOREIGN KEY (me_or_id, me_lo_id) REFERENCES loggers(lo_or_id, lo_id);





