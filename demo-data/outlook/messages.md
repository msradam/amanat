# Outlook Demo Messages

Synthetic emails used in the Amanat demo. These simulate real data governance violations found in humanitarian field operations.

## Email 1: Beneficiary list sent to external audit

- **Subject:** FW: Beneficiary list for Ambara Fund verification
- **From:** farah@wra-waqwaq.org
- **To:** audit@ambara-fund.org (external)
- **Date:** 2026-03-18
- **Attachment:** Beneficiary_List_Q1_Full.xlsx
- **PII:** Beneficiary names, WRA case numbers (WAQ-26C00891, WAQ-26C00892), distribution records for 12,400 beneficiaries
- **Violation:** Beneficiary PII sent to external recipient without redaction or data sharing agreement

## Email 2: Medical transport with beneficiary details

- **Subject:** RE: Medical transport for beneficiary
- **From:** penn@wra-waqwaq.org
- **To:** logistics@wra-waqwaq.org
- **Date:** 2026-03-22
- **PII:** Beneficiary name, case number (WAQ-26C00891), medical diagnosis (acute respiratory infection), GPS coordinates (12.4567, 43.8901), family member name, phone number (+252-61-555-0147)
- **Violation:** Medical data and GPS coordinates in email, phone number of family member
