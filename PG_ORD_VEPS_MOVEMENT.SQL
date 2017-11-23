CREATE OR REPLACE PACKAGE PG_ORD_VEPS_MOVEMENT AS

  /******************************************************/
  /* Created : 2017-11-17 16:11:04                       */
  /* Description: VEPS����λ�ƽ���                    */
  /******************************************************/
  PROCEDURE VIECHLE_MOVEMENT(I_USER   IN NUMBER,
                             O_STATUS OUT VARCHAR2,
                             O_RESULT OUT VARCHAR2);

  /******************************************************/
  /* Created : 2017-10-30 16:11:04                       */
  /* Description: VEPS����λ�ƽ���                    */
  /******************************************************/
  PROCEDURE VIECHLE_MOVEMENT_OLD(I_USER   IN NUMBER,
                                 O_STATUS OUT VARCHAR2,
                                 O_RESULT OUT VARCHAR2);

END PG_ORD_VEPS_MOVEMENT;
/
CREATE OR REPLACE PACKAGE BODY PG_ORD_VEPS_MOVEMENT AS

  PROCEDURE VIECHLE_MOVEMENT(I_USER   IN NUMBER,
                             O_STATUS OUT VARCHAR2,
                             O_RESULT OUT VARCHAR2) AS
  
    V_SQLERRM VARCHAR2(1000); --������Ϣ
    --V_MONITOR_PARAMS        VARCHAR2(1000); -- ����ʱ�Ĳ�������
    --V_MONITOR_WORKSHOP_CODE TM_MDS_WORKSHOP.WORKSHOP_CODE%TYPE;
    V_MONITOR_REGION_ID   TM_MDS_REGION.REGION_ID%TYPE;
    V_MONITOR_REGION_CODE TM_MDS_REGION.REGION_CODE%TYPE;
    --V_MONITOR_PVI           TT_ORD_VEPS_MOVEMENT.PVI%TYPE;
    V_MONITOR_CSN        TT_ORD_VEPS_MOVEMENT.CSN%TYPE;
    V_CAR_QUEUE          TI_ORD_QAS_INTERFACE.CAR_QUEUE%TYPE;
    V_REGION_ID          TM_MDS_REGION.REGION_ID%TYPE;
    V_REGION_ORDER       TM_MDS_REGION.REGION_ORDER%TYPE;
    V_WORKSHOP_ID        TM_MDS_REGION.WORKSHOP_ID%TYPE;
    V_GROUP_NO           TM_MDS_REGION.GROUP_NO%TYPE;
    V_MAX_CSN            TT_ORD_VEPS_MOVEMENT.CSN%TYPE;
    V_MIN_CSN            TT_ORD_VEPS_MOVEMENT.CSN%TYPE;
    V_SETOUT_FLAG        TM_MDS_REGION.SETOUT_FLAG%TYPE;
    V_SETOUT             VARCHAR2(10);
    V_COUNT              NUMBER;
    V_ISNULL_MINCSN_FLAG VARCHAR2(10);
    V_ISNULL_MAXCSN_FLAG VARCHAR2(10);
    /*V_ISNULL_FIRST_FLAG  VARCHAR2(10);
    V_ISNULL_LAST_FLAG   VARCHAR2(10);*/
  
    TYPE T_CAR_QUEUE IS TABLE OF VARCHAR2(4000); --���������
    VT_CAR_QUEUE T_CAR_QUEUE;
  
    TYPE T_CAR_INFO IS TABLE OF VARCHAR2(4000); --���������
    VT_CAR_INFO T_CAR_INFO;
  
    TYPE T_CAR_MOVEMENT IS TABLE OF VARCHAR2(4000); --���������
    VT_CAR_MOVEMENT T_CAR_MOVEMENT;
  
    C_MONITOR_TYPE_MOVEMENT CONSTANT VARCHAR2(20) := '550016'; -- ���ɳ���λ�ƽ���ʧ�ܱ�������
  
    CURSOR CSR_REGION_VEPS IS(
    /*
                          SELECT R.REGION_ID, R.REGION_SIZE, COUNT(VM.REGION_ID)
                            FROM TM_MDS_REGION R
                            LEFT JOIN TT_ORD_VEPS_MOVEMENT VM
                           WHERE R.REGION_TYPE = 'VEPS'
                             AND R.REGION_STATUS = '1'
                             AND R.REGION_ID = VM.REGION_ID
                             AND VM.QAS_LOCATION_ORDER > 0
                             AND NOT EXISTS (SELECT 1
                                    FROM TT_ORD_VEPS_MOVEMENT VM
                                   WHERE R.REGION_ID = VM.REGION_ID
                                     AND VM.QAS_LOCATION_ORDER <> 0))
                          */
      SELECT R.REGION_ID, R.REGION_SIZE, COUNT(VM.REGION_ID) AS VM_COUNT
        FROM TM_MDS_REGION R
        LEFT JOIN TT_ORD_VEPS_MOVEMENT VM
          ON R.REGION_ID = VM.REGION_ID
         AND VM.QAS_LOCATION_ORDER > 0
       WHERE R.REGION_TYPE = 'VEPS'
         AND R.REGION_STATUS = '1'
       GROUP BY R.REGION_ID, R.REGION_SIZE);
  
    TYPE TYPE_ORD_QAS IS RECORD(
      V_QAS_INTERFACE_ID TI_ORD_QAS_INTERFACE.QAS_INTERFACE_ID%TYPE,
      V_PLANT_CODE       TI_ORD_QAS_INTERFACE.PLANT_CODE%TYPE,
      V_WORKSHOP_CODE    TI_ORD_QAS_INTERFACE.WORKSHOP_CODE%TYPE,
      V_CAR_QUEUE        TI_ORD_QAS_INTERFACE.CAR_QUEUE%TYPE);
  
    TYPE TAB_TYPE_ORD_QAS IS TABLE OF TYPE_ORD_QAS;
    V_TAB_TYPE_ORD_QAS TAB_TYPE_ORD_QAS;
  
    TYPE TYPE_CSN_REGION IS RECORD(
      V_REGION_ID    TT_ORD_VEPS_MOVEMENT.REGION_ID%TYPE,
      V_REGION_ORDER TM_MDS_REGION.REGION_ORDER%TYPE,
      V_GROUP_NO     TM_MDS_REGION.GROUP_NO%TYPE,
      V_MIN_CSN      TT_ORD_VEPS_MOVEMENT.CSN%TYPE,
      V_MAX_CSN      TT_ORD_VEPS_MOVEMENT.CSN%TYPE);
  
    TYPE TAB_TYPE_CSN_REGION IS TABLE OF TYPE_CSN_REGION;
    V_TAB_TYPE_CSN_REGION TAB_TYPE_CSN_REGION;
  
    TYPE TYPE_GROUP_NO IS RECORD(
      V_GROUP_NO TM_MDS_REGION.GROUP_NO%TYPE);
  
    TYPE TAB_TYPE_GROUP_NO IS TABLE OF TYPE_GROUP_NO;
    V_TAB_TYPE_GROUP_NO TAB_TYPE_GROUP_NO;
  
  BEGIN
    --ϵͳ��ʼ��������ÿ��EPS���ͼ�������Ĵ�С�����չ�λ˳�����ν�����������ĳ�ʼλ�ƣ�TT_ORD_EPS_MOVEMENT
    FOR V_REGION_VEPS IN CSR_REGION_VEPS LOOP
      INSERT INTO TT_ORD_VEPS_MOVEMENT
        (CAR_QUEUE_REGION_ID,
         REGION_ID,
         QAS_LOCATION_ORDER,
         PVI,
         CSN,
         CREATE_USER,
         UPDATE_USER,
         CREATE_DATE,
         UPDATE_DATE)
        SELECT SQ_ORD_PPS_CAR_QUEUE_REGION_ID.NEXTVAL,
               V_REGION_VEPS.REGION_ID,
               RM,
               NULL,
               NULL,
               I_USER,
               I_USER,
               SYSDATE,
               SYSDATE
          FROM (SELECT ROWNUM AS RM
                  FROM DUAL
                CONNECT BY ROWNUM <= V_REGION_VEPS.REGION_SIZE)
         WHERE RM > V_REGION_VEPS.VM_COUNT;
    END LOOP;
  
    SELECT DISTINCT R.GROUP_NO
      BULK COLLECT
      INTO V_TAB_TYPE_GROUP_NO
      FROM TM_MDS_REGION R
     WHERE R.REGION_TYPE = 'VEPS';
  
    FOR M IN V_TAB_TYPE_GROUP_NO.FIRST .. V_TAB_TYPE_GROUP_NO.LAST LOOP
      BEGIN
        SELECT RO.REGION_ID
          INTO V_REGION_ID
          FROM (SELECT R.REGION_ID
                  FROM TM_MDS_REGION R
                 WHERE R.GROUP_NO = V_TAB_TYPE_GROUP_NO(M).V_GROUP_NO
                 ORDER BY R.REGION_ORDER) RO
         WHERE ROWNUM = 1;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          PG_SYS_MONITOR_MSG.SP_SYS_MONITOR_MSG_PARA('550014',
                                                     V_TAB_TYPE_GROUP_NO(M)
                                                     .V_GROUP_NO,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     NULL);
          CONTINUE;
      END;
      --ɾ����λ˳��=0�ļ�¼
      DELETE FROM TT_ORD_VEPS_MOVEMENT VM
       WHERE EXISTS (SELECT 1
                FROM TM_MDS_REGION R
               WHERE VM.REGION_ID = R.REGION_ID
                 AND R.GROUP_NO = V_TAB_TYPE_GROUP_NO(M).V_GROUP_NO
                 AND R.REGION_ID <> V_REGION_ID)
         AND VM.QAS_LOCATION_ORDER = 0;
    END LOOP;
  
    --���¹�λ˳��>0�ļ�¼CSN=NULL��PVI=NULL
    UPDATE TT_ORD_VEPS_MOVEMENT VM
       SET VM.CSN = NULL, VM.PVI = NULL
     WHERE VM.QAS_LOCATION_ORDER > 0;
  
    --��ȡͬһ�������������µ�һ������  
    SELECT QI.QAS_INTERFACE_ID,
           QI.PLANT_CODE,
           QI.WORKSHOP_CODE,
           QI.CAR_QUEUE
      BULK COLLECT
      INTO V_TAB_TYPE_ORD_QAS
      FROM TI_ORD_QAS_INTERFACE QI
     WHERE QI.PROCESS_STATUS = '0'
       AND QI.QAS_INTERFACE_ID IN
           (SELECT MAX(QAS_INTERFACE_ID)
              FROM TI_ORD_QAS_INTERFACE OQI
             GROUP BY OQI.PLANT_CODE, OQI.WORKSHOP_CODE);
  
    IF V_TAB_TYPE_ORD_QAS.COUNT > 0 THEN
      --ѭ������QAS�ӿ�����
      FOR I IN V_TAB_TYPE_ORD_QAS.FIRST .. V_TAB_TYPE_ORD_QAS.LAST LOOP
        --�������з�QAS����λ����Ϣ
        SELECT COLUMN_VALUE
          BULK COLLECT
          INTO VT_CAR_QUEUE
          FROM TABLE(SGM_SPLIT(SUBSTR(V_TAB_TYPE_ORD_QAS(I).V_CAR_QUEUE,
                                      2,
                                      LENGTH(V_TAB_TYPE_ORD_QAS(I)
                                             .V_CAR_QUEUE) - 1),
                               ','));
        --ѭ������QAS����λ����Ϣ                       
        FOR J IN VT_CAR_QUEUE.FIRST .. VT_CAR_QUEUE.LAST LOOP
          --��ȡ�����������
          V_MONITOR_REGION_CODE := SUBSTR(TRIM(VT_CAR_QUEUE(J)),
                                          1,
                                          INSTR(TRIM(VT_CAR_QUEUE(J)), '=') - 1);
          --��ȡ��������ID                               
          BEGIN
            SELECT R.REGION_ID
              INTO V_MONITOR_REGION_ID
              FROM TM_MDS_REGION R
             WHERE R.REGION_CODE = V_MONITOR_REGION_CODE;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              PG_SYS_MONITOR_MSG.SP_SYS_MONITOR_MSG_PARA('550014',
                                                         V_MONITOR_REGION_CODE,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL);
              CONTINUE;
          END;
          --��|�з�ÿ��������λ����Ϣ
          SELECT COLUMN_VALUE
            BULK COLLECT
            INTO VT_CAR_INFO
            FROM TABLE(SGM_SPLIT(SUBSTR(TRIM(VT_CAR_QUEUE(J)),
                                        INSTR(TRIM(VT_CAR_QUEUE(J)), '=') + 1,
                                        LENGTH(TRIM(VT_CAR_QUEUE(J)))),
                                 '|'));
          FOR K IN VT_CAR_INFO.FIRST .. VT_CAR_INFO.LAST LOOP
            SELECT COLUMN_VALUE
              BULK COLLECT
              INTO VT_CAR_MOVEMENT
              FROM TABLE(SGM_SPLIT(TRIM(VT_CAR_INFO(K)), '@'));
          
            BEGIN
              SELECT MAX(VCQ.CSN)
                INTO V_MONITOR_CSN
                FROM TT_ORD_VEPS_CAR_QUEUE VCQ
               WHERE VCQ.PVI = VT_CAR_MOVEMENT(2);
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                PG_SYS_MONITOR_MSG.SP_SYS_MONITOR_MSG_PARA('550015',
                                                           VT_CAR_MOVEMENT(2),
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL);
                CONTINUE;
            END;
          
            --������0��129��256�����ù�λ�Ǹ��հ�,ֱ�Ӹ���PVI,CSNΪ��
            IF VT_CAR_MOVEMENT(3) = '0' OR VT_CAR_MOVEMENT(3) = '129' OR
               VT_CAR_MOVEMENT(3) = '256' THEN
              UPDATE TT_ORD_VEPS_MOVEMENT VM
                 SET VM.PVI = NULL, VM.CSN = NULL
               WHERE VM.REGION_ID = V_MONITOR_REGION_ID
                 AND VM.QAS_LOCATION_ORDER = VT_CAR_MOVEMENT(1);
            END IF;
          
            --���Ͳ���0��129��256ֱ�Ӹ���PVI,CSN
            IF VT_CAR_MOVEMENT(3) <> '0' AND VT_CAR_MOVEMENT(3) <> '129' AND
               VT_CAR_MOVEMENT(3) <> '256' THEN
              UPDATE TT_ORD_VEPS_MOVEMENT VM
                 SET VM.PVI = VT_CAR_MOVEMENT(2), VM.CSN = V_MONITOR_CSN
               WHERE VM.REGION_ID = V_MONITOR_REGION_ID
                 AND VM.QAS_LOCATION_ORDER = VT_CAR_MOVEMENT(1);
            END IF;
          END LOOP;
        END LOOP;
      
        --ADD 2017-11-14 ������֮����Ҫ����״̬Ϊ�Ѵ���
        UPDATE TI_ORD_QAS_INTERFACE QI
           SET QI.PROCESS_STATUS = '1'
         WHERE QI.QAS_INTERFACE_ID = V_TAB_TYPE_ORD_QAS(I)
              .V_QAS_INTERFACE_ID;
      END LOOP;
    
      SELECT VM.REGION_ID,
             R.REGION_ORDER,
             R.GROUP_NO,
             MIN(VM.CSN),
             MAX(VM.CSN)
        BULK COLLECT
        INTO V_TAB_TYPE_CSN_REGION
        FROM TT_ORD_VEPS_MOVEMENT VM, TM_MDS_REGION R
       WHERE VM.REGION_ID = R.REGION_ID
         AND VM.QAS_LOCATION_ORDER <> 0
       GROUP BY VM.REGION_ID, R.GROUP_NO, R.REGION_ORDER
       ORDER BY R.GROUP_NO, R.REGION_ORDER;
    
      --ADD 2017-11-14 ���㻺��������
      FOR L IN V_TAB_TYPE_CSN_REGION.FIRST .. V_TAB_TYPE_CSN_REGION.LAST LOOP
      
        SELECT R.REGION_ORDER, R.WORKSHOP_ID, R.GROUP_NO, R.SETOUT_FLAG
          INTO V_REGION_ORDER, V_WORKSHOP_ID, V_GROUP_NO, V_SETOUT_FLAG
          FROM TM_MDS_REGION R
         WHERE R.REGION_ID = V_TAB_TYPE_CSN_REGION(L).V_REGION_ID;
      
        --��(1)��(0)����setout���� 0:����/1:setout/2:setin/3:produced
        IF V_SETOUT_FLAG = '0' THEN
          V_SETOUT_FLAG := '1';
          V_SETOUT      := 'FALSE';
        ELSE
          V_SETOUT_FLAG := '99';
          V_SETOUT      := 'TRUE';
        END IF;
      
        SELECT COUNT(1)
          INTO V_COUNT
          FROM TM_MDS_REGION
         WHERE GROUP_NO = V_GROUP_NO
           AND REGION_ORDER < V_REGION_ORDER;
      
        IF V_COUNT > 0 THEN
        
          PG_DES_IMPORT.SP_GET_SAMEWGNO_PRE_REGION(I_WORKSHOP_ID  => V_WORKSHOP_ID,
                                                   I_GROUP_NO     => V_GROUP_NO,
                                                   I_REGION_ORDER => V_REGION_ORDER,
                                                   O_REGION_ID    => V_REGION_ID,
                                                   O_REGION_ORDER => V_REGION_ORDER);
          SELECT MIN(VM.CSN)
            INTO V_MIN_CSN
            FROM TT_ORD_VEPS_MOVEMENT VM
           WHERE VM.REGION_ID = V_REGION_ID
             AND VM.QAS_LOCATION_ORDER <> 0;
        
          IF V_MIN_CSN IS NULL THEN
            V_ISNULL_MINCSN_FLAG := 'TRUE';
          END IF;
        
          IF V_TAB_TYPE_CSN_REGION(L).V_MAX_CSN IS NULL THEN
            V_ISNULL_MAXCSN_FLAG := 'TRUE';
          END IF;
        
          IF V_MIN_CSN IS NULL AND V_TAB_TYPE_CSN_REGION(L)
            .V_MAX_CSN IS NULL THEN
            CONTINUE;
          END IF;
        
          INSERT INTO TT_ORD_VEPS_MOVEMENT
            (CAR_QUEUE_REGION_ID,
             REGION_ID,
             QAS_LOCATION_ORDER,
             PVI,
             CSN,
             CREATE_USER,
             UPDATE_USER,
             CREATE_DATE,
             UPDATE_DATE)
            SELECT SQ_ORD_PPS_CAR_QUEUE_REGION_ID.NEXTVAL,
                   V_TAB_TYPE_CSN_REGION(L).V_REGION_ID,
                   0,
                   VCQ.PVI,
                   VCQ.CSN,
                   I_USER,
                   I_USER,
                   SYSDATE,
                   SYSDATE
              FROM TT_ORD_VEPS_CAR_QUEUE VCQ
             WHERE NOT EXISTS
             (SELECT 1
                      FROM TT_ORD_VEPS_MOVEMENT VM
                     WHERE VM.REGION_ID = V_TAB_TYPE_CSN_REGION(L)
                          .V_REGION_ID
                       AND VM.CSN = VCQ.CSN)
               AND (V_ISNULL_MINCSN_FLAG = 'TRUE' OR VCQ.CSN < V_MIN_CSN)
               AND VCQ.MANUFACTURE_STATUS <> '3' --ADD 2017-11-16 �ų�����80��ĳ�
               AND (V_ISNULL_MAXCSN_FLAG = 'TRUE' OR
                   VCQ.CSN > V_TAB_TYPE_CSN_REGION(L).V_MAX_CSN)
               AND ('TRUE' = V_SETOUT OR
                   VCQ.MANUFACTURE_STATUS <> V_SETOUT_FLAG);
        END IF;
      
      END LOOP;
    
      FOR N IN V_TAB_TYPE_GROUP_NO.FIRST .. V_TAB_TYPE_GROUP_NO.LAST LOOP
        BEGIN
          SELECT RO.REGION_ID
            INTO V_REGION_ID
            FROM (SELECT R.REGION_ID
                    FROM TM_MDS_REGION R
                   WHERE R.GROUP_NO = V_TAB_TYPE_GROUP_NO(N).V_GROUP_NO
                   ORDER BY R.REGION_ORDER) RO
           WHERE ROWNUM = 1;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            PG_SYS_MONITOR_MSG.SP_SYS_MONITOR_MSG_PARA('550014',
                                                       V_TAB_TYPE_GROUP_NO(N)
                                                       .V_GROUP_NO,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL);
            CONTINUE;
        END;
      
        SELECT MAX(VM.CSN)
          INTO V_MAX_CSN
          FROM TT_ORD_VEPS_MOVEMENT VM, TM_MDS_REGION R
         WHERE VM.REGION_ID = R.REGION_ID
           AND R.GROUP_NO = V_TAB_TYPE_GROUP_NO(N).V_GROUP_NO
           AND VM.QAS_LOCATION_ORDER <> 0;
        --ɾ����λ˳��=0�ļ�¼
        IF V_MAX_CSN IS NULL THEN
          CONTINUE;
        ELSE
          DELETE FROM TT_ORD_VEPS_MOVEMENT VM
           WHERE VM.REGION_ID = V_REGION_ID
             AND VM.QAS_LOCATION_ORDER = 0
             AND VM.CSN <= V_MAX_CSN;
        END IF;
      END LOOP;
    
    END IF;
  
    --ADD 2017-11-14 ������λ��֮�������������
    PG_MCO_VEPS_CALC_CONSUME.SP_MCO_VEPS_CALC_CONSUME(I_USER_ID => I_USER,
                                                      O_STATUS  => O_STATUS,
                                                      O_RESULT  => O_RESULT);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      V_SQLERRM := SUBSTR(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 11) || '. ' ||
                   SQLERRM;
      --�����쳣��־
      PG_SYS_LOG.SP_SYS_PROGRAM_LOG('PG_ORD_VEPS_MOVEMENT.VIECHLE_MOVEMENT',
                                    '',
                                    V_SQLERRM);
    
      PG_SYS_MONITOR_MSG.SP_SYS_MONITOR_MSG_PARA(C_MONITOR_TYPE_MOVEMENT,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 NULL);
    
      O_STATUS := PG_JOB_UTILS.JOB_RUN_STATUS_FAIL;
      O_RESULT := 'VEPS MOVEMENT QUEUE FAIL';
  END VIECHLE_MOVEMENT;

  /******************************************************/
  /* Created : 2017-10-30 16:11:04                     */
  /* Description: VEPS����λ��                         */
  /*****************************************************/

  PROCEDURE VIECHLE_MOVEMENT_OLD(I_USER   IN NUMBER,
                                 O_STATUS OUT VARCHAR2,
                                 O_RESULT OUT VARCHAR2) AS
  
    V_SQLERRM VARCHAR2(1000); --������Ϣ
    --V_MONITOR_PARAMS        VARCHAR2(1000); -- ����ʱ�Ĳ�������
    --V_MONITOR_WORKSHOP_CODE TM_MDS_WORKSHOP.WORKSHOP_CODE%TYPE;
    V_MONITOR_REGION_ID   TM_MDS_REGION.REGION_ID%TYPE;
    V_MONITOR_REGION_CODE TM_MDS_REGION.REGION_CODE%TYPE;
    --V_MONITOR_PVI           TT_ORD_VEPS_MOVEMENT.PVI%TYPE;
    V_MONITOR_CSN        TT_ORD_VEPS_MOVEMENT.CSN%TYPE;
    V_CAR_QUEUE          TI_ORD_QAS_INTERFACE.CAR_QUEUE%TYPE;
    V_REGION_ID          TM_MDS_REGION.REGION_ID%TYPE;
    V_REGION_ORDER       TM_MDS_REGION.REGION_ORDER%TYPE;
    V_WORKSHOP_ID        TM_MDS_REGION.WORKSHOP_ID%TYPE;
    V_GROUP_NO           TM_MDS_REGION.GROUP_NO%TYPE;
    V_MAX_CSN            TT_ORD_VEPS_MOVEMENT.CSN%TYPE;
    V_MIN_CSN            TT_ORD_VEPS_MOVEMENT.CSN%TYPE;
    V_SETOUT_FLAG        TM_MDS_REGION.SETOUT_FLAG%TYPE;
    V_SETOUT             VARCHAR2(10);
    V_COUNT              NUMBER;
    V_ISNULL_MINCSN_FLAG VARCHAR2(10);
    V_ISNULL_MAXCSN_FLAG VARCHAR2(10);
    V_ISNULL_FIRST_FLAG  VARCHAR2(10);
    V_ISNULL_LAST_FLAG   VARCHAR2(10);
  
    TYPE T_CAR_QUEUE IS TABLE OF VARCHAR2(4000); --���������
    VT_CAR_QUEUE T_CAR_QUEUE;
  
    TYPE T_CAR_INFO IS TABLE OF VARCHAR2(4000); --���������
    VT_CAR_INFO T_CAR_INFO;
  
    TYPE T_CAR_MOVEMENT IS TABLE OF VARCHAR2(4000); --���������
    VT_CAR_MOVEMENT T_CAR_MOVEMENT;
  
    C_MONITOR_TYPE_MOVEMENT CONSTANT VARCHAR2(20) := '550016'; -- ���ɳ���λ�ƽ���ʧ�ܱ�������
  
    CURSOR CSR_REGION_VEPS IS(
      SELECT R.REGION_ID, R.REGION_SIZE
        FROM TM_MDS_REGION R
       WHERE R.REGION_TYPE = 'VEPS'
         AND R.REGION_STATUS = '1'
         AND NOT EXISTS (SELECT 1
                FROM TT_ORD_VEPS_MOVEMENT VM
               WHERE R.REGION_ID = VM.REGION_ID));
  
    TYPE TYPE_ORD_QAS IS RECORD(
      V_QAS_INTERFACE_ID TI_ORD_QAS_INTERFACE.QAS_INTERFACE_ID%TYPE,
      V_PLANT_CODE       TI_ORD_QAS_INTERFACE.PLANT_CODE%TYPE,
      V_WORKSHOP_CODE    TI_ORD_QAS_INTERFACE.WORKSHOP_CODE%TYPE,
      V_CAR_QUEUE        TI_ORD_QAS_INTERFACE.CAR_QUEUE%TYPE);
  
    TYPE TAB_TYPE_ORD_QAS IS TABLE OF TYPE_ORD_QAS;
    V_TAB_TYPE_ORD_QAS TAB_TYPE_ORD_QAS;
  
    TYPE TYPE_CSN_REGION IS RECORD(
      V_REGION_ID    TT_ORD_VEPS_MOVEMENT.REGION_ID%TYPE,
      V_REGION_ORDER TM_MDS_REGION.REGION_ORDER%TYPE,
      V_GROUP_NO     TM_MDS_REGION.GROUP_NO%TYPE,
      V_MIN_CSN      TT_ORD_VEPS_MOVEMENT.CSN%TYPE,
      V_MAX_CSN      TT_ORD_VEPS_MOVEMENT.CSN%TYPE);
  
    TYPE TAB_TYPE_CSN_REGION IS TABLE OF TYPE_CSN_REGION;
    V_TAB_TYPE_CSN_REGION TAB_TYPE_CSN_REGION;
  
    TYPE TYPE_GROUP_NO IS RECORD(
      V_GROUP_NO TM_MDS_REGION.GROUP_NO%TYPE);
  
    TYPE TAB_TYPE_GROUP_NO IS TABLE OF TYPE_GROUP_NO;
    V_TAB_TYPE_GROUP_NO TAB_TYPE_GROUP_NO;
  
  BEGIN
    --ϵͳ��ʼ��������ÿ��EPS���ͼ�������Ĵ�С�����չ�λ˳�����ν�����������ĳ�ʼλ�ƣ�TT_ORD_EPS_MOVEMENT
    FOR V_REGION_VEPS IN CSR_REGION_VEPS LOOP
      INSERT INTO TT_ORD_VEPS_MOVEMENT
        (CAR_QUEUE_REGION_ID,
         REGION_ID,
         QAS_LOCATION_ORDER,
         PVI,
         CSN,
         CREATE_USER,
         UPDATE_USER,
         CREATE_DATE,
         UPDATE_DATE)
        SELECT SQ_ORD_PPS_CAR_QUEUE_REGION_ID.NEXTVAL,
               V_REGION_VEPS.REGION_ID,
               ROWNUM,
               NULL,
               NULL,
               I_USER,
               I_USER,
               SYSDATE,
               SYSDATE
          FROM DUAL
        CONNECT BY ROWNUM <= V_REGION_VEPS.REGION_SIZE;
    END LOOP;
  
    --ɾ����λ˳��=0�ļ�¼
    DELETE FROM TT_ORD_VEPS_MOVEMENT VM WHERE VM.QAS_LOCATION_ORDER = 0;
  
    --���¹�λ˳��>0�ļ�¼CSN=NULL��PVI=NULL
    UPDATE TT_ORD_VEPS_MOVEMENT VM
       SET VM.CSN = NULL, VM.PVI = NULL
     WHERE VM.QAS_LOCATION_ORDER > 0;
  
    --��ȡͬһ�������������µ�һ������  
    SELECT QI.QAS_INTERFACE_ID,
           QI.PLANT_CODE,
           QI.WORKSHOP_CODE,
           QI.CAR_QUEUE
      BULK COLLECT
      INTO V_TAB_TYPE_ORD_QAS
      FROM TI_ORD_QAS_INTERFACE QI
     WHERE QI.PROCESS_STATUS = '0'
       AND QI.QAS_INTERFACE_ID IN
           (SELECT MAX(QAS_INTERFACE_ID)
              FROM TI_ORD_QAS_INTERFACE OQI
             GROUP BY OQI.PLANT_CODE, OQI.WORKSHOP_CODE);
  
    IF V_TAB_TYPE_ORD_QAS.COUNT > 0 THEN
      --ѭ������QAS�ӿ�����
      FOR I IN V_TAB_TYPE_ORD_QAS.FIRST .. V_TAB_TYPE_ORD_QAS.LAST LOOP
        --�������з�QAS����λ����Ϣ
        SELECT COLUMN_VALUE
          BULK COLLECT
          INTO VT_CAR_QUEUE
          FROM TABLE(SGM_SPLIT(SUBSTR(V_TAB_TYPE_ORD_QAS(I).V_CAR_QUEUE,
                                      2,
                                      LENGTH(V_TAB_TYPE_ORD_QAS(I)
                                             .V_CAR_QUEUE) - 1),
                               ','));
        --ѭ������QAS����λ����Ϣ                       
        FOR J IN VT_CAR_QUEUE.FIRST .. VT_CAR_QUEUE.LAST LOOP
          --��ȡ�����������
          V_MONITOR_REGION_CODE := SUBSTR(TRIM(VT_CAR_QUEUE(J)),
                                          1,
                                          INSTR(TRIM(VT_CAR_QUEUE(J)), '=') - 1);
          --��ȡ��������ID                               
          BEGIN
            SELECT R.REGION_ID
              INTO V_MONITOR_REGION_ID
              FROM TM_MDS_REGION R
             WHERE R.REGION_CODE = V_MONITOR_REGION_CODE;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              PG_SYS_MONITOR_MSG.SP_SYS_MONITOR_MSG_PARA('550014',
                                                         V_MONITOR_REGION_CODE,
                                                         NULL,
                                                         NULL,
                                                         NULL,
                                                         NULL);
              CONTINUE;
          END;
          --��|�з�ÿ��������λ����Ϣ
          SELECT COLUMN_VALUE
            BULK COLLECT
            INTO VT_CAR_INFO
            FROM TABLE(SGM_SPLIT(SUBSTR(TRIM(VT_CAR_QUEUE(J)),
                                        INSTR(TRIM(VT_CAR_QUEUE(J)), '=') + 1,
                                        LENGTH(TRIM(VT_CAR_QUEUE(J)))),
                                 '|'));
          FOR K IN VT_CAR_INFO.FIRST .. VT_CAR_INFO.LAST LOOP
            SELECT COLUMN_VALUE
              BULK COLLECT
              INTO VT_CAR_MOVEMENT
              FROM TABLE(SGM_SPLIT(TRIM(VT_CAR_INFO(K)), '@'));
          
            BEGIN
              SELECT MAX(VCQ.CSN)
                INTO V_MONITOR_CSN
                FROM TT_ORD_VEPS_CAR_QUEUE VCQ
               WHERE VCQ.PVI = VT_CAR_MOVEMENT(2);
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                PG_SYS_MONITOR_MSG.SP_SYS_MONITOR_MSG_PARA('550015',
                                                           VT_CAR_MOVEMENT(2),
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL);
                CONTINUE;
            END;
          
            --������0��129��256�����ù�λ�Ǹ��հ�,ֱ�Ӹ���PVI,CSNΪ��
            IF VT_CAR_MOVEMENT(3) = '0' OR VT_CAR_MOVEMENT(3) = '129' OR
               VT_CAR_MOVEMENT(3) = '256' THEN
              UPDATE TT_ORD_VEPS_MOVEMENT VM
                 SET VM.PVI = NULL, VM.CSN = NULL
               WHERE VM.REGION_ID = V_MONITOR_REGION_ID
                 AND VM.QAS_LOCATION_ORDER = VT_CAR_MOVEMENT(1);
            END IF;
          
            --���Ͳ���0��129��256ֱ�Ӹ���PVI,CSN
            IF VT_CAR_MOVEMENT(3) <> '0' AND VT_CAR_MOVEMENT(3) <> '129' AND
               VT_CAR_MOVEMENT(3) <> '256' THEN
              UPDATE TT_ORD_VEPS_MOVEMENT VM
                 SET VM.PVI = VT_CAR_MOVEMENT(2), VM.CSN = V_MONITOR_CSN
               WHERE VM.REGION_ID = V_MONITOR_REGION_ID
                 AND VM.QAS_LOCATION_ORDER = VT_CAR_MOVEMENT(1);
            END IF;
          END LOOP;
        END LOOP;
      
        --ADD 2017-11-14 ������֮����Ҫ����״̬Ϊ�Ѵ���
        UPDATE TI_ORD_QAS_INTERFACE QI
           SET QI.PROCESS_STATUS = '1'
         WHERE QI.QAS_INTERFACE_ID = V_TAB_TYPE_ORD_QAS(I)
              .V_QAS_INTERFACE_ID;
      END LOOP;
    
      SELECT DISTINCT R.GROUP_NO
        BULK COLLECT
        INTO V_TAB_TYPE_GROUP_NO
        FROM TM_MDS_REGION R
       WHERE R.REGION_TYPE = 'VEPS';
    
      /*    SELECT VM.REGION_ID, MIN(VM.CSN), MAX(VM.CSN)
       BULK COLLECT
       INTO V_TAB_TYPE_CSN_REGION
       FROM TT_ORD_VEPS_MOVEMENT VM
      GROUP BY VM.REGION_ID;*/
    
      FOR M IN V_TAB_TYPE_GROUP_NO.FIRST .. V_TAB_TYPE_GROUP_NO.LAST LOOP
        SELECT VM.REGION_ID,
               R.REGION_ORDER,
               R.GROUP_NO,
               MIN(VM.CSN),
               MAX(VM.CSN)
          BULK COLLECT
          INTO V_TAB_TYPE_CSN_REGION
          FROM TT_ORD_VEPS_MOVEMENT VM, TM_MDS_REGION R
         WHERE VM.REGION_ID = R.REGION_ID
           AND R.GROUP_NO = V_TAB_TYPE_GROUP_NO(M).V_GROUP_NO
           AND VM.QAS_LOCATION_ORDER <> 0
         GROUP BY VM.REGION_ID, R.GROUP_NO, R.REGION_ORDER
         ORDER BY R.GROUP_NO, R.REGION_ORDER;
      
        IF V_TAB_TYPE_CSN_REGION.COUNT = 1 THEN
          SELECT R.REGION_ORDER, R.WORKSHOP_ID, R.GROUP_NO, R.SETOUT_FLAG
            INTO V_REGION_ORDER, V_WORKSHOP_ID, V_GROUP_NO, V_SETOUT_FLAG
            FROM TM_MDS_REGION R
           WHERE R.REGION_ID = V_TAB_TYPE_CSN_REGION(1).V_REGION_ID;
        
          --��(1)��(0)����setout���� 0:����/1:setout/2:setin/3:produced
          IF V_SETOUT_FLAG = '0' THEN
            V_SETOUT_FLAG := '1';
            V_SETOUT      := 'FALSE';
          ELSE
            V_SETOUT_FLAG := '99';
            V_SETOUT      := 'TRUE';
          END IF;
        
          INSERT INTO TT_ORD_VEPS_MOVEMENT
            (CAR_QUEUE_REGION_ID,
             REGION_ID,
             QAS_LOCATION_ORDER,
             PVI,
             CSN,
             CREATE_USER,
             UPDATE_USER,
             CREATE_DATE,
             UPDATE_DATE)
            SELECT SQ_ORD_PPS_CAR_QUEUE_REGION_ID.NEXTVAL,
                   V_TAB_TYPE_CSN_REGION(1).V_REGION_ID,
                   0,
                   VCQ.PVI,
                   VCQ.CSN,
                   I_USER,
                   I_USER,
                   SYSDATE,
                   SYSDATE
              FROM TT_ORD_VEPS_CAR_QUEUE VCQ
             WHERE NOT EXISTS
             (SELECT 1
                      FROM TT_ORD_VEPS_MOVEMENT VM
                     WHERE VM.REGION_ID = V_TAB_TYPE_CSN_REGION(1)
                          .V_REGION_ID
                       AND VM.CSN = VCQ.CSN)
               AND VCQ.MANUFACTURE_STATUS <> '3' --ADD 2017-11-16 �ų�����80��ĳ�
               AND ('TRUE' = V_SETOUT OR
                   VCQ.MANUFACTURE_STATUS <> V_SETOUT_FLAG);
          CONTINUE;
        END IF;
      
        IF V_TAB_TYPE_CSN_REGION.COUNT > 1 THEN
          V_ISNULL_FIRST_FLAG := 'FALSE';
          V_ISNULL_LAST_FLAG  := 'FALSE';
          IF V_TAB_TYPE_CSN_REGION(V_TAB_TYPE_CSN_REGION.FIRST)
           .V_MIN_CSN IS NULL AND V_TAB_TYPE_CSN_REGION(V_TAB_TYPE_CSN_REGION.FIRST)
             .V_MAX_CSN IS NULL THEN
            V_ISNULL_FIRST_FLAG := 'TRUE';
          END IF;
        
          IF V_TAB_TYPE_CSN_REGION(V_TAB_TYPE_CSN_REGION.LAST)
           .V_MIN_CSN IS NULL AND V_TAB_TYPE_CSN_REGION(V_TAB_TYPE_CSN_REGION.LAST)
             .V_MAX_CSN IS NULL THEN
            V_ISNULL_LAST_FLAG := 'TRUE';
          END IF;
        
          IF V_ISNULL_FIRST_FLAG = 'TRUE' AND V_ISNULL_LAST_FLAG = 'TRUE' THEN
            INSERT INTO TT_ORD_VEPS_MOVEMENT
              (CAR_QUEUE_REGION_ID,
               REGION_ID,
               QAS_LOCATION_ORDER,
               PVI,
               CSN,
               CREATE_USER,
               UPDATE_USER,
               CREATE_DATE,
               UPDATE_DATE)
              SELECT SQ_ORD_PPS_CAR_QUEUE_REGION_ID.NEXTVAL,
                     V_TAB_TYPE_CSN_REGION(1).V_REGION_ID,
                     0,
                     VCQ.PVI,
                     VCQ.CSN,
                     I_USER,
                     I_USER,
                     SYSDATE,
                     SYSDATE
                FROM TT_ORD_VEPS_CAR_QUEUE VCQ
               WHERE NOT EXISTS
               (SELECT 1
                        FROM TT_ORD_VEPS_MOVEMENT VM
                       WHERE VM.REGION_ID = V_TAB_TYPE_CSN_REGION(1)
                            .V_REGION_ID
                         AND VM.CSN = VCQ.CSN)
                 AND VCQ.MANUFACTURE_STATUS <> '3' --ADD 2017-11-16 �ų�����80��ĳ�
                 AND ('TRUE' = V_SETOUT OR
                     VCQ.MANUFACTURE_STATUS <> V_SETOUT_FLAG);
            CONTINUE;
          END IF;
        END IF;
      
        --ADD 2017-11-14 ���㻺��������
        FOR L IN V_TAB_TYPE_CSN_REGION.FIRST .. V_TAB_TYPE_CSN_REGION.LAST LOOP
        
          SELECT R.REGION_ORDER, R.WORKSHOP_ID, R.GROUP_NO, R.SETOUT_FLAG
            INTO V_REGION_ORDER, V_WORKSHOP_ID, V_GROUP_NO, V_SETOUT_FLAG
            FROM TM_MDS_REGION R
           WHERE R.REGION_ID = V_TAB_TYPE_CSN_REGION(L).V_REGION_ID;
        
          --��(1)��(0)����setout���� 0:����/1:setout/2:setin/3:produced
          IF V_SETOUT_FLAG = '0' THEN
            V_SETOUT_FLAG := '1';
            V_SETOUT      := 'FALSE';
          ELSE
            V_SETOUT_FLAG := '99';
            V_SETOUT      := 'TRUE';
          END IF;
        
          IF V_ISNULL_FIRST_FLAG = 'FALSE' THEN
            SELECT COUNT(1)
              INTO V_COUNT
              FROM TM_MDS_REGION
             WHERE GROUP_NO = V_GROUP_NO
               AND REGION_ORDER < V_REGION_ORDER;
          
            IF V_COUNT = 0 THEN
              INSERT INTO TT_ORD_VEPS_MOVEMENT
                (CAR_QUEUE_REGION_ID,
                 REGION_ID,
                 QAS_LOCATION_ORDER,
                 PVI,
                 CSN,
                 CREATE_USER,
                 UPDATE_USER,
                 CREATE_DATE,
                 UPDATE_DATE)
                SELECT SQ_ORD_PPS_CAR_QUEUE_REGION_ID.NEXTVAL,
                       V_TAB_TYPE_CSN_REGION(L).V_REGION_ID,
                       0,
                       VCQ.PVI,
                       VCQ.CSN,
                       I_USER,
                       I_USER,
                       SYSDATE,
                       SYSDATE
                  FROM TT_ORD_VEPS_CAR_QUEUE VCQ
                 WHERE NOT EXISTS
                 (SELECT 1
                          FROM TT_ORD_VEPS_MOVEMENT VM
                         WHERE VM.REGION_ID = V_TAB_TYPE_CSN_REGION(1)
                              .V_REGION_ID
                           AND VM.CSN = VCQ.CSN)
                   AND VCQ.CSN >
                       NVL(V_TAB_TYPE_CSN_REGION(L).V_MAX_CSN, '0')
                   AND VCQ.MANUFACTURE_STATUS <> '3' --ADD 2017-11-16 �ų�����80��ĳ�
                   AND ('TRUE' = V_SETOUT OR
                       VCQ.MANUFACTURE_STATUS <> V_SETOUT_FLAG);
            ELSE
              PG_DES_IMPORT.SP_GET_SAMEWGNO_PRE_REGION(I_WORKSHOP_ID  => V_WORKSHOP_ID,
                                                       I_GROUP_NO     => V_GROUP_NO,
                                                       I_REGION_ORDER => V_REGION_ORDER,
                                                       O_REGION_ID    => V_REGION_ID,
                                                       O_REGION_ORDER => V_REGION_ORDER);
              SELECT MIN(VM.CSN)
                INTO V_MIN_CSN
                FROM TT_ORD_VEPS_MOVEMENT VM
               WHERE VM.REGION_ID = V_REGION_ID
                 AND VM.QAS_LOCATION_ORDER <> 0;
            
              IF V_MIN_CSN IS NULL THEN
                V_ISNULL_MINCSN_FLAG := 'TRUE';
              END IF;
            
              IF V_TAB_TYPE_CSN_REGION(L).V_MAX_CSN IS NULL THEN
                V_ISNULL_MAXCSN_FLAG := 'TRUE';
              END IF;
            
              IF V_MIN_CSN IS NULL AND V_TAB_TYPE_CSN_REGION(L)
                .V_MAX_CSN IS NULL THEN
                CONTINUE;
              END IF;
            
              INSERT INTO TT_ORD_VEPS_MOVEMENT
                (CAR_QUEUE_REGION_ID,
                 REGION_ID,
                 QAS_LOCATION_ORDER,
                 PVI,
                 CSN,
                 CREATE_USER,
                 UPDATE_USER,
                 CREATE_DATE,
                 UPDATE_DATE)
                SELECT SQ_ORD_PPS_CAR_QUEUE_REGION_ID.NEXTVAL,
                       V_TAB_TYPE_CSN_REGION(L).V_REGION_ID,
                       0,
                       VCQ.PVI,
                       VCQ.CSN,
                       I_USER,
                       I_USER,
                       SYSDATE,
                       SYSDATE
                  FROM TT_ORD_VEPS_CAR_QUEUE VCQ
                 WHERE (V_ISNULL_MINCSN_FLAG = 'TRUE' OR
                       VCQ.CSN < V_MIN_CSN)
                   AND VCQ.MANUFACTURE_STATUS <> '3' --ADD 2017-11-16 �ų�����80��ĳ�
                   AND (V_ISNULL_MAXCSN_FLAG = 'TRUE' OR
                       VCQ.CSN > V_TAB_TYPE_CSN_REGION(L).V_MAX_CSN)
                   AND ('TRUE' = V_SETOUT OR
                       VCQ.MANUFACTURE_STATUS <> V_SETOUT_FLAG);
            END IF;
          END IF;
        
        END LOOP;
      END LOOP;
    END IF;
  
    --ADD 2017-11-14 ������λ��֮�������������
    /* PG_MCO_VEPS_CALC_CONSUME.SP_MCO_VEPS_CALC_CONSUME(I_USER_ID => I_USER,
    O_STATUS  => O_STATUS,
    O_RESULT  => O_RESULT);*/
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      V_SQLERRM := SUBSTR(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 11) || '. ' ||
                   SQLERRM;
      --�����쳣��־
      PG_SYS_LOG.SP_SYS_PROGRAM_LOG('PG_ORD_VEPS_MOVEMENT.VIECHLE_MOVEMENT',
                                    '',
                                    V_SQLERRM);
    
      PG_SYS_MONITOR_MSG.SP_SYS_MONITOR_MSG_PARA(C_MONITOR_TYPE_MOVEMENT,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 NULL);
    
      O_STATUS := PG_JOB_UTILS.JOB_RUN_STATUS_FAIL;
      O_RESULT := 'VEPS MOVEMENT QUEUE FAIL';
  END VIECHLE_MOVEMENT_OLD;
END PG_ORD_VEPS_MOVEMENT;
/