# Urban Easy Mobile App - Manual QA Test Cases

## Scope

Test both live mobile modules with dynamic backend data:

- Property Management
- Society Management

Use the same login credentials unless a case explicitly needs a different role:

- Mobile: `8522863101`
- OTP: `9009`

Do not hardcode expected names, counts, bill amounts, dates, or IDs. Validate that the app shows values returned by the API and that filters/actions update the visible data correctly.

## Test Rules

- Run on a real Android device with a fresh debug APK.
- Capture screenshots for failed cases.
- Check logcat after every major module for `E/flutter`, `EXCEPTION CAUGHT`, `FATAL EXCEPTION`, `AndroidRuntime`, and disposed controller errors.
- Do not complete destructive live actions unless using a staging account. Stop at confirmation dialogs for close contract, resolve enquiry, mark ticket resolved, create bill, confirm payment, renew plan, deactivate/activate records, and delete/remove actions.
- For any time check, compare against the website or API timestamp using the device timezone. The app must not show UTC-offset shifted times.

## Common Login And Role Switching

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| GEN-001 | Launch | Open the app from a clean install. | Splash/login loads without red screen or Flutter exception. |
| GEN-002 | Login | Enter `8522863101`, request OTP, enter `9009`. | Login succeeds and role/module selection appears if multiple roles are available. |
| GEN-003 | Property role | Select Property Management. | Property dashboard loads with manager name, summary cards, bottom navigation, and notification icon. |
| GEN-004 | Society role | Sign out or switch role, then select Society Management. | Society dashboard loads with society manager name, summary cards, bottom navigation, and notification icon. |
| GEN-005 | Back navigation | Open each main tab, then press Android back once. | App returns to previous screen or dashboard without red screen. |
| GEN-006 | Runtime logs | After each module, inspect logcat. | No Flutter exceptions, no disposed controller error, no fatal crash. |

## Property Management

### Property Dashboard

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| PM-DASH-001 | Dashboard data | Open Property Management Home. | Summary counts, enquiry count, contract/bill metrics, and manager name display from API data. |
| PM-DASH-002 | Enquiry badge | Compare dashboard enquiry count with unresolved enquiries list. | Count matches unresolved enquiry records only. Resolved enquiries are excluded. |
| PM-DASH-003 | Notification icon | Tap notification bell. | Notifications page opens and lists property events with readable timestamps. |
| PM-DASH-004 | Refresh | Pull to refresh the dashboard. | Counts reload without duplicate cards or layout jump. |

### Properties

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| PM-PROP-001 | Property list | Open Properties tab. | Property cards load with property name, owner name, approval/status text, available/used contract counts, and image/fallback. |
| PM-PROP-002 | Dynamic approved text | Inspect approved/pending/status line on cards. | Text is dynamic, fits on one line where possible, and does not overlap buttons. |
| PM-PROP-003 | Availability visible | Open a property with availability slots. | Availability/contract slot information is visible and not clipped off screen. |
| PM-PROP-004 | Search | Search using a visible property name. | List filters to matching properties and restores when search is cleared. |
| PM-PROP-005 | Status filter | Use available property status filters. | Cards update according to selected status. |
| PM-PROP-006 | Deactivate property popup | Tap Deactivate/Close/Inactive action on a property. | Website-style confirmation popup opens with property details. Cancel closes it without changing data. |
| PM-PROP-007 | Deactivate property action | In staging only, confirm deactivate. | API updates status, card refreshes, and website shows matching status. |

### Property Enquiries

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| PM-ENQ-001 | Default list | Open Enquiries. | Only unresolved/new enquiries are shown by default. Resolved count is not mixed into default list. |
| PM-ENQ-002 | Property details | Inspect an enquiry card. | Card shows tenant name, tenant phone/email where available, property name, owner name, message, and received time. |
| PM-ENQ-003 | Property filter | Select a property from property filter. | List and counts update to that property only. |
| PM-ENQ-004 | Status filter | Switch between New and Resolved. | New shows Mark Resolved; Resolved does not show Mark Resolved. |
| PM-ENQ-005 | Resolve confirmation | Tap Mark Resolved on a new enquiry. | Confirmation/action path opens without crash. Cancel keeps enquiry unresolved. |
| PM-ENQ-006 | Resolve action | In staging only, confirm Mark Resolved. | Enquiry disappears from default new list, count decreases, resolved list includes it. |
| PM-ENQ-007 | Notification creation | Create or use a fresh website enquiry. | Property notification appears in app with tenant/property details and correct time. |
| PM-ENQ-008 | Time accuracy | Compare enquiry time with website. | App time matches local display expected from backend timestamp, not shifted by timezone. |

