CREATE OR REPLACE PACKAGE XXVEN_AP_REPSUPOU_PKG AUTHID CURRENT_USER AS
  -- $Header: XXVEN_AP_REPSUPOU_PKG.pks 120.1 2020/07/29 12:00:00 appldev $
  -- +=================================================================+
  -- |        Copyright (c) 2020 VENANCIO Rio de Janeiro, Brasil       |
  -- |                       All rights reserved.                      |
  -- +=================================================================+
  -- | FILENAME                                                        |
  -- |   XXVEN_AP_REPSUPOU_PKG.pks                                     |
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
  ;
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
  ;
  --
END XXVEN_AP_REPSUPOU_PKG;
/