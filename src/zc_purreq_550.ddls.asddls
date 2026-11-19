@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Requisition (Projection)'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['ReqID']
define root view entity ZC_PurReq_550
  provider contract transactional_query
  as projection on ZR_PurReq_550
{
  key ReqUUID,
      @Search.defaultSearchElement: true
      ReqID,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Title,
      Description,
      @Search.defaultSearchElement: true
      CostCenter,
      NeededBy,
      @ObjectModel.text.element: ['StatusText']
      Status,
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PURREQ_VIRT_550'
      @EndUserText.label: 'Status Text'
      virtual StatusText        : abap.char(20),
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_PURREQ_VIRT_550'
      @EndUserText.label: 'Status Criticality'
      virtual StatusCriticality : abap.int1,
      TotalAmount,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'I_CurrencyStdVH', element: 'Currency' }, useForValidation: true }]
      CurrencyCode,
      DecidedBy,
      DecidedAt,
      RejectionReason,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      _Item : redirected to composition child ZC_PurReqItem_550
}
