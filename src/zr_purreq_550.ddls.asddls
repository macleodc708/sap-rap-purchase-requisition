@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Requisition'
define root view entity ZR_PurReq_550
  as select from zpr_req_550
  composition [0..*] of ZR_PurReqItem_550 as _Item
{
  key req_uuid              as ReqUUID,
      req_id                as ReqID,
      title                 as Title,
      description           as Description,
      cost_center           as CostCenter,
      needed_by             as NeededBy,
      status                as Status,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_amount          as TotalAmount,
      currency_code         as CurrencyCode,
      decided_by            as DecidedBy,
      decided_at            as DecidedAt,
      rejection_reason      as RejectionReason,

      @Semantics.user.createdBy: true
      local_created_by      as LocalCreatedBy,
      @Semantics.systemDateTime.createdAt: true
      local_created_at      as LocalCreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      _Item
}
