CREATE OR REPLACE PACKAGE BODY XXVEN_AP_REPSUPOU_PKG AS
  -- $Header: XXVEN_AP_REPSUPOU_PKG.pkb 120.1 2020/07/29 12:00:00 appldev $
  -- +=================================================================+
  -- |        Copyright (c) 2020 VENANCIO Rio de Janeiro, Brasil       |
  -- |                       All rights reserved.                      |
  -- +=================================================================+
  -- | FILENAME                                                        |
  -- |   XXVEN_AP_REPSUPOU_PKG.pkb                                     |
  -- |                                                                 |
  -- | PURPOSE                                                         |
  -- |   Replicar informações de Fornecedores entre as Unidades de     |
  -- |   Negocio Cadastradas                                           |
  -- |                                                                 |
  -- | [DESCRIPTION]                                                   |
  -- |   ...                                                           |
  -- |                                                                 |
  -- | [PARAMETERS]                                                    |
  -- |   [Parametro1: descricao do parametro]                          |
  -- |   [Parametro2: descricao do parametro]                          |
  -- |                                                                 |
  -- | CREATED BY                                                      |
  -- |   Alessandro Chaves      2020/07/29            v120.1           |
  -- |                                                                 |
  -- | ALTERED BY                                                      |
  -- |   ...                                                           |
  -- |   [nome]             [data alteracao]        [nova versao]      |
  -- |                                                                 |
  -- +=================================================================+
  --
  PROCEDURE set_log_p
    (
       p_vendor_id      IN NUMBER
     , p_status         IN VARCHAR2
     , p_erro           IN VARCHAR2
     , p_vendor_site_id	IN NUMBER
     , p_party_site_id	IN NUMBER
     , p_location_id    IN NUMBER
    )
  IS
    lv_msg   VARCHAR2(32000);
  BEGIN
    IF p_status = 'S' THEN
      lv_msg := 'SUCESSO: Vendor_id: ' || p_vendor_id      ||
                '; Vendor_Site_Id: '   || p_vendor_site_id ||
                '; Party_Site_Id: '    || p_party_site_id  ||
                '; Location_Id: '      || p_location_id
	  ;
    ELSE
      lv_msg := 'ERROR: Vendor_id: ' || p_vendor_id      ||
                ' --> '   || p_erro
	  ;
    END IF;
    fnd_file.put_line( fnd_file.log, lv_msg );
    dbms_output.put_line( lv_msg );
  END set_log_p;	
  --
  -- Replicate Supplier's Address Book
  PROCEDURE rpl_address_book_p
    (  errbuf      OUT VARCHAR2
     , retcode     OUT NUMBER
     , p_from_ou   IN  NUMBER DEFAULT NULL
     , p_to_ou     IN  NUMBER DEFAULT NULL
     , p_vendor_id IN  NUMBER DEFAULT NULL
     , p_site_id   IN  NUMBER DEFAULT NULL	 
    )
  IS
   
    lr_vendor_site_rec_type   ap_vendor_pub_pkg.r_vendor_site_rec_type;
    lx_return_status          VARCHAR2(32000);
    lx_msg_count              NUMBER;
    lx_msg_data               VARCHAR2(32000);
    lx_vendor_site_id         NUMBER;
    lx_party_site_id          NUMBER;
    lx_location_id            NUMBER;
 
    ln_cnt                    NUMBER := 0;
    ln_user_id                fnd_user.user_id%TYPE;
    ln_resp_id                fnd_responsibility_tl.responsibility_id%TYPE;
    ln_resp_appl_id           fnd_responsibility_tl.application_id%TYPE;
    ln_limit                  PLS_INTEGER := 5000;
    ln_time                   NUMBER;
	
    CURSOR c_supba IS
      SELECT
               sup_site.*
        FROM
               ap_suppliers           sup
             , ap_supplier_sites_all  sup_site
      WHERE 1=1
        AND sup_site.vendor_id        = sup.vendor_id
        AND sup_site.org_id           = 101  -- p_from_ou
        AND sup.vendor_id             = NVL( p_vendor_id, sup.vendor_id )
        AND sup_site.vendor_site_id   = NVL(p_site_id, sup_site.vendor_site_id)
        AND NOT EXISTS
          (
            SELECT 1
              FROM ap_supplier_sites_all assa
            WHERE 1=1
              AND assa.vendor_id      = sup.vendor_id
              AND assa.org_id         = 83  -- p_to_ou
          )
      ORDER BY
               sup.vendor_id
    ;
    --
    TYPE lt_supba                IS TABLE OF ap_supplier_sites_all%ROWTYPE INDEX BY PLS_INTEGER;
    l_supba                      lt_supba;

  BEGIN

	fnd_file.put_line(fnd_file.log,'-------------------------------------------------------------------------------');
    fnd_file.put_line(fnd_file.log,CHR(13)||'    Início Atualização dos Estoques   ');

    EXECUTE IMMEDIATE (' alter session set nls_language  = '||CHR(39)||'AMERICAN'||CHR(39));
    -- Set the applications context
    BEGIN
      mo_global.init('SQLAP');
      -- mo_global.set_policy_context(p_access_mode => 'S', p_org_id => fnd_global.org_id);
      fnd_global.APPS_INITIALIZE
        (   user_id      => fnd_global.user_id
          , resp_id      => fnd_global.resp_id
          , resp_appl_id => fnd_global.resp_appl_id
        )
      ;
      -- fnd_client_info.set_org_context(101);
    END;
    --
    ln_time := dbms_utility.get_time;
    OPEN c_supba;
      LOOP
        FETCH c_supba 
          BULK COLLECT INTO l_supba LIMIT ln_limit
        ;
        FOR i IN 1 .. l_supba.COUNT LOOP
          --
          SAVEPOINT INICIO;
          --
          lr_vendor_site_rec_type.area_code                      := l_supba(i).area_code;
          lr_vendor_site_rec_type.phone                          := l_supba(i).phone;
          lr_vendor_site_rec_type.customer_num                   := l_supba(i).customer_num;
          lr_vendor_site_rec_type.ship_to_location_id            := l_supba(i).ship_to_location_id;
          lr_vendor_site_rec_type.bill_to_location_id            := l_supba(i).ship_to_location_id;
          lr_vendor_site_rec_type.ship_via_lookup_code           := l_supba(i).ship_via_lookup_code;
          lr_vendor_site_rec_type.freight_terms_lookup_code      := l_supba(i).freight_terms_lookup_code;
          lr_vendor_site_rec_type.fob_lookup_code                := l_supba(i).fob_lookup_code;
          lr_vendor_site_rec_type.inactive_date                  := l_supba(i).inactive_date;
          lr_vendor_site_rec_type.fax                            := l_supba(i).fax;
          lr_vendor_site_rec_type.fax_area_code                  := l_supba(i).fax_area_code;
          lr_vendor_site_rec_type.telex                          := l_supba(i).telex;
          lr_vendor_site_rec_type.terms_date_basis               := l_supba(i).terms_date_basis;
          lr_vendor_site_rec_type.distribution_set_id            := l_supba(i).distribution_set_id;
          lr_vendor_site_rec_type.accts_pay_code_combination_id  := l_supba(i).accts_pay_code_combination_id;
          lr_vendor_site_rec_type.prepay_code_combination_id     := l_supba(i).prepay_code_combination_id;
          lr_vendor_site_rec_type.pay_group_lookup_code          := l_supba(i).pay_group_lookup_code;
          lr_vendor_site_rec_type.payment_priority               := l_supba(i).payment_priority;
          lr_vendor_site_rec_type.terms_id                       := l_supba(i).terms_id;
          lr_vendor_site_rec_type.invoice_amount_limit           := l_supba(i).invoice_amount_limit;
          lr_vendor_site_rec_type.pay_date_basis_lookup_code     := l_supba(i).pay_date_basis_lookup_code;
          lr_vendor_site_rec_type.always_take_disc_flag          := l_supba(i).always_take_disc_flag;
          lr_vendor_site_rec_type.invoice_currency_code          := l_supba(i).invoice_currency_code;
          lr_vendor_site_rec_type.payment_currency_code          := l_supba(i).payment_currency_code;
          lr_vendor_site_rec_type.last_update_date               := SYSDATE;
          lr_vendor_site_rec_type.last_updated_by                := fnd_global.user_id;
          lr_vendor_site_rec_type.vendor_id                      := l_supba(i).vendor_id;
          lr_vendor_site_rec_type.vendor_site_code               := l_supba(i).vendor_site_code;
          lr_vendor_site_rec_type.vendor_site_code_alt           := l_supba(i).vendor_site_code_alt;
          lr_vendor_site_rec_type.purchasing_site_flag           := l_supba(i).purchasing_site_flag;
          lr_vendor_site_rec_type.rfq_only_site_flag             := l_supba(i).rfq_only_site_flag;
          lr_vendor_site_rec_type.pay_site_flag                  := l_supba(i).pay_site_flag;
          lr_vendor_site_rec_type.attention_ar_flag              := l_supba(i).attention_ar_flag;
          lr_vendor_site_rec_type.hold_all_payments_flag         := l_supba(i).hold_all_payments_flag;
          lr_vendor_site_rec_type.hold_future_payments_flag      := l_supba(i).hold_future_payments_flag;
          lr_vendor_site_rec_type.hold_reason                    := l_supba(i).hold_reason;
          lr_vendor_site_rec_type.hold_unmatched_invoices_flag   := l_supba(i).hold_unmatched_invoices_flag;
          lr_vendor_site_rec_type.tax_reporting_site_flag        := l_supba(i).tax_reporting_site_flag;
          lr_vendor_site_rec_type.attribute_category             := l_supba(i).attribute_category;
          lr_vendor_site_rec_type.attribute1                     := l_supba(i).attribute1;
          lr_vendor_site_rec_type.attribute2                     := l_supba(i).attribute2;
          lr_vendor_site_rec_type.attribute3                     := l_supba(i).attribute3;
          lr_vendor_site_rec_type.attribute4                     := l_supba(i).attribute4;
          lr_vendor_site_rec_type.attribute5                     := l_supba(i).attribute5;
          lr_vendor_site_rec_type.attribute6                     := l_supba(i).attribute6;
          lr_vendor_site_rec_type.attribute7                     := l_supba(i).attribute7;
          lr_vendor_site_rec_type.attribute8                     := l_supba(i).attribute8;
          lr_vendor_site_rec_type.attribute9                     := l_supba(i).attribute9;
          lr_vendor_site_rec_type.attribute10                    := l_supba(i).attribute10;
          lr_vendor_site_rec_type.attribute11                    := l_supba(i).attribute11;
          lr_vendor_site_rec_type.attribute12                    := l_supba(i).attribute12;
          lr_vendor_site_rec_type.attribute13                    := l_supba(i).attribute13;
          lr_vendor_site_rec_type.attribute14                    := l_supba(i).attribute14;
          lr_vendor_site_rec_type.attribute15                    := l_supba(i).attribute15;
          lr_vendor_site_rec_type.validation_number              := l_supba(i).validation_number;
          lr_vendor_site_rec_type.exclude_freight_from_discount  := l_supba(i).exclude_freight_from_discount;
          lr_vendor_site_rec_type.bank_charge_bearer             := l_supba(i).bank_charge_bearer;
          lr_vendor_site_rec_type.org_id                         := 83; -- p_to_ou
          lr_vendor_site_rec_type.check_digits                   := l_supba(i).check_digits;
          lr_vendor_site_rec_type.allow_awt_flag                 := l_supba(i).allow_awt_flag;
          lr_vendor_site_rec_type.awt_group_id                   := l_supba(i).awt_group_id;
          lr_vendor_site_rec_type.pay_awt_group_id               := l_supba(i).pay_awt_group_id;
          lr_vendor_site_rec_type.default_pay_site_id            := l_supba(i).default_pay_site_id;
          lr_vendor_site_rec_type.pay_on_code                    := l_supba(i).pay_on_code;
          lr_vendor_site_rec_type.pay_on_receipt_summary_code    := l_supba(i).pay_on_receipt_summary_code;
          lr_vendor_site_rec_type.global_attribute_category      := l_supba(i).global_attribute_category;
          lr_vendor_site_rec_type.global_attribute1              := l_supba(i).global_attribute1;
          lr_vendor_site_rec_type.global_attribute2              := l_supba(i).global_attribute2;
          lr_vendor_site_rec_type.global_attribute3              := l_supba(i).global_attribute3;
          lr_vendor_site_rec_type.global_attribute4              := l_supba(i).global_attribute4;
          lr_vendor_site_rec_type.global_attribute5              := l_supba(i).global_attribute5;
          lr_vendor_site_rec_type.global_attribute6              := l_supba(i).global_attribute6;
          lr_vendor_site_rec_type.global_attribute7              := l_supba(i).global_attribute7;
          lr_vendor_site_rec_type.global_attribute8              := l_supba(i).global_attribute8;
          lr_vendor_site_rec_type.global_attribute9              := l_supba(i).global_attribute9;
          lr_vendor_site_rec_type.global_attribute10             := l_supba(i).global_attribute10;
          lr_vendor_site_rec_type.global_attribute11             := l_supba(i).global_attribute11;
          lr_vendor_site_rec_type.global_attribute12             := l_supba(i).global_attribute12;
          lr_vendor_site_rec_type.global_attribute13             := l_supba(i).global_attribute13;
          lr_vendor_site_rec_type.global_attribute14             := l_supba(i).global_attribute14;
          lr_vendor_site_rec_type.global_attribute15             := l_supba(i).global_attribute15;
          lr_vendor_site_rec_type.global_attribute16             := l_supba(i).global_attribute16;
          lr_vendor_site_rec_type.global_attribute17             := l_supba(i).global_attribute17;
          lr_vendor_site_rec_type.global_attribute18             := l_supba(i).global_attribute18;
          lr_vendor_site_rec_type.global_attribute19             := l_supba(i).global_attribute19;
          lr_vendor_site_rec_type.global_attribute20             := l_supba(i).global_attribute20;
          lr_vendor_site_rec_type.tp_header_id                   := l_supba(i).tp_header_id;
          lr_vendor_site_rec_type.ece_tp_location_code           := l_supba(i).ece_tp_location_code;
          lr_vendor_site_rec_type.pcard_site_flag                := l_supba(i).pcard_site_flag;
          lr_vendor_site_rec_type.match_option                   := l_supba(i).match_option;
          lr_vendor_site_rec_type.country_of_origin_code         := l_supba(i).country_of_origin_code;
          lr_vendor_site_rec_type.future_dated_payment_ccid      := l_supba(i).future_dated_payment_ccid;
          lr_vendor_site_rec_type.create_debit_memo_flag         := l_supba(i).create_debit_memo_flag;
          lr_vendor_site_rec_type.supplier_notif_method	         := l_supba(i).supplier_notif_method;
          lr_vendor_site_rec_type.email_address                  := l_supba(i).email_address;
          lr_vendor_site_rec_type.primary_pay_site_flag          := l_supba(i).primary_pay_site_flag;
          lr_vendor_site_rec_type.shipping_control               := l_supba(i).shipping_control;
          lr_vendor_site_rec_type.selling_company_identifier     := l_supba(i).selling_company_identifier;
          lr_vendor_site_rec_type.gapless_inv_num_flag		     := l_supba(i).gapless_inv_num_flag;
          lr_vendor_site_rec_type.duns_number     		         := l_supba(i).duns_number;
          lr_vendor_site_rec_type.address_style   		         := l_supba(i).address_style;
          lr_vendor_site_rec_type.language        		         := l_supba(i).language;
          lr_vendor_site_rec_type.province        		         := l_supba(i).province;
          lr_vendor_site_rec_type.country         		         := l_supba(i).country;
          lr_vendor_site_rec_type.address_line1   		         := l_supba(i).address_line1;
          lr_vendor_site_rec_type.address_line2   		         := l_supba(i).address_line2;
          lr_vendor_site_rec_type.address_line3   		         := l_supba(i).address_line3;
          lr_vendor_site_rec_type.address_line4   		         := l_supba(i).address_line4;
          lr_vendor_site_rec_type.address_lines_alt       	     := l_supba(i).address_lines_alt;
          lr_vendor_site_rec_type.county          		         := l_supba(i).county;
          lr_vendor_site_rec_type.city            		         := l_supba(i).city;
          lr_vendor_site_rec_type.state           		         := l_supba(i).state;
          lr_vendor_site_rec_type.zip             		         := l_supba(i).zip;
          lr_vendor_site_rec_type.tolerance_id			         := l_supba(i).tolerance_id;
          lr_vendor_site_rec_type.retainage_rate			     := l_supba(i).retainage_rate;
          lr_vendor_site_rec_type.services_tolerance_id          := l_supba(i).services_tolerance_id;
          lr_vendor_site_rec_type.vat_code                       := l_supba(i).vat_code;
          lr_vendor_site_rec_type.vat_registration_num		     := l_supba(i).vat_registration_num;
          lr_vendor_site_rec_type.remittance_email		         := l_supba(i).remittance_email;
          lr_vendor_site_rec_type.edi_id_number                  := l_supba(i).edi_id_number;
          lr_vendor_site_rec_type.edi_payment_format             := l_supba(i).edi_payment_format;
          lr_vendor_site_rec_type.edi_transaction_handling       := l_supba(i).edi_transaction_handling;
          lr_vendor_site_rec_type.edi_payment_method             := l_supba(i).edi_payment_method;
          lr_vendor_site_rec_type.edi_remittance_method          := l_supba(i).edi_remittance_method;
          lr_vendor_site_rec_type.edi_remittance_instruction     := l_supba(i).edi_remittance_instruction;
          lr_vendor_site_rec_type.offset_tax_flag                := l_supba(i).offset_tax_flag;
          lr_vendor_site_rec_type.auto_tax_calc_flag             := l_supba(i).auto_tax_calc_flag;
          lr_vendor_site_rec_type.cage_code                      := l_supba(i).cage_code;
          lr_vendor_site_rec_type.legal_business_name            := l_supba(i).legal_business_name;
          lr_vendor_site_rec_type.doing_bus_as_name              := l_supba(i).doing_bus_as_name;
          lr_vendor_site_rec_type.division_name                  := l_supba(i).division_name;
          lr_vendor_site_rec_type.small_business_code            := l_supba(i).small_business_code;
          lr_vendor_site_rec_type.ccr_comments                   := l_supba(i).ccr_comments;
          lr_vendor_site_rec_type.debarment_start_date           := l_supba(i).debarment_start_date;
          lr_vendor_site_rec_type.debarment_end_date             := l_supba(i).debarment_end_date;
          --lr_vendor_site_rec_type.ap_tax_rounding_rule           := l_supba(i).ap_tax_rounding_rule_code;
          --lr_vendor_site_rec_type.amount_includes_tax_flag	     := l_supba(i).amount_inclusive_tax_flag;
          -- lr_vendor_site_rec_type.vendor_site_id			number,
          --lr_vendor_site_rec_type.location_id			         := l_supba(i).location_id;
          --lr_vendor_site_rec_type.party_site_id			         := l_supba(i).party_site_id;
          --lr_vendor_site_rec_type.org_name			hr_operating_units.name;
          --lr_vendor_site_rec_type.terms_name			ap_terms_tl.name;
          --lr_vendor_site_rec_type.default_terms_id		number,
          --lr_vendor_site_rec_type.awt_group_name			ap_awt_groups.name;
          --lr_vendor_site_rec_type.pay_awt_group_name              ap_awt_groups.name;--bug6664407
          --lr_vendor_site_rec_type.distribution_set_name		ap_distribution_sets_all.distribution_set_name;
          --lr_vendor_site_rec_type.ship_to_location_code           hr_locations_all_tl.location_code;
          --lr_vendor_site_rec_type.bill_to_location_code           hr_locations_all_tl.location_code;
          --lr_vendor_site_rec_type.default_dist_set_id             number,
          --lr_vendor_site_rec_type.default_ship_to_loc_id          number,
          --lr_vendor_site_rec_type.default_bill_to_loc_id          number,
          --lr_vendor_site_rec_type.tolerance_name			ap_tolerance_templates.tolerance_name;
          --lr_vendor_site_rec_type.vendor_interface_id		number,
          --lr_vendor_site_rec_type.vendor_site_interface_id	number,
          --lr_vendor_site_rec_type.ext_payee_rec			iby_disbursement_setup_pub.external_payee_rec_type,
          --lr_vendor_site_rec_type.services_tolerance_name         ap_tolerance_templates.tolerance_name;
          --lr_vendor_site_rec_type.shipping_location_id            number,
          --lr_vendor_site_rec_type.party_site_name            hz_party_sites.party_site_name; -- bug 7429668
          --lr_vendor_site_rec_type.remit_advice_delivery_method ap_supplier_sites_int.remit_advice_delivery_method%type  -- bug 8422781
          --lr_vendor_site_rec_type.remit_advice_fax           ap_supplier_sites_int.remit_advice_fax%type -- bug 8769088
          -- starting the changes for clm reference data management bug#9499174
	
          ap_vendor_pub_pkg.create_vendor_site
            ( 	
                p_api_version        => 1.0
              , p_init_msg_list      => FND_API.G_TRUE
              , p_commit             => FND_API.G_TRUE
              , p_validation_level   => FND_API.G_VALID_LEVEL_FULL
              , x_return_status      => lx_return_status
              , x_msg_count          => lx_msg_count
              , x_msg_data           => lx_msg_data
              , p_vendor_site_rec    => lr_vendor_site_rec_type
              , x_vendor_site_id     => lx_vendor_site_id
              , x_party_site_id      => lx_party_site_id
              , x_location_id        => lx_location_id
            )
          ;
          IF lx_return_status = fnd_api.g_ret_sts_success THEN
            set_log_p
              (
                 p_vendor_id      => l_supba(i).VENDOR_ID
               , p_status         => lx_return_status
               , p_erro           => lx_msg_data
               , p_vendor_site_id => lx_vendor_site_id
               , p_party_site_id  => lx_party_site_id
               , p_location_id    => lx_location_id
              )
            ;
            COMMIT;
          ELSE
            ROLLBACK;
            FOR i IN 1 .. lx_msg_count LOOP
              lx_msg_data := oe_msg_pub.get(
                                             p_msg_index => i
                                           , p_encoded   => 'F'
                                          )
              ;
              set_log_p
                (
                   p_vendor_id      => l_supba(i).VENDOR_ID
                 , p_status         => lx_return_status
                 , p_erro           => lx_msg_data
                 , p_vendor_site_id => lx_vendor_site_id
                 , p_party_site_id  => lx_party_site_id
                 , p_location_id    => lx_location_id
                )
              ;
            END LOOP;			 
          END IF;	  
          --
          COMMIT;
          <<PROXIMO>>
          NULL;
          --
        END LOOP;
        EXIT WHEN l_supba.COUNT < ln_limit;
      END LOOP;
    CLOSE c_supba;
    --
    COMMIT;
    --
    dbms_output.put_line( 'Finalizado em: '||((dbms_utility.get_time - ln_time)/100) || ' seconds....' );
    fnd_file.put_line (fnd_file.log, 'Finalizado em: '||((dbms_utility.get_time - ln_time)/100) || ' seconds....' );
    fnd_file.put_line(fnd_file.log,'-------------------------------------------------------------------------------'||CHR(13));
  END rpl_address_book_p;
  --
END XXVEN_AP_REPSUPOU_PKG;
/