### Rental Contracts

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| PM-CON-001 | Contract list | Open Contracts tab. | Active, expired, and closed totals display. Cards show tenant profile photo/fallback, name, 10-digit phone, property, flat/unit, status, and dates. |
| PM-CON-002 | KYC pending | Find a tenant without uploaded documents. | Card/detail shows `KYC Pending` to remind owner documents are missing. |
| PM-CON-003 | Active status | Open an active contract detail. | Detail shows active contract information, owner/property/tenant data, rent/security/maintenance, and date terms. |
| PM-CON-004 | Expired status | Open an expired contract. | Contract shows `Expired`, not active, when end date is completed. |
| PM-CON-005 | Closed status | Open a closed contract. | Contract shows `Closed` and cannot be activated again from the same screen. |
| PM-CON-006 | Close contract popup | Tap Close Contract on an active contract. | Website-style popup opens with warning and contract/property/tenant details. Cancel returns safely. |
| PM-CON-007 | Close contract action | In staging only, confirm close contract. | Contract becomes Closed, used count decreases, available count increases, and the contract cannot be reactivated. |
| PM-CON-008 | Add contract visibility | Open Add Contract. | Availability slot section is visible, not hidden out of display. |
| PM-CON-009 | Phone validation | Enter tenant phone shorter or longer than 10 digits. | Validation blocks submit and says tenant phone must be 10-digit mobile number. |
| PM-CON-010 | Duplicate flat | Enter an existing flat number for the same property. | Popup/message says flat number already exists for this property. |
| PM-CON-011 | Required data back | Start Add Contract with incomplete data, then press back. | No red screen, no disposed controller error, and contract list remains usable. |
| PM-CON-012 | Renewal reduced capacity | Open Renew plan and reduce purchased slots below active contracts. | Popup explains active/purchased/free contract counts and required extra contract count. No endless spinner. |
| PM-CON-013 | Rental agreement preview | Tap PDF/rental agreement action. | In-app Rental Agreement Preview opens first, not Android share sheet. |
| PM-CON-014 | Rental agreement content | Inspect preview. | Logo, parties, property, tenant, owner, rent, security, dates, terms, and signature sections are dynamic and match contract data. |

### Rental Bills And Payments

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| PM-BILL-001 | Bill list | Open Bills tab. | Rental bill cards load without Generate Bills button and without `Unable to load payment proof` for valid proof URLs. |
| PM-BILL-002 | Card content | Inspect bill cards. | Tenant profile photo/fallback, tenant name, phone, property, bill month/type, amount, due date, status, and action buttons are visible. |
| PM-BILL-003 | Filters | Check visible filters. | Maintenance, first month rent paid, and first month security deposit paid filters are absent if backend cannot support them. Remaining filters update list correctly. |
| PM-BILL-004 | Record payment button | Find an unpaid/partial bill. | Record Payment button is visible on the bill card. |
| PM-BILL-005 | Record payment attach | Open Record Payment, enter amount/mode/reference, upload image. | Screen does not reload or wipe entered data; uploaded image preview appears. |
| PM-BILL-006 | Confirm payment guard | Tap Confirm Payment only in staging. | No red screen. Payment posts once, bill refreshes, and receipt/proof is visible. |
| PM-BILL-007 | Back from payment | Open manual payment screen, type partial data, press back. | Returns safely without red screen or disposed controller error. |
| PM-BILL-008 | Export bills | Open Export PDF/report. | In-app PDF preview opens before sharing. |
| PM-BILL-009 | Receipt preview | Open bill receipt. | Receipt preview contains Urban Easy logo and dynamic bill/payment data. |
| PM-BILL-010 | Bill PDF UI | Inspect rental bill PDF. | Layout is readable, logo appears, and labels/data are aligned. |

