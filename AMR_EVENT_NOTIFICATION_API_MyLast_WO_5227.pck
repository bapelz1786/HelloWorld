create or replace package AMR_EVENT_NOTIFICATION_API is

module_  CONSTANT VARCHAR2(25) := 'AMR';
lu_name_ CONSTANT VARCHAR2(25) := 'AmrEventNotification';

PROCEDURE Reprint_Send_Report (
  param_attr_ IN VARCHAR2);
  
FUNCTION Check_Result_Key_Sent (
  result_key_     IN NUMBER) RETURN VARCHAR2; 
  
-- 20190118, start
FUNCTION Get_Sales_Rep_Email_ (
  user_name_    IN VARCHAR2) RETURN VARCHAR2;
-- 20190118, end

  
end AMR_EVENT_NOTIFICATION_API;
/
create or replace package body AMR_EVENT_NOTIFICATION_API is

PROCEDURE Reprint_Report_ (
  language_code_    IN VARCHAR2,
  report_id_        IN VARCHAR2,
  printed_by_       IN VARCHAR2,
  report_type_      IN VARCHAR2,
  result_key_       IN NUMBER);

PROCEDURE Email_Report_ (
  result_key_   IN NUMBER,
  report_id_    IN VARCHAR2,
  report_type_  IN VARCHAR2,
  pdf_file_     IN VARCHAR2,
  printed_by_   IN VARCHAR2);

FUNCTION Printed_Forms_Flag_Exist_ (
  result_key_   IN NUMBER,
  report_id_    IN VARCHAR2,
  report_type_  IN VARCHAR2) RETURN BOOLEAN;



-- This function returns a value to determine if a hard copy printout should be printed
-- If returns TRUE, then need to print out a hardcopy of the report id
FUNCTION Printed_Forms_Flag_Exist_ (
  result_key_   IN NUMBER,
  report_id_    IN VARCHAR2,
  report_type_  IN VARCHAR2) RETURN BOOLEAN
  
IS
  -- Define local variables
  report_type_like_  VARCHAR2(20);
  return_val_        BOOLEAN;
  dummy_             NUMBER;
  str_key1           VARCHAR2(50) := '';
  num_key1           NUMBER;
  str_key2           VARCHAR2(50) := '';
  str_key3           VARCHAR2(50) := '';
  --str_key4           VARCHAR2(50) := '';
  --num_key1           NUMBER := 0;
  --num_key2           NUMBER := 0;
  
  
  -- Define cursors for reports
  
  -- CUSTOMER_ORDER_CONF_REP, Customer Order Confirmation
  CURSOR get_ord_conf(order_no_ VARCHAR2, report_type_like_ VARCHAR2) IS
  select distinct 1
      from 
        CUSTOMER_ORDER co,
        COMM_METHOD_CFV cm
      where 
        co.order_no = order_no_ and
        cm.PARTY_TYPE_DB = 'CUSTOMER' and
        co.customer_no = cm.identity and
        co.ship_addr_no = cm.address_id and
        cm.cf$_amr_print_form_db like report_type_like_;

  -- For Advance invoice, customer invoice, and collective invoice
  CURSOR cust_ord_inv_cur(invoice_id_ NUMBER, report_type_like_ VARCHAR2) IS
     SELECT distinct 1
     FROM   
        customer_order_inv_head ih,
        comm_method_cfv cm
      WHERE  
         ih.invoice_id = invoice_id_ and
         ih.identity = cm.identity and
         cm.PARTY_TYPE_DB = 'CUSTOMER' and    
         cm.cf$_amr_print_form_db like report_type_like_;
         
  -- For instant invoice
     CURSOR instant_ivc_cur(invoice_id_ NUMBER, report_type_like_ VARCHAR2) IS
     SELECT distinct 1
     FROM   
          Invoice i,
          comm_method_cfv cm
     WHERE 
          i.invoice_id = invoice_id_ and
          i.identity = cm.identity and
          cm.PARTY_TYPE_DB = 'CUSTOMER' and
          cm.cf$_amr_email_form_db like report_type_like_;

  -- For order quotation
     CURSOR quote_addr_cur(quotation_no_ IN VARCHAR2, report_type_like_ VARCHAR2) IS
     select distinct 1
     from 
        order_quotation oq,
        comm_method_cfv cm
     where 
        oq.quotation_no = quotation_no_ and
        cm.PARTY_TYPE_DB = 'CUSTOMER' and
        oq.customer_no = cm.identity and
        oq.ship_addr_no = cm.address_id and
        cm.cf$_amr_email_form_db like report_type_like_; 

  -- For customer statement of accounts
  CURSOR cust_statement(customer_id_ IN VARCHAR2, report_type_like_ VARCHAR2) IS
  select distinct 1
      from 
        COMM_METHOD_CFV cm
      where 
        cm.PARTY_TYPE_DB = 'CUSTOMER' and
        cm.identity = customer_id_ and
        cm.cf$_amr_print_form_db like report_type_like_;
        
  -- For "normal" rma report
  CURSOR rma_cur(rma_no_ IN NUMBER, report_type_like_ VARCHAR2) IS
  select distinct 1
    from
      return_material rm,
      comm_method_cfv cm
    where 
        rm.rma_no = rma_no_ and
        cm.PARTY_TYPE_DB = 'CUSTOMER' and
        rm.customer_no = cm.identity and
        rm.ship_addr_no = cm.address_id and
        cm.cf$_amr_print_form_db like report_type_like_;
   
  -- For work order rma reports
  CURSOR wo_rma_cur(wo_no_ IN NUMBER, report_type_like_ VARCHAR2) IS
  select distinct 1
      from
        active_separate wo,
        cust_ord_customer coc,
        comm_method_cfv cm
      where
             wo.customer_no = coc.customer_no and
             cm.PARTY_TYPE_DB = 'CUSTOMER' and
             wo.customer_no = cm.identity and
             Customer_Info_Address_Type_API.Get_Default_Address_Id(wo.customer_no, 'DELIVERY') = cm.address_id and
             cm.cf$_amr_print_form_db like report_type_like_ and
             wo.wo_no = wo_no_;
  
  
        
