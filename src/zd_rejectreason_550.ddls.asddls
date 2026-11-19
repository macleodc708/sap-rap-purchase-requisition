@EndUserText.label: 'Parameter for Rejecting a Requisition'
define abstract entity ZD_RejectReason_550
{
  @EndUserText.label: 'Reason for Rejection'
  RejectionReason : abap.char(255);
}
