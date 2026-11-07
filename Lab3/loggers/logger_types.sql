CREATE TABLE logger_types (
    lt_id integer,
    lt_name character varying(20)
);

ALTER TABLE logger_types
ADD PRIMARY KEY (lt_id);

/*
ALTER TABLE loggers
ADD FOREIGN KEY (lo_lt_id) REFERENCES logger_types(lt_id);
*/