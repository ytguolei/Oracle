CREATE OR REPLACE FUNCTION WM_CONCAT(P1 varchar2)
RETURN varchar2 AGGREGATE USING SGM_WM_CONCAT_TYPE ;
/