### Property Support

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| PM-SUP-001 | Support list | Open Support from Account. | Ticket stats and cards load. |
| PM-SUP-002 | Tenant details | Inspect ticket card. | Card shows tenant name, phone, email, property/unit context, priority/status, and created time. |
| PM-SUP-003 | Tenant photo | Inspect ticket avatar. | Tenant profile photo appears when available; otherwise initials/fallback appears, not attachment image. |
| PM-SUP-004 | Details dialog | Tap View Details. | Details opens, including uploaded attachment preview/open action when present. |
| PM-SUP-005 | Status action | Tap resolve/status action. | Confirmation/action opens without crash. Do not confirm on live data. |
| PM-SUP-006 | Time accuracy | Compare support created time with website. | Time matches local expected display. |

### Property Account, Bank, Settings, Reports

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| PM-ACC-001 | Account modules | Open Account. | Property module list displays Properties, Contracts, Bills, Enquiries, Support, Bank Details, Reports, Settings as applicable. |
| PM-BANK-001 | Bank details | Open Bank Details. | Wallet/accounts/transactions/withdrawals tabs load without crash. |
| PM-SET-001 | Settings | Open Settings. | Profile details and profile photo controls display correctly. |
| PM-REP-001 | Reports | Open Reports. | Reports page loads and filters/actions are visible. |
| PM-NOT-001 | Notifications | Open Notifications. | Enquiry and contract notifications show tenant/property details and status. |

## Society Management

### Society Dashboard

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| SM-DASH-001 | Dashboard data | Open Society Management Home. | Society manager name, open tickets, unread notices, monthly collection, and alerts display from API. |
| SM-DASH-002 | Renew button color | Inspect renewal/slot buttons on dashboard. | Color changes by expiry: normal when safe, orange within 5 days, red within 2 days or expired. |
| SM-DASH-003 | Shortcut navigation | Use dashboard shortcuts. | Each shortcut opens the correct module without stale data. |
| SM-DASH-004 | New-number isolation | Login with a number not added as resident. | Resident details from other numbers must not appear. User sees only allowed account/society data. |

### Residents

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| SM-RES-001 | Resident list | Open Residents tab. | Counts show total/active/available/used slots. Cards show name, phone, email, flat/unit, block, building, type, and active/inactive status. |
| SM-RES-002 | Inactive color | Find inactive resident. | Inactive chip is red. Active chip uses active/success color. |
| SM-RES-003 | Profile photo | Inspect residents with photos. | Profile photo appears when API provides one; support/attachment image is not used as profile photo. |
| SM-RES-004 | Block/building | Inspect resident cards. | Block and building names display dynamically on cards. |
| SM-RES-005 | Filters | Use search, block, building, type, and status filters. | List updates and resets correctly. |
| SM-RES-006 | Add resident label | Open Add Resident. | Monthly Rent label is changed to Monthly Maintenance. |
| SM-RES-007 | Add resident validation | Leave required data incomplete and press Save. | Validation messages show and no API call is made. |
| SM-RES-008 | Back with incomplete data | Start Add Resident, fill partial data, press back. | Returns to list without red screen or disposed controller error. |
| SM-RES-009 | Renew slot warning | Open Renew Slots and reduce slots below used/active residents. | Website-style popup explains used/purchased/free slots and extra slots needed. No endless spinner. |
| SM-RES-010 | Renewal date color | Check resident renew-slot button close to expiry. | Orange appears within 5 days, red within 2 days or expired. |

### Society Billing

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| SM-BILL-001 | Billing list | Open Billing tab. | Summary totals and bill cards load with resident data. |
| SM-BILL-002 | Card content | Inspect each card. | Resident profile photo/fallback, name, phone, email, block, building, unit, bill type, amount, due date, and status appear. |
| SM-BILL-003 | Record payment | Find unpaid/partial bill. | Record Payment button appears on each eligible card. |
| SM-BILL-004 | Reminder button color | Inspect Send Reminder button. | Send Reminder button is green, not blue. |
| SM-BILL-005 | Manual payment upload | Open Record Payment, upload proof. | Data stays filled after upload and image preview appears. |
| SM-BILL-006 | Bill view | Tap View on a bill. | Detail modal opens with resident, society, block/building, unit, amount, date, and payment data. |
| SM-BILL-007 | Receipt preview | Tap Download Receipt/View Receipt. | In-app receipt preview opens before sharing and includes logo with dynamic receipt data. |
| SM-BILL-008 | Export bills | Tap Export PDF/report. | In-app PDF preview opens before sharing and includes society logo/data. |
| SM-BILL-009 | Maintenance bill PDF | Inspect maintenance bill preview. | UI is aligned, readable, branded, and data is dynamic. |