BEGIN
  
  -- Set the report type format
  report_type_like_ := '%^' || report_type_ || '^%';
  
  IF (report_id_ = 'CUSTOMER_ORDER_CONF_REP') THEN
    
      -- str_key1 = ORDER_NO report parameter
      str_key1 := archive_parameter_api.get_parameter_value(result_key_, 'ORDER_NO');
   
      OPEN get_ord_conf(str_key1, report_type_like_);
      FETCH get_ord_conf INTO dummy_;
      IF get_ord_conf%FOUND THEN 
        return_val_ := TRUE;
      ELSE
        return_val_ := FALSE;
      END IF;
    
  ELSIF (report_id_ in ('CUSTOMER_ORDER_ADV_IVC_REP','CUSTOMER_ORDER_IVC_REP','CUSTOMER_ORDER_COLL_IVC_REP')) THEN
    
    -- num_key1 = INVOICE_ID report parameter
    num_key1 := TO_NUMBER(archive_parameter_api.get_parameter_value(result_key_, 'INVOICE_ID'));
  
    OPEN cust_ord_inv_cur(num_key1, report_type_like_);
    FETCH cust_ord_inv_cur INTO dummy_;
    IF cust_ord_inv_cur%FOUND THEN 
        return_val_ := TRUE;
    ELSE
        return_val_ := FALSE;
    END IF;
  
  ELSIF (report_id_ = 'INSTANT_INVOICE_REP') THEN
    
    -- num_key1 = INVOICE_ID report parameter
    num_key1 := TO_NUMBER(archive_parameter_api.get_parameter_value(result_key_, 'INVOICE_ID'));
  
    OPEN instant_ivc_cur(num_key1, report_type_like_);
    FETCH instant_ivc_cur INTO dummy_;
    IF instant_ivc_cur%FOUND THEN 
        return_val_ := TRUE;
    ELSE
        return_val_ := FALSE;
    END IF;
  
  ELSIF (report_id_ = 'ORDER_QUOTATION_REP') THEN
    
      -- str_key1 = ORDER_NO report parameter
      str_key1 := archive_parameter_api.get_parameter_value(result_key_, 'QUOTATION_NO');
   
      OPEN quote_addr_cur(str_key1, report_type_like_);
      FETCH quote_addr_cur INTO dummy_;
      IF quote_addr_cur%FOUND THEN 
        return_val_ := TRUE;
      ELSE
        return_val_ := FALSE;
      END IF;
  
  ELSIF (report_id_ = 'CUST_STMT_ACCT_REP') THEN
    
      -- str_key1 = ORDER_NO report parameter
      str_key1 := archive_parameter_api.get_parameter_value(result_key_, 'CUSTOMER_ID');
   
      OPEN cust_statement(str_key1, report_type_like_);
      FETCH cust_statement INTO dummy_;
      IF cust_statement%FOUND THEN 
        return_val_ := TRUE;
      ELSE
        return_val_ := FALSE;
      END IF;
  
  -- For "normal" RMA
  ELSIF (report_id_ = 'RETURN_MATERIAL_REP') THEN
    
      -- num_key1 = RMA_NO report parameter
      num_key1 := archive_parameter_api.get_parameter_value(result_key_, 'RMA_NO');
   
      OPEN rma_cur(num_key1, report_type_like_);
      FETCH rma_cur INTO dummy_;
      IF rma_cur%FOUND THEN 
        return_val_ := TRUE;
      ELSE
        return_val_ := FALSE;
      END IF;
  
  -- For work order RMA (this is a custom report id)
  ELSIF (report_id_ = 'AMR_ACTIVE_SEP_WO_RMA_REP') THEN
    
      -- num_key1 = WO_NO report parameter
      num_key1 := archive_parameter_api.get_parameter_value(result_key_, 'WO_NO');
   
      OPEN wo_rma_cur(num_key1, report_type_like_);
      FETCH wo_rma_cur INTO dummy_;
      IF wo_rma_cur%FOUND THEN 
        return_val_ := TRUE;
      ELSE
        return_val_ := FALSE;
      END IF;
  
  ELSIF (report_id_ = 'PURCHASE_ORDER_PRINT_REP') THEN
    -- Not based on custom fields on comm method
    -- Check the print flag on the customer
    
    -- There will only be one PO Number in the ORDER_NO_LIST parameter
    str_key1 := archive_parameter_api.get_parameter_value(result_key_, 'ORDER_NO_LIST');
    
    -- Get the vendor no for the order
    str_key2 := Purchase_Order_API.Get_Vendor_No(str_key1);
    
    -- Get the print order flag
    str_key3 := Supplier_API.Get_Purch_Order_Flag(str_key2);
    
    IF (str_key3 = 'Print order') THEN
      -- return_val_ := TRUE;
      return_val_ := FALSE; -- AHDBRPEUS, 20180816, updated to always return false no matter what
    ELSE
        return_val_ := FALSE;
    END IF;
    
    
  -- For supplier goods returned report
  ELSIF (report_id_ = 'PURCHASE_RECEIPT_RETURN_REP') THEN
    return_val_ := TRUE;
  
  ELSE
    return_val_ := FALSE;
  END IF;

  RETURN return_val_;

END Printed_Forms_Flag_Exist_; 


PROCEDURE Email_Report_ (
  result_key_   IN NUMBER,
  report_id_    IN VARCHAR2,
  report_type_  IN VARCHAR2,
  pdf_file_     IN VARCHAR2,
  printed_by_   IN VARCHAR2)
