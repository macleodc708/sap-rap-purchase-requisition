@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Requisition Item'
define view entity ZR_PurReqItem_550
  as select from zpr_item_550
  association to parent ZR_PurReq_550 as _PurReq on $projection.ParentUUID = _PurReq.ReqUUID
{
  key item_uuid             as ItemUUID,
      parent_uuid           as ParentUUID,
      item_no               as ItemNo,
      description           as Description,
      @Semantics.quantity.unitOfMeasure: 'Unit'
      quantity              as Quantity,
      unit                  as Unit,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      unit_price            as UnitPrice,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      net_amount            as NetAmount,
      currency_code         as CurrencyCode,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _PurReq
}
