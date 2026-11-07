
set termout on
rem host write sys$output "Konstrukcja relacji demonstracyjnych.  Prosze czekac"
host echo "Konstrukcja relacji demonstracyjnych.  Prosze czekac"
set feedback on
DROP TABLE ETATY cascade constraints;
CREATE TABLE ETATY
      ( NAZWA VARCHAR2(10) CONSTRAINT PK_ETAT PRIMARY KEY,
	PLACA_MIN NUMBER(6,2),
	PLACA_MAX NUMBER(6,2));


INSERT INTO ETATY VALUES ('PROFESOR'  ,800.00,1500.00);
INSERT INTO ETATY VALUES ('ADIUNKT'   ,510.00, 750.00);
INSERT INTO ETATY VALUES ('ASYSTENT'  ,300.00, 500.00);
INSERT INTO ETATY VALUES ('STAZYSTA'  ,150.00, 250.00);
INSERT INTO ETATY VALUES ('SEKRETARKA',270.00, 450.00);
INSERT INTO ETATY VALUES ('DYREKTOR' ,1280.00,2100.00);
 

COMMIT;
set termout on
set feedback on