IS
  -- Define local variables
  msg_               VARCHAR2(4000);
  message_body_      VARCHAR2(1000);
  report_type_like_  VARCHAR2(20);
  event_id_          VARCHAR2(50) := 'AMR_SEND_EMAIL';
  event_lu_          VARCHAR2(50) := 'AmrEventNotification';
  str_key1           VARCHAR2(50) := '';
  str_key2           VARCHAR2(50) := '';
  str_key3           VARCHAR2(50) := '';
  num_key1           NUMBER;
  rec_count_         NUMBER := 0;
  from_name_         VARCHAR2(100);
  from_email_        VARCHAR2(100);
  to_email_          VARCHAR2(500);
  po_attach_         VARCHAR2(2000); -- bpelz, 20190408
  
  -- Define cursors
  
  -- This is the primary customer order cursor looking for a match for comm methods
  -- attached to the address and associated with the correct form type
  CURSOR ord_addr_mail_cur(order_no_ VARCHAR2, report_type_like_ VARCHAR2) IS
     select
      co.order_no,
      co.customer_no,
      airm1app.customer_info_api.get_name(co.customer_no) as customer_name,
      ca.addr_1 as ship_address_name,
      co.salesman_code,
      airm1app.person_info_api.get_name(co.salesman_code) as salesman_name,
      airm1app.Fnd_User_API.Get_Property(co.salesman_code, 'SMTP_MAIL_ADDRESS') as salesman_email,
      co.customer_po_no,
      -- cm.name as to_name,
      'Valued Customer' as to_name,
      -- cm.value as to_email_address
      airm1app.AMR_EVENT_NOTIFICATION_API.Get_Sales_Rep_Email_(co.cf$_amr_main_rep) as sales_rep_email,
      listagg(cm.value,',') within GROUP (ORDER BY cm.VALUE) as to_email_address
    from 
      CUSTOMER_ORDER_CFV co,
      CUSTOMER_ORDER_ADDRESS_2 ca,
      COMM_METHOD_CFV cm
    where 
       co.order_no = order_no_ and
       co.order_no = ca.order_no and
       cm.PARTY_TYPE_DB = 'CUSTOMER' and
       cm.method_id_db = 'E_MAIL' and
       co.customer_no = cm.identity and
       co.ship_addr_no = cm.address_id and
       cm.cf$_amr_email_form_db like report_type_like_
    group by
      co.order_no,
      co.customer_no,
      ca.addr_1,
      co.salesman_code,
      co.customer_po_no,
      co.cf$_amr_main_rep;
  
  -- This is a secondary cursor that is used to determine if there are any comm methds for the form type
  -- where the address id is null. This is only used if the primary cursor doesn't return any rows. It is a "catch all".
  CURSOR ord_mail_cur(order_no_ VARCHAR2, report_type_like_ VARCHAR2) IS
  select
      co.order_no,
      co.customer_no,
      airm1app.customer_info_api.get_name(co.customer_no) as customer_name,
      ca.addr_1 as ship_address_name,
      co.salesman_code,
      airm1app.person_info_api.get_name(co.salesman_code) as salesman_name,
      airm1app.Fnd_User_API.Get_Property(co.salesman_code, 'SMTP_MAIL_ADDRESS') as salesman_email,
      co.customer_po_no,
      -- cm.name as to_name,
      'Valued Customer' as to_name,
      -- cm.value as to_email_address
      airm1app.AMR_EVENT_NOTIFICATION_API.Get_Sales_Rep_Email_(co.cf$_amr_main_rep) as sales_rep_email,
      listagg(cm.value,',') within GROUP (ORDER BY cm.VALUE) as to_email_address
    from 
      CUSTOMER_ORDER_CFV co,
      CUSTOMER_ORDER_ADDRESS_2 ca,
      COMM_METHOD_CFV cm
    where 
       co.order_no = order_no_ and
       co.order_no = ca.order_no and
       cm.PARTY_TYPE_DB = 'CUSTOMER' and
       cm.method_id_db = 'E_MAIL' and
       co.customer_no = cm.identity and
       cm.address_id is null and
       cm.cf$_amr_email_form_db like report_type_like_
    group by
      co.order_no,
      co.customer_no,
      ca.addr_1,
      co.salesman_code,
      co.customer_po_no,
      co.cf$_amr_main_rep;
       
     
     -- This cursor is for the following reports: Advance Invoice, Customer Invoice, and Collective Invoice
     CURSOR cust_ord_inv_cur(invoice_id_ NUMBER, report_type_like_ VARCHAR2) IS
     SELECT       
        ih.creators_reference           order_no,
        ih.our_reference                authorize_name,
        ih.identity                     customer_no_pay,
        ih.your_reference               cust_ref,
        ih.invoice_address_id           bill_addr_no,
        ih.series_id || ih.invoice_no   invoice_no,
        ih.invoice_date                 invoice_date,
        ih.invoice_type                 invoice_type,
        ih.name                         customer_name,
        -- cm.name as                      to_name,
        -- cm.value as                     to_email_address
        'Valued Customer' as to_name,
        listagg(cm.value,',') within GROUP (ORDER BY cm.VALUE) as to_email_address
     FROM   
        customer_order_inv_head ih,
        comm_method_cfv cm
     WHERE  
         ih.invoice_id = invoice_id_ and
         ih.identity = cm.identity and
         cm.PARTY_TYPE_DB = 'CUSTOMER' and
         cm.method_id_db = 'E_MAIL' and    
         cm.cf$_amr_email_form_db like report_type_like_
     GROUP BY
        ih.creators_reference,
        ih.our_reference,
        ih.identity,
        ih.your_reference,
        ih.invoice_address_id,
        ih.series_id || ih.invoice_no,
        ih.invoice_date,
        ih.invoice_type,
        ih.name;
         
         
     -- For instant invoice
     CURSOR instant_ivc_cur(invoice_id_ NUMBER, report_type_like_ VARCHAR2) IS
     SELECT 
          i.series_id || i.invoice_no as invoice_no,
          i.invoice_type,
          i.identity as customer_no,
          Customer_Info_Address_API.Get_Name (i.identity, i.invoice_address_id) as customer_name,
          i.invoice_address_id as bill_addr_no,
          i.C2 cust_reference,
          i.C3 order_no,
          -- cm.name as to_name,
          -- cm.value as to_email_address
          'Valued Customer' as to_name,
          listagg(cm.value,',') within GROUP (ORDER BY cm.VALUE) as to_email_address
     FROM   
          Invoice i,
          comm_method_cfv cm
     WHERE 
          i.invoice_id = invoice_id_ and
          i.identity = cm.identity and
          cm.PARTY_TYPE_DB = 'CUSTOMER' and
          cm.method_id_db = 'E_MAIL' and    
          cm.cf$_amr_email_form_db like report_type_like_
     GROUP BY
          i.series_id || i.invoice_no,
          i.invoice_type,
          i.identity,
          i.invoice_address_id,
          i.C2,
          i.C3;
 
     -- For quotations
     CURSOR quote_addr_cur(quotation_no_ IN VARCHAR2, report_type_like_ VARCHAR2) IS
     select
       oq.quotation_no,
       oq.cust_ref,
       oq.customer_no,
       Customer_Info_API.Get_Name(oq.customer_no) as customer_name,
       Customer_Info_Address_API.Get_Name(oq.customer_no, oq.ship_addr_no) as ship_address_name,
       oq.salesman_code,
       person_info_api.get_name(oq.salesman_code) as salesman_name,
       Fnd_User_API.Get_Property(oq.salesman_code, 'SMTP_MAIL_ADDRESS') as salesman_email,
       oq.ship_addr_no,
       oq.cust_ref_name,
       -- cm.name as to_name,
       -- cm.value as to_email_address
       'Valued Customer' as to_name,
       listagg(cm.value,',') within GROUP (ORDER BY cm.VALUE) as to_email_address
     from 
        order_quotation oq,
        comm_method_cfv cm
     where 
        oq.quotation_no = quotation_no_ and
        cm.PARTY_TYPE_DB = 'CUSTOMER' and
        cm.method_id_db = 'E_MAIL' and
        oq.customer_no = cm.identity and
        oq.ship_addr_no = cm.address_id and
        cm.cf$_amr_email_form_db like report_type_like_
     group by
        oq.quotation_no,
        oq.cust_ref,
        oq.customer_no,
        oq.ship_addr_no,
        oq.salesman_code,
        oq.cust_ref_name;
     
        
      CURSOR quote_no_addr_cur(quotation_no_ IN VARCHAR2, report_type_like_ VARCHAR2) IS
      select
         oq.quotation_no,
         oq.cust_ref,
         oq.customer_no,
         Customer_Info_API.Get_Name(oq.customer_no) as customer_name,
         Customer_Info_Address_API.Get_Name(oq.customer_no, oq.ship_addr_no) as ship_address_name,
         oq.salesman_code,
         person_info_api.get_name(oq.salesman_code) as salesman_name,
         Fnd_User_API.Get_Property(oq.salesman_code, 'SMTP_MAIL_ADDRESS') as salesman_email,
         oq.ship_addr_no,
         oq.cust_ref_name,
         -- cm.name as to_name,
         -- cm.value as to_email_address
         'Valued Customer' as to_name,
         listagg(cm.value,',') within GROUP (ORDER BY cm.VALUE) as to_email_address
      from 
         order_quotation oq,
         comm_method_cfv cm
      where 
         oq.quotation_no = quotation_no_ and
         cm.PARTY_TYPE_DB = 'CUSTOMER' and
         cm.method_id_db = 'E_MAIL' and
         oq.customer_no = cm.identity and
         cm.address_id is null and
         cm.cf$_amr_email_form_db like report_type_like_
      group by
        oq.quotation_no,
        oq.cust_ref,
        oq.customer_no,
        oq.ship_addr_no,
        oq.salesman_code,
        oq.cust_ref_name;
         
      -- For customer statement of accounts
      CURSOR cust_statement(customer_id_ VARCHAR2, report_type_like_ VARCHAR2) IS
      SELECT 
          cm.identity as customer_no,
          Customer_Info_API.Get_Name(cm.identity) as customer_name,
          -- cm.name as to_name,
          -- cm.value as to_email_address
          'Valued Customer' as to_name,
          listagg(cm.value,',') within GROUP (ORDER BY cm.VALUE) as to_email_address
      FROM   
          comm_method_cfv cm
      WHERE 
          cm.identity = customer_id_ and
          cm.PARTY_TYPE_DB = 'CUSTOMER' and
          cm.method_id_db = 'E_MAIL' and    
          cm.cf$_amr_email_form_db like report_type_like_
      GROUP BY cm.identity;
          
      -- For "normal" RMA reports
      CURSOR rma_cur(rma_no_ NUMBER, report_type_like_ VARCHAR2) IS
      select
          rm.rma_no,
          rm.customer_no,
          Customer_Info_API.Get_Name(rm.customer_no) as customer_name,
          rm.customer_no_addr_no as document_address,
          rm.ship_addr_no as delivery_address,
          Customer_Info_Address_API.Get_Name(rm.customer_no, rm.ship_addr_no) as ship_address_name,
          rm.order_no,
          Cust_Ord_Customer_API.Get_Salesman_Code(rm.customer_no) as salesman_code,
          Person_info_api.get_name(Cust_Ord_Customer_API.Get_Salesman_Code(rm.customer_no)) as salesman_name,
          Fnd_User_API.Get_Property(Cust_Ord_Customer_API.Get_Salesman_Code(rm.customer_no), 'SMTP_MAIL_ADDRESS') as salesman_email,
          -- cm.name as to_name,
          -- cm.value as to_email_address
          'Valued Customer' as to_name,
          listagg(cm.value,',') within GROUP (ORDER BY cm.VALUE) as to_email_address
       from
          return_material rm,
          comm_method_cfv cm
       where 
          rm.rma_no = rma_no_ and
          cm.PARTY_TYPE_DB = 'CUSTOMER' and
          cm.method_id_db = 'E_MAIL' and
          rm.customer_no = cm.identity and
          rm.ship_addr_no = cm.address_id and
          cm.cf$_amr_email_form_db like report_type_like_
       group by
          rm.rma_no,
          rm.customer_no,
          rm.customer_no_addr_no,
          rm.ship_addr_no,
          rm.order_no;
       
       -- For "work order" RMA reports
       CURSOR wo_rma_cur(wo_no_ NUMBER, report_type_like_ VARCHAR2) IS
       select
          wo.wo_no as rma_no,
          wo.customer_no,
          customer_info_api.get_name(wo.customer_no) as customer_name,
          Customer_Info_Address_Type_API.Get_Default_Address_Id(wo.customer_no, 'DELIVERY') as delivery_address,
          Cust_Ord_Customer_Address_API.get_name(wo.customer_no, Customer_Info_Address_Type_API.Get_Default_Address_Id(wo.customer_no, 'DELIVERY')) as ship_address_name,
          coc.salesman_code,
          person_info_api.get_name(coc.salesman_code) as salesman_name,
          Fnd_User_API.Get_Property(coc.salesman_code, 'SMTP_MAIL_ADDRESS') as salesman_email,
          -- cm.name as to_name,
          -- cm.value as to_email_address
          'Valued Customer' as to_name,
          listagg(cm.value,',') within GROUP (ORDER BY cm.VALUE) as to_email_address
       from
          active_separate wo,
          cust_ord_customer coc,
          comm_method_cfv cm
       where
             wo.customer_no = coc.customer_no and
             cm.PARTY_TYPE_DB = 'CUSTOMER' and
             cm.method_id_db = 'E_MAIL' and
             wo.customer_no = cm.identity and
             Customer_Info_Address_Type_API.Get_Default_Address_Id(wo.customer_no, 'DELIVERY') = cm.address_id and
             cm.cf$_amr_email_form_db like report_type_like_ and
             wo.wo_no = wo_no_
       group by
          wo.wo_no,
          wo.customer_no,
          coc.salesman_code;
     
     -- For Purchase Order report and supplier goods returned reports
     CURSOR po_cur(order_no_ VARCHAR2) IS
     SELECT 
       po.vendor_no,
       Supplier_API.Get_Vendor_Name(po.vendor_no) vendor_name,
       po.order_no,
       po.revision,
       doc_addr_no,
       po.buyer_code,
       person_info_api.get_name(po.buyer_code) as buyer_name,
       Fnd_User_API.Get_Property(po.buyer_code, 'SMTP_MAIL_ADDRESS') as buyer_email,
       -- cm.name as to_name,
       -- cm.value as to_email_address
       'Valued Supplier' as to_name,
       listagg(cm.value,',') within GROUP (ORDER BY cm.VALUE) as to_email_address
     FROM   
       purchase_order_tab po,
       comm_method_cfv cm
     WHERE  
       po.order_no = order_no_ and
       cm.PARTY_TYPE_DB = 'SUPPLIER' and
       cm.method_id_db = 'E_MAIL' and
       po.vendor_no = cm.identity and
       po.doc_addr_no = cm.address_id
    GROUP BY
       po.vendor_no,
       po.order_no,
       po.revision,
       doc_addr_no,
       po.buyer_code;
    
    -- Get Documents to send with PO report
    CURSOR po_docs(order_no_ VARCHAR2) IS
    SELECT DISTINCT
      doc_no,
      doc_rev,
      file_name,
      doc_title,
      remote_file_name
    FROM IFSINFO.AMR_EMAIL_PO_DOCS_SEND
    WHERE order_no = order_no_;

  
