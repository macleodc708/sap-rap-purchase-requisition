@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Requisition Item (Projection)'
@Metadata.allowExtensions: true
define view entity ZC_PurReqItem_550
  as projection on ZR_PurReqItem_550
{
  key ItemUUID,
      ParentUUID,
      ItemNo,
      Description,
      Quantity,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_UnitOfMeasureStdVH', element: 'UnitOfMeasure' }, useForValidation: true }]
      Unit,
      UnitPrice,
      NetAmount,
      CurrencyCode,
      LocalLastChangedAt,

      _PurReq : redirected to parent ZC_PurReq_550
}