### Society Communication

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| SM-COM-001 | Communication list | Open Communication. | Announcement count and list cards load. Spinner disappears after local announcement load. |
| SM-COM-002 | Time accuracy | Compare visible announcement time with website/API. | Time matches expected local display and is not shifted. |
| SM-COM-003 | Search | Search by visible title/message. | List filters and restores when search clears. |
| SM-COM-004 | Priority filter | Select Low/Medium/High. | List updates to matching priority only. |
| SM-COM-005 | Block/building filter | Select block/building. | List updates to matching targeted notices. |
| SM-COM-006 | New announcement form | Open New Announcement, enter partial data, press back/cancel. | No red screen. Form closes safely. |
| SM-COM-007 | Create announcement | In staging only, create an announcement. | It appears in list/dashboard/notifications with correct time and target. |

### Society Support

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| SM-SUP-001 | Support list | Open Support. | Stats and ticket cards load. |
| SM-SUP-002 | Resident details | Inspect ticket card. | Resident name, phone, email, block/building/unit, status, priority, and created time appear. |
| SM-SUP-003 | Profile photo | Inspect support avatar. | Resident profile photo appears when available; attachment image is not shown as profile photo. |
| SM-SUP-004 | Details dialog | Tap View Details. | Details opens with issue text, resident details, timestamps, and attachment if present. |
| SM-SUP-005 | Resolve action | Tap resolve/status action. | Confirmation/action opens without crash. Do not confirm on live data. |
| SM-SUP-006 | Time accuracy | Compare support ticket created time with website. | App time matches local expected display. |

### Society Management, Security, Bank, Reports, Settings, Notifications

| ID | Area | Steps | Expected Result |
| --- | --- | --- | --- |
| SM-SOC-001 | Society profile | Open Society tab. | Society name, status, address, phone, email, available resident slots, blocks, buildings, and setup progress appear. |
| SM-SOC-002 | Edit profile guard | Tap edit action and cancel. | Form opens without crash and cancel returns safely. |
| SM-SEC-001 | Security | Open Security from Account. | Incident/visitor/security queue loads with filters and status actions. |
| SM-SEC-002 | Security action guard | Open an update action and cancel. | Confirmation/action path opens without changing live data. |
| SM-BANK-001 | Bank details | Open Bank Details. | Wallet/accounts/transactions/withdrawals tabs load. |
| SM-REP-001 | Reports | Open Reports. | Financial, visitor, maintenance, support, and wallet report sections load. |
| SM-SET-001 | Settings | Open Settings. | Profile details and photo controls display correctly. |
| SM-NOT-001 | Notifications | Open notification bell. | Society notifications show resident/support/announcement context and correct status/time. |
| SM-NOT-002 | Read action guard | Open notification read action and cancel/return. | App does not crash and unread count is preserved unless explicitly marked read. |

## Regression Automation Checklist

| ID | Command/Check | Expected Result |
| --- | --- | --- |
| AUTO-001 | `flutter test --no-pub test/property_management_regression_test.dart --reporter expanded` | All property regression tests pass. |
| AUTO-002 | `flutter test --no-pub --reporter expanded` | All available Flutter tests pass. |
| AUTO-003 | `flutter analyze --no-pub` | Completes without new errors. Existing warnings must be reviewed. |
| AUTO-004 | `flutter run --no-pub -d <device>` | APK installs and launches on device. |
| AUTO-005 | Logcat scan after device pass | No runtime Flutter exceptions or fatal Android crashes. |

## Final Sign-Off Criteria

- Both roles login with the same mobile and OTP.
- All major tabs and Account modules open.
- Lists show dynamic API data, not placeholders.
- Filters visibly change results or are removed when unsupported by backend.
- PDF and receipt actions open in-app preview before share.
- Profile photos use profile image fields only, not attachments.
- Time displays match website/API local-time behavior.
- Back navigation from partially filled forms never shows a red screen.
- Live destructive actions are either verified only in staging or stopped at confirmation in production.