BEGIN
  
  IF (Event_SYS.Event_Enabled(event_lu_, event_id_)) THEN
  
     -- Set the report type format
     report_type_like_ := '%^' || report_type_ || '^%';
  
     IF (report_id_ = 'CUSTOMER_ORDER_CONF_REP') THEN
       
         IF (Transaction_SYS.Is_Session_Deferred) THEN
            Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Check emails for report id ' || report_id_, 'INFO');
         END IF;
    
          -- str_key1 = ORDER_NO report parameter
         str_key1 := archive_parameter_api.get_parameter_value(result_key_, 'ORDER_NO');
   
          FOR rec_ IN ord_addr_mail_cur(str_key1, report_type_like_) LOOP
               msg_          := '';
               
               -- AHDBRPEUS, 20180118, START
               -- Add the salesman and sales rep rep emails to send with the customer comm methods
               IF (rec_.salesman_email = rec_.sales_rep_email) THEN
                 to_email_ := rec_.to_email_address || ',' || rec_.salesman_email;
               ELSE
                 to_email_ := rec_.to_email_address;
               
                 IF (rec_.salesman_email IS NOT NULL) THEN
                   to_email_ := to_email_ || ',' || rec_.salesman_email;
                 END IF;
                 
                 IF (rec_.sales_rep_email IS NOT NULL) THEN
                   to_email_ := to_email_ || ',' || rec_.sales_rep_email;
                 END IF;
                 
               END IF;
               -- AHDBRPEUS, 20180118, END
    
               msg_ := Message_SYS.Construct(event_id_);
               Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         pdf_file_);
               Message_SYS.Add_Attribute(msg_, 'FROM_EMAIL_ADDRESS', rec_.salesman_email);
               Message_SYS.Add_Attribute(msg_, 'FROM_NAME',          rec_.salesman_name);
               Message_SYS.Add_Attribute(msg_, 'FROM_USERID',        rec_.salesman_code);
               Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       '');
               Message_SYS.Add_Attribute(msg_, 'REPORT_ID',          report_id_);
               Message_SYS.Add_Attribute(msg_, 'SUBJECT',            '');
               -- Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   rec_.to_email_address);
               Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   to_email_); -- AHDBRPEUS, 20180118
               Message_SYS.Add_Attribute(msg_, 'TO_NAME',            rec_.to_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_1',              rec_.order_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_2',              rec_.customer_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_3',              rec_.customer_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_4',              rec_.ship_address_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_5',              rec_.customer_po_no);
               
               -- Send email using event = AMR_SEND_EMAIL
               Event_SYS.Event_Execute(event_lu_, event_id_, msg_); 
               
               IF (Transaction_SYS.Is_Session_Deferred) THEN
                  Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Email sent to ' || rec_.to_email_address || ' for order ' || rec_.order_no, 'INFO');
               END IF;
               
               rec_count_ := rec_count_ + 1;
               
          END LOOP;
                    
          -- If no records connected to address id, then get records where no address id assigned
          IF rec_count_ = 0 THEN
            
            FOR rec_ IN ord_mail_cur(str_key1, report_type_like_) LOOP
               msg_          := '';
               
               -- AHDBRPEUS, 20180118, START
               -- Add the salesman and sales rep rep emails to send with the customer comm methods
               IF (rec_.salesman_email = rec_.sales_rep_email) THEN
                 to_email_ := rec_.to_email_address || ',' || rec_.salesman_email;
               ELSE
                 to_email_ := rec_.to_email_address;
               
                 IF (rec_.salesman_email IS NOT NULL) THEN
                   to_email_ := to_email_ || ',' || rec_.salesman_email;
                 END IF;
                 
                 IF (rec_.sales_rep_email IS NOT NULL) THEN
                   to_email_ := to_email_ || ',' || rec_.sales_rep_email;
                 END IF;
                 
               END IF;
               -- AHDBRPEUS, 20180118, END
    
               msg_ := Message_SYS.Construct(event_id_);
               Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         pdf_file_);
               Message_SYS.Add_Attribute(msg_, 'FROM_EMAIL_ADDRESS', rec_.salesman_email);
               Message_SYS.Add_Attribute(msg_, 'FROM_NAME',          rec_.salesman_name);
               Message_SYS.Add_Attribute(msg_, 'FROM_USERID',        rec_.salesman_code);
               Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       '');
               Message_SYS.Add_Attribute(msg_, 'REPORT_ID',          report_id_);
               Message_SYS.Add_Attribute(msg_, 'SUBJECT',            '');
               -- Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   rec_.to_email_address);
               Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   to_email_); -- AHDBRPEUS, 20180118
               Message_SYS.Add_Attribute(msg_, 'TO_NAME',            rec_.to_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_1',              rec_.order_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_2',              rec_.customer_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_3',              rec_.customer_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_4',              rec_.ship_address_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_5',              rec_.customer_po_no);
               
               -- Send email using event = AMR_SEND_EMAIL
               Event_SYS.Event_Execute(event_lu_, event_id_, msg_); 
               
               IF (Transaction_SYS.Is_Session_Deferred) THEN
                  Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Email sent to ' || rec_.to_email_address || ' for order ' || rec_.order_no, 'INFO');
               END IF;
               
            END LOOP;
            
          END IF;
       
     ELSIF (report_id_ IN ('CUSTOMER_ORDER_ADV_IVC_REP','CUSTOMER_ORDER_IVC_REP','CUSTOMER_ORDER_COLL_IVC_REP')) THEN
       
         IF (Transaction_SYS.Is_Session_Deferred) THEN
            Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Check emails for report id ' || report_id_, 'INFO');
         END IF;
    
          -- num_key1 = INVOICE_ID report parameter
         num_key1 := TO_NUMBER(archive_parameter_api.get_parameter_value(result_key_, 'INVOICE_ID'));
         
         from_name_  := airm1app.person_info_api.get_name(printed_by_);
         from_email_ := airm1app.Fnd_User_API.Get_Property(printed_by_, 'SMTP_MAIL_ADDRESS');
         
         FOR rec_ IN cust_ord_inv_cur(num_key1, report_type_like_) LOOP
               msg_          := '';
    
               msg_ := Message_SYS.Construct(event_id_);
               Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         pdf_file_);
               Message_SYS.Add_Attribute(msg_, 'FROM_EMAIL_ADDRESS', from_email_);
               Message_SYS.Add_Attribute(msg_, 'FROM_NAME',          from_name_);
               Message_SYS.Add_Attribute(msg_, 'FROM_USERID',        printed_by_);
               Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       '');
               Message_SYS.Add_Attribute(msg_, 'REPORT_ID',          report_id_);
               Message_SYS.Add_Attribute(msg_, 'SUBJECT',            '');
               Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   rec_.to_email_address);
               Message_SYS.Add_Attribute(msg_, 'TO_NAME',            rec_.to_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_1',              rec_.order_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_2',              rec_.authorize_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_3',              rec_.customer_no_pay);
               Message_SYS.Add_Attribute(msg_, 'KEY_4',              rec_.invoice_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_5',              rec_.customer_name);
              
               
               -- Send email using event = AMR_SEND_EMAIL
               Event_SYS.Event_Execute(event_lu_, event_id_, msg_); 
               
               IF (Transaction_SYS.Is_Session_Deferred) THEN
                  Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Email sent to ' || rec_.to_email_address || ' for invoice ' || rec_.invoice_no, 'INFO');
               END IF;
               
         END LOOP;
     
     ELSIF (report_id_ = 'INSTANT_INVOICE_REP') THEN
       
         IF (Transaction_SYS.Is_Session_Deferred) THEN
            Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Check emails for report id ' || report_id_, 'INFO');
         END IF;
    
          -- num_key1 = INVOICE_ID report parameter
         num_key1 := TO_NUMBER(archive_parameter_api.get_parameter_value(result_key_, 'INVOICE_ID'));
         
         from_name_  := airm1app.person_info_api.get_name(printed_by_);
         from_email_ := airm1app.Fnd_User_API.Get_Property(printed_by_, 'SMTP_MAIL_ADDRESS');
         
         FOR rec_ IN instant_ivc_cur(num_key1, report_type_like_) LOOP
               msg_          := '';
    
               msg_ := Message_SYS.Construct(event_id_);
               Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         pdf_file_);
               Message_SYS.Add_Attribute(msg_, 'FROM_EMAIL_ADDRESS', from_email_);
               Message_SYS.Add_Attribute(msg_, 'FROM_NAME',          from_name_);
               Message_SYS.Add_Attribute(msg_, 'FROM_USERID',        printed_by_);
               Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       '');
               Message_SYS.Add_Attribute(msg_, 'REPORT_ID',          report_id_);
               Message_SYS.Add_Attribute(msg_, 'SUBJECT',            '');
               Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   rec_.to_email_address);
               Message_SYS.Add_Attribute(msg_, 'TO_NAME',            rec_.to_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_1',              rec_.order_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_2',              rec_.customer_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_3',              rec_.invoice_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_4',              rec_.customer_name);
              
               
               -- Send email using event = AMR_SEND_EMAIL
               Event_SYS.Event_Execute(event_lu_, event_id_, msg_); 
               
               IF (Transaction_SYS.Is_Session_Deferred) THEN
                  Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Email sent to ' || rec_.to_email_address || ' for invoice ' || rec_.invoice_no, 'INFO');
               END IF;
               
         END LOOP;
     
     ELSIF (report_id_ = 'ORDER_QUOTATION_REP') THEN
     
         IF (Transaction_SYS.Is_Session_Deferred) THEN
            Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Check emails for report id ' || report_id_, 'INFO');
         END IF;
    
          -- str_key1 = QUOTATION_NO report parameter
         str_key1 := archive_parameter_api.get_parameter_value(result_key_, 'QUOTATION_NO');
   
          FOR rec_ IN quote_addr_cur(str_key1, report_type_like_) LOOP
               msg_          := '';
    
               msg_ := Message_SYS.Construct(event_id_);
               Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         pdf_file_);
               Message_SYS.Add_Attribute(msg_, 'FROM_EMAIL_ADDRESS', rec_.salesman_email);
               Message_SYS.Add_Attribute(msg_, 'FROM_NAME',          rec_.salesman_name);
               Message_SYS.Add_Attribute(msg_, 'FROM_USERID',        rec_.salesman_code);
               Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       '');
               Message_SYS.Add_Attribute(msg_, 'REPORT_ID',          report_id_);
               Message_SYS.Add_Attribute(msg_, 'SUBJECT',            '');
               Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   rec_.to_email_address);
               Message_SYS.Add_Attribute(msg_, 'TO_NAME',            rec_.to_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_1',              rec_.quotation_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_2',              rec_.customer_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_3',              rec_.customer_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_4',              rec_.ship_address_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_5',              rec_.customer_name);
               
               -- Send email using event = AMR_SEND_EMAIL
               Event_SYS.Event_Execute(event_lu_, event_id_, msg_); 
               
               IF (Transaction_SYS.Is_Session_Deferred) THEN
                  Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Email sent to ' || rec_.to_email_address || ' for quotation ' || rec_.quotation_no, 'INFO');
               END IF;
               
               rec_count_ := rec_count_ + 1;
               
          END LOOP;
                    
          -- If no records connected to address id, then get records where no address id assigned
          IF rec_count_ = 0 THEN
            
            FOR rec_ IN quote_no_addr_cur(str_key1, report_type_like_) LOOP
               msg_ := '';
    
               msg_ := Message_SYS.Construct(event_id_);
               Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         pdf_file_);
               Message_SYS.Add_Attribute(msg_, 'FROM_EMAIL_ADDRESS', rec_.salesman_email);
               Message_SYS.Add_Attribute(msg_, 'FROM_NAME',          rec_.salesman_name);
               Message_SYS.Add_Attribute(msg_, 'FROM_USERID',        rec_.salesman_code);
               Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       '');
               Message_SYS.Add_Attribute(msg_, 'REPORT_ID',          report_id_);
               Message_SYS.Add_Attribute(msg_, 'SUBJECT',            '');
               Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   rec_.to_email_address);
               Message_SYS.Add_Attribute(msg_, 'TO_NAME',            rec_.to_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_1',              rec_.quotation_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_2',              rec_.customer_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_3',              rec_.customer_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_4',              rec_.ship_address_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_5',              rec_.customer_name);
               
               -- Send email using event = AMR_SEND_EMAIL
               Event_SYS.Event_Execute(event_lu_, event_id_, msg_); 
               
               IF (Transaction_SYS.Is_Session_Deferred) THEN
                  Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Email sent to ' || rec_.to_email_address || ' for order ' || rec_.quotation_no, 'INFO');
               END IF;
               
            END LOOP;
            
          END IF;
          
     ELSIF (report_id_ = 'CUST_STMT_ACCT_REP') THEN
       
         IF (Transaction_SYS.Is_Session_Deferred) THEN
            Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Check emails for report id ' || report_id_, 'INFO');
         END IF;
    
          -- num_key1 = CUSTOMER_ID report parameter
         str_key1 := archive_parameter_api.get_parameter_value(result_key_, 'CUSTOMER_ID');
         
         from_name_  := airm1app.person_info_api.get_name(printed_by_);
         from_email_ := airm1app.Fnd_User_API.Get_Property(printed_by_, 'SMTP_MAIL_ADDRESS');
         
         FOR rec_ IN cust_statement(str_key1, report_type_like_) LOOP
               msg_          := '';
    
               msg_ := Message_SYS.Construct(event_id_);
               Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         pdf_file_);
               Message_SYS.Add_Attribute(msg_, 'FROM_EMAIL_ADDRESS', from_email_);
               Message_SYS.Add_Attribute(msg_, 'FROM_NAME',          from_name_);
               Message_SYS.Add_Attribute(msg_, 'FROM_USERID',        printed_by_);
               Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       '');
               Message_SYS.Add_Attribute(msg_, 'REPORT_ID',          report_id_);
               Message_SYS.Add_Attribute(msg_, 'SUBJECT',            '');
               Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   rec_.to_email_address);
               Message_SYS.Add_Attribute(msg_, 'TO_NAME',            rec_.to_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_1',              rec_.customer_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_2',              rec_.customer_name);
              
               
               -- Send email using event = AMR_SEND_EMAIL
               Event_SYS.Event_Execute(event_lu_, event_id_, msg_); 
               
               IF (Transaction_SYS.Is_Session_Deferred) THEN
                  Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Statemen of Account email sent to ' || rec_.to_email_address || ' for customer ' || rec_.customer_no, 'INFO');
               END IF;
               
         END LOOP;        
         
     ELSIF (report_id_ = 'RETURN_MATERIAL_REP') THEN
     
         IF (Transaction_SYS.Is_Session_Deferred) THEN
            Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Check emails for report id ' || report_id_, 'INFO');
         END IF;
    
          -- num_key1 = RMA_NO report parameter
          num_key1 := TO_NUMBER(archive_parameter_api.get_parameter_value(result_key_, 'RMA_NO'));
   
          FOR rec_ IN rma_cur(num_key1, report_type_like_) LOOP
               msg_          := '';
    
               msg_ := Message_SYS.Construct(event_id_);
               Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         pdf_file_);
               Message_SYS.Add_Attribute(msg_, 'FROM_EMAIL_ADDRESS', rec_.salesman_email);
               Message_SYS.Add_Attribute(msg_, 'FROM_NAME',          rec_.salesman_name);
               Message_SYS.Add_Attribute(msg_, 'FROM_USERID',        rec_.salesman_code);
               Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       '');
               Message_SYS.Add_Attribute(msg_, 'REPORT_ID',          report_id_);
               Message_SYS.Add_Attribute(msg_, 'SUBJECT',            '');
               Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   rec_.to_email_address);
               Message_SYS.Add_Attribute(msg_, 'TO_NAME',            rec_.to_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_1',              rec_.rma_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_2',              rec_.customer_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_3',              rec_.customer_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_4',              rec_.ship_address_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_5',              rec_.order_no);
               
               -- Send email using event = AMR_SEND_EMAIL
               Event_SYS.Event_Execute(event_lu_, event_id_, msg_); 
               
               IF (Transaction_SYS.Is_Session_Deferred) THEN
                  Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Email sent to ' || rec_.to_email_address || ' for RMA ' || to_char(rec_.rma_no), 'INFO');
               END IF;
               
               rec_count_ := rec_count_ + 1;
               
          END LOOP;
     
      -- For Work Order RMA (this is a custom report id)
      ELSIF (report_id_ = 'AMR_ACTIVE_SEP_WO_RMA_REP') THEN
     
         IF (Transaction_SYS.Is_Session_Deferred) THEN
            Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Check emails for report id ' || report_id_, 'INFO');
         END IF;
    
          -- num_key1 = RMA_NO report parameter
          num_key1 := TO_NUMBER(archive_parameter_api.get_parameter_value(result_key_, 'WO_NO'));
   
          FOR rec_ IN wo_rma_cur(num_key1, report_type_like_) LOOP
               msg_          := '';
    
               msg_ := Message_SYS.Construct(event_id_);
               Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         pdf_file_);
               Message_SYS.Add_Attribute(msg_, 'FROM_EMAIL_ADDRESS', rec_.salesman_email);
               Message_SYS.Add_Attribute(msg_, 'FROM_NAME',          rec_.salesman_name);
               Message_SYS.Add_Attribute(msg_, 'FROM_USERID',        rec_.salesman_code);
               Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       '');
               Message_SYS.Add_Attribute(msg_, 'REPORT_ID',          report_id_);
               Message_SYS.Add_Attribute(msg_, 'SUBJECT',            '');
               Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   rec_.to_email_address);
               Message_SYS.Add_Attribute(msg_, 'TO_NAME',            rec_.to_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_1',              rec_.rma_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_2',              rec_.customer_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_3',              rec_.customer_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_4',              rec_.ship_address_name);
               
               -- Send email using event = AMR_SEND_EMAIL
               Event_SYS.Event_Execute(event_lu_, event_id_, msg_); 
               
               IF (Transaction_SYS.Is_Session_Deferred) THEN
                  Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Email sent to ' || rec_.to_email_address || ' for RMA ' || to_char(rec_.rma_no), 'INFO');
               END IF;
               
               rec_count_ := rec_count_ + 1;
               
          END LOOP;
         
     -- For purchase order report
     ELSIF (report_id_ = 'PURCHASE_ORDER_PRINT_REP') THEN
     
         IF (Transaction_SYS.Is_Session_Deferred) THEN
            Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Check emails for report id ' || report_id_, 'INFO');
         END IF;
    
          -- str_key1 = ORDER_NO_LIST report parameter, which will only be a single PO no
          str_key1 := archive_parameter_api.get_parameter_value(result_key_, 'ORDER_NO_LIST');
   
          FOR rec_ IN po_cur(str_key1) LOOP
               msg_          := '';
               message_body_ := '';
               po_attach_    := pdf_file_;
               
               -- initialize message body
               message_body_ := '<p>Dear ' || rec_.to_name || ',</p>';
               message_body_ := message_body_ || '<p>Attached is purchase order ' || rec_.order_no || ' revision ' || rec_.revision || '.</p>';
               message_body_ := message_body_ || '<p>Additional supporting files:</p>';
               message_body_ := message_body_ || '<table style="width: 800px;">';
               message_body_ := message_body_ || '<tbody>';
               message_body_ := message_body_ || '<tr>';
               message_body_ := message_body_ || '<td style="width: 300px;">File</td>';
               message_body_ := message_body_ || '<td style="width: 500px;">Document Title</td>';
               message_body_ := message_body_ || '</tr>';
               -- message_body_ := message_body_ || '';

               
               
               ----------------------------------
               -- bpelz, 20190408, start, build the message body and the attachment list
               FOR doc_rec_ IN po_docs(str_key1) LOOP
                 message_body_ := message_body_ || '<tr>';
                 message_body_ := message_body_ || '<td style="width: 300px;">' || doc_rec_.file_name || '</td>';
                 message_body_ := message_body_ || '<td style="width: 500px;">' || doc_rec_.doc_title ||'</td>';
                 message_body_ := message_body_ || '</tr>';
                 
                 po_attach_ := po_attach_ || ',' || doc_rec_.remote_file_name; -- attach the documents
                 
               END LOOP;
               
               -- finalize body
               message_body_ := message_body_ || '</tbody>';
               message_body_ := message_body_ || '</table>';
               message_body_ := message_body_ || '<p>Thank You,<br />' || rec_.buyer_name ||'</p>';
               
               
               -- bpelz, 20190408, end
               ----------------------------------
               
    
               msg_ := Message_SYS.Construct(event_id_);
               -- Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         pdf_file_);
               Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         po_attach_); -- bpelz, 20190408
               Message_SYS.Add_Attribute(msg_, 'FROM_EMAIL_ADDRESS', rec_.buyer_email);
               Message_SYS.Add_Attribute(msg_, 'FROM_NAME',          rec_.buyer_name);
               Message_SYS.Add_Attribute(msg_, 'FROM_USERID',        rec_.buyer_code);
               -- Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       '');
               Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       message_body_);
               Message_SYS.Add_Attribute(msg_, 'REPORT_ID',          report_id_);
               Message_SYS.Add_Attribute(msg_, 'SUBJECT',            '');
               Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   rec_.to_email_address);
               Message_SYS.Add_Attribute(msg_, 'TO_NAME',            rec_.to_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_1',              rec_.order_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_2',              rec_.revision);
               Message_SYS.Add_Attribute(msg_, 'KEY_3',              rec_.vendor_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_4',              rec_.vendor_name);
               
               -- Send email using event = AMR_SEND_EMAIL
               Event_SYS.Event_Execute(event_lu_, event_id_, msg_); 
               
               IF (Transaction_SYS.Is_Session_Deferred) THEN
                  Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Email sent to ' || rec_.to_email_address || ' for purchase order ' || to_char(rec_.order_no), 'INFO');
               END IF;
               
               rec_count_ := rec_count_ + 1;
               
          END LOOP;
     
     -- For supplier goods returned report
     ELSIF (report_id_ = 'PURCHASE_RECEIPT_RETURN_REP') THEN
     
         IF (Transaction_SYS.Is_Session_Deferred) THEN
            Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Check emails for report id ' || report_id_, 'INFO');
         END IF;
    
          
          str_key1 := archive_parameter_api.get_parameter_value(result_key_, 'ORDER_NO');
          str_key2 := archive_parameter_api.get_parameter_value(result_key_, 'LINE_NO');
          str_key3 := archive_parameter_api.get_parameter_value(result_key_, 'RELEASE_NO');
          num_key1 := TO_NUMBER(archive_parameter_api.get_parameter_value(result_key_, 'RECEIPT_NO'));
   
          FOR rec_ IN po_cur(str_key1) LOOP
               msg_          := '';
    
               msg_ := Message_SYS.Construct(event_id_);
               Message_SYS.Add_Attribute(msg_, 'ATTACHMENT',         pdf_file_);
               Message_SYS.Add_Attribute(msg_, 'FROM_EMAIL_ADDRESS', rec_.buyer_email);
               Message_SYS.Add_Attribute(msg_, 'FROM_NAME',          rec_.buyer_name);
               Message_SYS.Add_Attribute(msg_, 'FROM_USERID',        rec_.buyer_code);
               Message_SYS.Add_Attribute(msg_, 'MESSAGE_BODY',       '');
               Message_SYS.Add_Attribute(msg_, 'REPORT_ID',          report_id_);
               Message_SYS.Add_Attribute(msg_, 'SUBJECT',            '');
               Message_SYS.Add_Attribute(msg_, 'TO_EMAIL_ADDRESS',   rec_.to_email_address);
               Message_SYS.Add_Attribute(msg_, 'TO_NAME',            rec_.to_name);
               Message_SYS.Add_Attribute(msg_, 'KEY_1',              rec_.order_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_2',              str_key2); -- line_no
               Message_SYS.Add_Attribute(msg_, 'KEY_3',              str_key3); -- release_no
               Message_SYS.Add_Attribute(msg_, 'KEY_4',              num_key1); -- receipt_no
               Message_SYS.Add_Attribute(msg_, 'KEY_5',              rec_.vendor_no);
               Message_SYS.Add_Attribute(msg_, 'KEY_6',              rec_.vendor_name);
               
               -- Send email using event = AMR_SEND_EMAIL
               Event_SYS.Event_Execute(event_lu_, event_id_, msg_); 
               
               IF (Transaction_SYS.Is_Session_Deferred) THEN
                  Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Email sent to ' || rec_.to_email_address || ' for supplier goods returned for order ' || to_char(rec_.order_no), 'INFO');
               END IF;
               
               rec_count_ := rec_count_ + 1;
               
          END LOOP;
     
     
     ELSE
        NULL;
     END IF;

  END IF;
  
END Email_Report_;


PROCEDURE Reprint_Report_ (
  language_code_    IN VARCHAR2,
  report_id_        IN VARCHAR2,
  printed_by_       IN VARCHAR2,
  report_type_      IN VARCHAR2,
  result_key_       IN NUMBER)
IS

   report_attr_        varchar2(2000);
   --parameter_attr_     VARCHAR2(2000);
   print_job_id_       NUMBER;
   printer_id_list_    VARCHAR2(32767);
   print_hardcopy_     BOOLEAN;
   printer_id_         VARCHAR2(500);

 BEGIN

  -- Determine if a hard copy needs to be printed
  print_hardcopy_ := Printed_Forms_Flag_Exist_( result_key_, report_id_, report_type_);
  
  IF (print_hardcopy_ = TRUE) THEN
     -- Get default printer for user that just printed the report
     printer_id_ := printer_connection_api.get_default_printer(printed_by_, report_id_);

    -- Create a new print job
    airm1app.Client_SYS.Add_To_Attr('PRINTER_ID', printer_id_, report_attr_);
    airm1app.Print_Job_API.New(print_job_id_, report_attr_);
    
    
    /*** This is commented out since we are not going to create a new archive file
         We will use the one just created
         
    Clear report_attr_ and add the report id
    ifsapp.Client_SYS.Clear_Attr(report_attr_);
    ifsapp.Client_SYS.Add_To_Attr('REPORT_ID', report_id_, report_attr_);

    -- Add the report parameters and create a new archive record
    ifsapp.Client_SYS.Clear_Attr(parameter_attr_);
    ifsapp.Client_SYS.Add_To_Attr('SHIPMENT_ID', shipment_id_, parameter_attr_);
    ifsapp.Archive_API.New_Instance(result_key_, report_attr_, parameter_attr_);

    ***/

    -- Add the report to the print job
    airm1app.Client_SYS.Clear_Attr(report_attr_);
    airm1app.Client_SYS.Add_To_Attr('PRINT_JOB_ID', print_job_id_, report_attr_);
    airm1app.Client_SYS.Add_To_Attr('RESULT_KEY', result_key_, report_attr_);
    airm1app.Client_SYS.Add_To_Attr('LANG_CODE', language_code_,   report_attr_);
    
    airm1app.Print_Job_Contents_API.New_Instance(report_attr_);
    airm1app.Logical_Printer_API.Enumerate_Printer_Id(printer_id_list_);

    IF (printer_id_list_ IS NOT NULL) THEN
       IF (print_job_id_ IS NOT NULL) THEN
          airm1app.Print_Job_API.Print(print_job_id_);
       END IF;
    END IF;

  END IF;
  
END Reprint_Report_;

-- Private Methods, end
-----------------------------------------------


PROCEDURE Reprint_Send_Report (
  param_attr_ IN VARCHAR2)
IS

  -- For parameters passed to method
  language_code_    VARCHAR2(10);
  report_id_        VARCHAR2(100);
  printed_by_       VARCHAR2(100);
  report_type_      VARCHAR2(20);
  result_key_       NUMBER;
  pdf_file_         VARCHAR2(500);
  pdf_file_name_    VARCHAR2(500);

BEGIN
  General_SYS.Init_Method('AmrEventNotification', 'AMR_EVENT_NOTIFICATION_API', 'Reprint_Send_Report');  


  -- Get the parameters
  language_code_    := Client_SYS.Get_Item_Value('LANGUAGE_CODE', param_attr_);
  report_id_        := Client_SYS.Get_Item_Value('REPORT_ID', param_attr_);
  printed_by_       := Client_SYS.Get_Item_Value('USER_IDENTITY', param_attr_);
  report_type_      := Client_SYS.Get_Item_Value('REPORT_TYPE', param_attr_);
  result_key_       := Client_SYS.Get_Item_Value('RESULT_KEY', param_attr_);
  pdf_file_         := Client_SYS.Get_Item_Value('PDF_FILE', param_attr_);
  pdf_file_name_    := Client_SYS.Get_Item_Value('PDF_FILE_NAME', param_attr_);
  
  IF (Transaction_SYS.Is_Session_Deferred) THEN
    Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Impersonate User ' || printed_by_, 'INFO');
  END IF;
  
  -- Start impersonation 
  -- Fnd_Session_Util_API.Impersonate_Fnd_User_(Fnd_Session_API.Get_App_Owner);
  Fnd_Session_Util_API.Impersonate_Fnd_User_(printed_by_);
  
  IF (Transaction_SYS.Is_Session_Deferred) THEN
    Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Reprint report for result key ' || to_char(result_key_), 'INFO');
  END IF;
  
  -- Reprint Report to user's default printer
  Reprint_Report_(language_code_, report_id_, printed_by_,report_type_,result_key_);
  
  IF (Transaction_SYS.Is_Session_Deferred) THEN
    Transaction_SYS.Set_Status_Info(to_char(sysdate, 'MM/DD/YYYY HH24:MI:SS') || ': Email report for result key ' || to_char(result_key_), 'INFO');
  END IF;
  
  -- Email report
  Email_Report_(result_key_, report_id_, report_type_, pdf_file_, printed_by_);
  
  -- End impersonation
  Fnd_Session_Util_API.Reset_Fnd_User_;
  
END;

-- Function returns TRUE if method = Amr_Event_Notification_API.Reprint_Send_Report
-- has send the passed in result_key
-- otherwise it returns FALSE
FUNCTION Check_Result_Key_Sent (
  result_key_     IN NUMBER) RETURN VARCHAR2
IS
  dummy_ NUMBER;
BEGIN
   SELECT 1
   INTO  dummy_
   FROM deferred_job
   WHERE procedure_name = 'Amr_Event_Notification_API.Reprint_Send_Report'
   AND client_sys.get_item_value('RESULT_KEY',arguments_string) = result_key_;
   RETURN 'TRUE';
   EXCEPTION
      WHEN no_data_found THEN
         RETURN 'FALSE';
      WHEN too_many_rows THEN
         RETURN 'TRUE';
END Check_Result_Key_Sent;

-- 20190118, start
FUNCTION Get_Sales_Rep_Email_ (
  user_name_    IN VARCHAR2) RETURN VARCHAR2
IS
  email_address_  VARCHAR2(100);
  
BEGIN
  
  SELECT max(fup.value) INTO email_address_
  FROM Fnd_User fu, Fnd_User_Property fup
  WHERE
      fu.identity = fup.identity
  and fup.name = 'SMTP_MAIL_ADDRESS'
  and fu.description = user_name_;
  
  return(email_address_);
  
END Get_Sales_Rep_Email_;
-- 20190118, end

end AMR_EVENT_NOTIFICATION_API;
/
