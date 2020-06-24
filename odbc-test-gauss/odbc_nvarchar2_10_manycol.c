/*
����odbc֧��nvarchar2����
test: �����ı��ж���ֶ�,�Ҳ����ֶ�Ϊ����
*/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sql.h>
#include <sqlext.h>
#include <sqltypes.h>

 /*global*/
 SQLLEN cbSID =100;
 
 char omg[200];
 SQLINTEGER errInfo = 0;
 
 SQLSMALLINT errCb = 0;
 
 SQLCHAR errStat[200];
 SQLCHAR errMsg[200];
   
int main( )
{
   SQLHENV         hEnv    = SQL_NULL_HENV;
   SQLHDBC         hDbc    = SQL_NULL_HDBC;
   SQLHSTMT        hStmt   = SQL_NULL_HSTMT;
   SQLRETURN       rc      = SQL_SUCCESS;
   SQLINTEGER      RETCODE = 0;
   
   (void) printf ("**** Entering CLIP06.\n\n");
  /*****************************************************************/
  /* Allocate environment handle                                   */
  /*****************************************************************/
   RETCODE = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &hEnv);
   if (!SQL_SUCCEEDED(RETCODE))
   { SQLGetDiagRec(SQL_HANDLE_DBC,hDbc,1, errStat,&errInfo,errMsg,100,&errCb);
     printf("%s \n",errMsg);       
     goto dberror;
	} 
   SQLSetEnvAttr(hEnv, SQL_ATTR_ODBC_VERSION, (void*)SQL_OV_ODBC3, 0); 

  /*****************************************************************/
  /* Allocate connection handle to DSN                             */
  /*****************************************************************/
   RETCODE = SQLAllocHandle(SQL_HANDLE_DBC, hEnv, &hDbc);
   if( !SQL_SUCCEEDED(RETCODE) )      // Could not get a Connect Handle
   { SQLGetDiagRec(SQL_HANDLE_DBC,hDbc,1, errStat,&errInfo,errMsg,100,&errCb);
     printf("%s \n",errMsg);       
     goto dberror;
   }
  /*****************************************************************/
  /* CONNECT TO data source (STLEC1)                               */
  /*****************************************************************/
   RETCODE = SQLConnect(hDbc,        // Connect handle
                        (SQLCHAR *)"gaussdb", // DSN
                        SQL_NTS,     // DSN is nul-terminated
                        NULL,        // Null UID
                        0   ,
                        NULL,        // Null Auth string
                        0);
	 
   if( !SQL_SUCCEEDED(RETCODE))      // Connect failed
   { SQLGetDiagRec(SQL_HANDLE_DBC,hDbc,1, errStat,&errInfo,errMsg,100,&errCb);
     printf("%s \n",errMsg);       
     goto dberror;
	} 
  /*****************************************************************/
  /* Allocate statement handle                                     */
  /*****************************************************************/
   rc = SQLAllocHandle(SQL_HANDLE_STMT, hDbc, &hStmt);
   if (!SQL_SUCCEEDED(rc))
   { SQLGetDiagRec(SQL_HANDLE_DBC,hDbc,1, errStat,&errInfo,errMsg,100,&errCb);
     printf("%s \n",errMsg);       
     goto exit;
	} 
  /*****************************************************************/
  /* Retrieve native SQL types from DSN            				   */
  /*****************************************************************/ 
   rc = SQLExecDirect(hStmt,"drop table  IF EXISTS odbc_nvarchar2_10_manycol",SQL_NTS);
   if (!SQL_SUCCEEDED(rc))
   { SQLGetDiagRec(SQL_HANDLE_STMT,hStmt,1, errStat,&errInfo,errMsg,100,&errCb);
     printf("%s \n",errMsg);     
	 goto exit;
	} 
   rc = SQLExecDirect(hStmt,"create table odbc_nvarchar2_10_manycol(id tinyint,ft float,identi char(20),omg nvarchar2(20),tm timestamp)",SQL_NTS);
   if (!SQL_SUCCEEDED(rc))
   { SQLGetDiagRec(SQL_HANDLE_STMT,hStmt,1, errStat,&errInfo,errMsg,100,&errCb);
     printf("%s \n",errMsg);     
     goto exit;
	}
	/* tinyint [0,255] */
   rc = SQLExecDirect(hStmt,"insert into odbc_nvarchar2_10_manycol values(228,2.88,'ni hao','你好','2013-07-23 13:55:55')",SQL_NTS);
   if (!SQL_SUCCEEDED(rc))
   { SQLGetDiagRec(SQL_HANDLE_STMT,hStmt,1, errStat,&errInfo,errMsg,100,&errCb);
     printf("%s \n",errMsg);   
    goto exit;
   } 
   rc = SQLExecDirect(hStmt,"select omg from odbc_nvarchar2_10_manycol",SQL_NTS);
   
   if (!SQL_SUCCEEDED(rc))
   { SQLGetDiagRec(SQL_HANDLE_STMT,hStmt,1, errStat,&errInfo,errMsg,100,&errCb);
     printf("%s \n",errMsg);      
     goto exit;
   }
   //test SQLBindCol
   rc = SQLBindCol(hStmt,1,SQL_C_CHAR, (SQLPOINTER)&omg,sizeof(omg),&cbSID);
   
   if (!SQL_SUCCEEDED(rc))
   { SQLGetDiagRec(SQL_HANDLE_DBC,hDbc,1, errStat,&errInfo,errMsg,100,&errCb);
     printf("%s \n",errMsg);     
     goto exit;
   }
   rc = SQLFetch(hStmt);  
   while(rc != SQL_NO_DATA)
   {
     printf("omg = %s\n",omg);
     rc = SQLFetch(hStmt);  
   };
	
   if (!SQL_SUCCEEDED(rc) && rc != SQL_NO_DATA)
   { SQLGetDiagRec(SQL_HANDLE_DBC,hDbc,1, errStat,&errInfo,errMsg,100,&errCb);
     printf("%s \n",errMsg);     
     goto exit;
   }
  /*****************************************************************/
  /* Free statement handle                                         */
  /*****************************************************************/
   RETCODE = SQLFreeHandle(SQL_HANDLE_STMT, hStmt);
   if (!SQL_SUCCEEDED(RETCODE))       // An advertised API failed
     goto dberror;
  /*****************************************************************/
  /* DISCONNECT from data source                                   */
  /*****************************************************************/
   RETCODE = SQLDisconnect(hDbc);
   if (!SQL_SUCCEEDED(RETCODE))
     goto dberror;
  /*****************************************************************/
  /* Deallocate connection handle                                  */
  /*****************************************************************/
   RETCODE = SQLFreeHandle(SQL_HANDLE_DBC, hDbc);
   if (!SQL_SUCCEEDED(RETCODE))
     goto dberror;
   /*****************************************************************/
  /* Free environment handle                                       */
  /*****************************************************************/
   RETCODE = SQLFreeHandle(SQL_HANDLE_ENV, hEnv);
   if (!SQL_SUCCEEDED(RETCODE))
     goto exit;
   return 0;

dberror:
   RETCODE=12;
exit:
     (void) printf ("**** Exiting  CLIP06.\n\n");
     return(RETCODE);
}
