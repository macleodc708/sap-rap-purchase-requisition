"""Erzeugt die abapGit-XML-Dateien der Datenbanktabellen (aktiv + Draft)."""
BOM = '﻿'

def builtin(datatype, inttype, intlen, leng, decimals=None, ref=None):
    return dict(kind='builtin', datatype=datatype, inttype=inttype, intlen=intlen, leng=leng, decimals=decimals, ref=ref)

def rollname(name):
    return dict(kind='rollname', rollname=name)

CHAR = lambda n: builtin('CHAR', 'C', n * 2, n)
DATS = builtin('DATS', 'D', 16, 8)
CUKY = builtin('CUKY', 'C', 10, 5)
UNIT = builtin('UNIT', 'C', 6, 3)
INT4 = builtin('INT4', 'X', 4, 10)
TSTMPL = builtin('DEC', 'P', 11, 21, 7)
CURR = lambda ref: builtin('CURR', 'P', 8, 15, 2, ref)
QUAN = lambda ref: builtin('QUAN', 'P', 7, 13, 3, ref)
UUID = rollname('SYSUUID_X16')

def field_xml(table, name, spec, key=False, notnull=False):
    x = ['    <DD03P>', f'     <FIELDNAME>{name}</FIELDNAME>']
    if key: x.append('     <KEYFLAG>X</KEYFLAG>')
    if spec['kind'] == 'rollname':
        x.append(f"     <ROLLNAME>{spec['rollname']}</ROLLNAME>")
        x.append('     <ADMINFIELD>0</ADMINFIELD>')
        if notnull: x.append('     <NOTNULL>X</NOTNULL>')
        x.append('     <COMPTYPE>E</COMPTYPE>')
    else:
        x.append('     <ADMINFIELD>0</ADMINFIELD>')
        x.append(f"     <INTTYPE>{spec['inttype']}</INTTYPE>")
        x.append(f"     <INTLEN>{spec['intlen']:06d}</INTLEN>")
        if spec['ref']:
            x.append(f'     <REFTABLE>{table}</REFTABLE>')
            x.append(f"     <REFFIELD>{spec['ref']}</REFFIELD>")
        if notnull: x.append('     <NOTNULL>X</NOTNULL>')
        x.append(f"     <DATATYPE>{spec['datatype']}</DATATYPE>")
        x.append(f"     <LENG>{spec['leng']:06d}</LENG>")
        if spec['decimals'] is not None: x.append(f"     <DECIMALS>{spec['decimals']:06d}</DECIMALS>")
        x.append(f"     <MASK>  {spec['datatype']}</MASK>")
    x.append('    </DD03P>')
    return '\n'.join(x)

def table_xml(name, text, fields, draft=False):
    client = 'MANDT' if draft else 'CLIENT'
    client_xml = (field_xml(name, 'MANDT', rollname('MANDT'), key=True, notnull=True) if draft else
                  '\n'.join(['    <DD03P>', '     <FIELDNAME>CLIENT</FIELDNAME>', '     <KEYFLAG>X</KEYFLAG>',
                             '     <ADMINFIELD>0</ADMINFIELD>', '     <INTTYPE>C</INTTYPE>', '     <INTLEN>000006</INTLEN>',
                             '     <NOTNULL>X</NOTNULL>', '     <DATATYPE>CLNT</DATATYPE>', '     <LENG>000003</LENG>',
                             '     <MASK>  CLNT</MASK>', '    </DD03P>']))
    rows = [client_xml]
    for i, (fname, spec) in enumerate(fields):
        rows.append(field_xml(name, fname, spec, key=(i == 0), notnull=(i == 0)))
    if draft:
        rows.append('\n'.join(['    <DD03P>', '     <FIELDNAME>.INCLUDE</FIELDNAME>', '     <ADMINFIELD>0</ADMINFIELD>',
                               '     <PRECFIELD>SYCH_BDL_DRAFT_ADMIN_INC</PRECFIELD>', '     <MASK>      S</MASK>',
                               '     <DDTEXT>Standard Include for Draft Administration (BDL Syntax Check)</DDTEXT>',
                               '     <COMPTYPE>S</COMPTYPE>', '     <GROUPNAME>%ADMIN</GROUPNAME>', '    </DD03P>']))
    dd02v = [f'    <TABNAME>{name}</TABNAME>', '    <DDLANGUAGE>E</DDLANGUAGE>', '    <TABCLASS>TRANSP</TABCLASS>',
             '    <CLIDEP>X</CLIDEP>']
    if draft: dd02v.append('    <LANGDEP>X</LANGDEP>')
    dd02v += [f'    <DDTEXT>{text}</DDTEXT>', '    <MASTERLANG>E</MASTERLANG>', '    <CONTFLAG>A</CONTFLAG>',
              f"    <EXCLASS>{'4' if draft else '1'}</EXCLASS>"]
    dd09l = [f'    <TABNAME>{name}</TABNAME>', '    <AS4LOCAL>A</AS4LOCAL>', f"    <TABKAT>{'4' if draft else '0'}</TABKAT>",
             f"    <TABART>{'APPL1' if draft else 'APPL0'}</TABART>", '    <BUFALLOW>N</BUFALLOW>']
    return BOM + '\n'.join([
        '<?xml version="1.0" encoding="utf-8"?>',
        '<abapGit version="v1.0.0" serializer="LCL_OBJECT_TABL" serializer_version="v1.0.0">',
        ' <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">', '  <asx:values>',
        '   <DD02V>', *dd02v, '   </DD02V>', '   <DD09L>', *dd09l, '   </DD09L>',
        '   <DD03P_TABLE>', *rows, '   </DD03P_TABLE>', '  </asx:values>', ' </asx:abap>', '</abapGit>', ''])

