select
  vendor_name,
  vendor_number,
  :p_as_on_date as_on_date,
  NVL(sum(amt_due_remaining), 0) Total,
  NVL(sum(current_Month), 0) current_Month,
  NVL(sum(Month_1), 0) Month_1,
  NVL(sum(Month_2), 0) Month_2,
  NVL(sum(Month_3), 0) Month_3,
  NVL(sum(Month_abve_3), 0) Month_abve_3
from
  (
    SELECT
      vendor_name,
      vendor_number,
      amt_due_remaining,
      CASE
        WHEN past_due_days <= 30 THEN amt_due_remaining
        ELSE NULL
      END current_Month,
      CASE
        WHEN past_due_days > 30
        AND past_due_days <= 60 THEN amt_due_remaining
        ELSE NULL
      END Month_1,
      CASE
        WHEN past_due_days > 60
        AND past_due_days <= 90 THEN amt_due_remaining
        ELSE NULL
      END Month_2,
      CASE
        WHEN past_due_days > 90
        AND past_due_days <= 120 THEN amt_due_remaining
        ELSE NULL
      END Month_3,
      CASE
        WHEN past_due_days > 120 THEN amt_due_remaining
        ELSE NULL
      END Month_abve_3
    FROM
      (SELECT  pv.vendor_name vendor_name
               ,  pv.segment1 vendor_number
               ,  i.invoice_num invoice_number
               ,  i.payment_status_flag
               ,  i.invoice_type_lookup_code invoice_type
               ,  i.invoice_date invoice_date
               ,  i.gl_date gl_date
               ,  ps.due_date due_date
               ,  CEIL (TO_DATE (TO_CHAR (:p_as_on_date, 'DD-MON-RRRR'), 'DD-MON-RRRR') - i.invoice_date) past_due_days
               ---,  NVL (aida.invoice_amount, i.invoice_amount) + NVL (aipa.invoice_amt_paid, 0) amt_due_remaining
               ,(nvl(atb.accounted_dr,0)- nvl(atb.accounted_cr,0) ) *(-1) amt_due_remaining
               ,  term.name payment_terms
             
            FROM  ap_payment_schedules_all ps
               ,  ap_invoices_all i
               ,  poz_suppliers_v  pv
               ,  ap_lookup_codes alc1
               ,  ap_terms_val_v term
               ,ap_trial_balances  atb
              /* ,  (  SELECT SUM (p.amount + NVL (p.discount_taken, 0)) invoice_amt_paid, p.invoice_id
                       FROM ap_invoice_payments_all p
                      WHERE p.accounting_date <= :p_as_on_date
                   GROUP BY p.invoice_id) aipa
               ,  (  SELECT SUM (d.amount) invoice_amount, d.invoice_id
                       FROM ap_invoice_LINES_all d
                      WHERE d.accounting_date < :p_as_on_date
                   GROUP BY d.invoice_id) aida*/
          WHERE i.invoice_id = ps.invoice_id
             AND i.vendor_id = pv.vendor_id
             AND atb.vendor_id = pv.vendor_id
             and i.invoice_id = atb.invoice_id
             and atb.invoice_id = ps.invoice_id
           --  AND i.cancelled_date IS NULL
             AND alc1.lookup_type = 'INVOICE TYPE'
             AND alc1.lookup_code = i.invoice_type_lookup_code
             AND i.terms_id = term.term_id(+)
           ---  AND i.invoice_id = aipa.invoice_id(+)
             and   i.invoice_date < :p_as_on_date
             AND pv.vendor_name = nvl(:p_vendor_name, pv.vendor_name)
             AND pv.segment1 = nvl(:p_vendor_num, pv.segment1)
            --AND i.invoice_id = aida.invoice_id(+)
           --  AND NVL (aida.invoice_amount, i.invoice_amount) - NVL (aipa.invoice_amt_paid, 0) != 0
  
)
    ORDER BY
      vendor_name,
      vendor_number,
      payment_terms
  )
group by
  vendor_name,
  vendor_number