ADMIN_ACTIVE = [('LOCAL_CREATED_BY', rollname('ABP_CREATION_USER')), ('LOCAL_CREATED_AT', rollname('ABP_CREATION_TSTMPL')),
                ('LOCAL_LAST_CHANGED_BY', rollname('ABP_LOCINST_LASTCHANGE_USER')),
                ('LOCAL_LAST_CHANGED_AT', rollname('ABP_LOCINST_LASTCHANGE_TSTMPL')), ('LAST_CHANGED_AT', rollname('ABP_LASTCHANGE_TSTMPL'))]
ADMIN_DRAFT = [(n.replace('_', ''), s) for n, s in ADMIN_ACTIVE]

req_active = [('REQ_UUID', UUID), ('REQ_ID', CHAR(10)), ('TITLE', CHAR(80)), ('DESCRIPTION', CHAR(255)),
              ('COST_CENTER', CHAR(10)), ('NEEDED_BY', DATS), ('STATUS', CHAR(1)), ('TOTAL_AMOUNT', CURR('CURRENCY_CODE')),
              ('CURRENCY_CODE', CUKY), ('DECIDED_BY', CHAR(12)), ('DECIDED_AT', TSTMPL), ('REJECTION_REASON', CHAR(255))] + ADMIN_ACTIVE
req_draft = [('REQUUID', UUID), ('REQID', CHAR(10)), ('TITLE', CHAR(80)), ('DESCRIPTION', CHAR(255)),
             ('COSTCENTER', CHAR(10)), ('NEEDEDBY', DATS), ('STATUS', CHAR(1)), ('TOTALAMOUNT', CURR('CURRENCYCODE')),
             ('CURRENCYCODE', CUKY), ('DECIDEDBY', CHAR(12)), ('DECIDEDAT', TSTMPL), ('REJECTIONREASON', CHAR(255))] + ADMIN_DRAFT
item_active = [('ITEM_UUID', UUID), ('PARENT_UUID', UUID), ('ITEM_NO', INT4), ('DESCRIPTION', CHAR(80)),
               ('QUANTITY', QUAN('UNIT')), ('UNIT', UNIT), ('UNIT_PRICE', CURR('CURRENCY_CODE')), ('NET_AMOUNT', CURR('CURRENCY_CODE')),
               ('CURRENCY_CODE', CUKY), ('LOCAL_LAST_CHANGED_AT', rollname('ABP_LOCINST_LASTCHANGE_TSTMPL'))]
item_draft = [('ITEMUUID', UUID), ('PARENTUUID', UUID), ('ITEMNO', INT4), ('DESCRIPTION', CHAR(80)),
              ('QUANTITY', QUAN('UNIT')), ('UNIT', UNIT), ('UNITPRICE', CURR('CURRENCYCODE')), ('NETAMOUNT', CURR('CURRENCYCODE')),
              ('CURRENCYCODE', CUKY), ('LOCALLASTCHANGEDAT', rollname('ABP_LOCINST_LASTCHANGE_TSTMPL'))]

for name, text, fields, draft in [
    ('ZPR_REQ_550', 'Purchase Requisition (Header)', req_active, False),
    ('ZPR_REQ_D_550', 'Draft table for entity ZR_PURREQ_550', req_draft, True),
    ('ZPR_ITEM_550', 'Purchase Requisition (Item)', item_active, False),
    ('ZPR_ITEM_D_550', 'Draft table for entity ZR_PURREQITEM_550', item_draft, True)]:
    with open(f'src/{name.lower()}.tabl.xml', 'w', encoding='utf-8') as f:
        f.write(table_xml(name, text, fields, draft))
    print('written', name, len(fields) + 1, 'fields')
