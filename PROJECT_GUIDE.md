# Power Motors: Project Guide

## Purpose

This Salesforce DX project adds three business features to Power Motors:

1. **Lead enrichment:** populate a Lead with company information found through an external Salesforce REST API.
2. **B2C sales:** show catalog products in a Lightning Web Component and create a Closed Won Opportunity with selected line items.
3. **PDF emails:** email an Opportunity owner a PDF when a deal becomes Closed Won; a separate Flow action creates and emails Quote PDFs.

## Repository structure

| Location | Purpose |
| --- | --- |
| `force-app/main/default/classes` | Apex controllers, services, trigger framework, wrappers, and tests. |
| `force-app/main/default/triggers` | Thin Lead and Opportunity trigger entry points. |
| `force-app/main/default/lwc` | Lightning Web Components. |
| `force-app/main/default/pages` | Visualforce PDF template. |
| `force-app/main/default/staticresources` | Generator and part image resources. |
| `config/project-scratch-def.json` | Developer scratch-org definition. |
| `manifest/package.xml` | Retrieve/deploy manifest. |
| `scripts` | Example anonymous Apex and SOQL scripts. |

`sfdx-project.json` declares `force-app` as the default package directory and API version 67.0. `package.json` defines lint, Jest, and Prettier commands.

## Architecture

```text
Lead trigger -> LeadTriggerHandler -> AP01_Lead -> LeadEnrichmentService (@future)
                                                       |
                                                       v
                              ExternalCompanyApiClient -> external Salesforce REST API
                                                       |
                                                       v
                        ExternalCompanyResponse + LeadEnrichmentMapper -> Lead update

Account page -> b2cCatalog LWC -> B2CCatalogController -> Opportunity + line items

Opportunity trigger -> OpportunityTriggerHandler -> Email logic (@future)
                                                        |
                                                        v
                         Visualforce PDF controller/page -> owner email with PDF attachment
```

The triggers use `TriggerHandler`, which identifies the Salesforce trigger context and calls the matching object-specific handler hook. It also supports handler bypasses and loop limits.

## Lead enrichment

`LeadTrigger` delegates to `LeadTriggerHandler`.

- **Before update:** if an existing Lead's Website changes to blank, `AP01_Lead.clearLeadFieldsOnWebsiteRemoval` clears the fields treated as enrichment data. This is before-update, so the clearing is saved in the same DML operation.
- **After insert:** a Lead with a Website schedules `LeadEnrichmentService.enrichLead`.
- **After update:** a changed Website with a value schedules the same service.
- Scheduling is skipped in batch/future contexts to avoid starting a future method from async code.

`LeadEnrichmentService` is `@future(callout=true)`. It re-queries the Lead, normalizes the Website to a domain, calls the external service, and writes one of these statuses:

| Outcome | Status |
| --- | --- |
| Matching company returned and mapped | `Success` |
| Successful response with no company | `No Match` |
| Blank Website, bad response, or exception | `Failed` |

`ExternalCompanyApiClient` obtains an OAuth token through the `PowerMotors_Enrichment_API` named credential and external credential placeholders, then sends a REST SOQL query to the external org. No secret should be stored in source control.

`ExternalCompanyResponse` converts the JSON into Apex wrapper classes. Its parser removes `__c` from response keys so they match the wrapper fields. `LeadEnrichmentMapper` copies company logo, employee count, foundation date, description, billing address, and status onto the Lead.

### Invisible enrichment component

`invisibleEnrichment` has an empty template by design. When it is added to a **Lead record page**, it reads `Lead.Website`, extracts the domain, calls `CompanyEnrichmentController` immediately and every 30 seconds, then requests a Lightning Data Service refresh.

There is a configuration mismatch to fix: the LWC is restricted to Lead pages and passes a Lead Id, but `CompanyEnrichmentController.enrichAndSaveAccount` constructs an `Account` with that Id and updates Account fields. The trigger-driven Lead enrichment flow is internally consistent; do not rely on the invisible worker until its target object is made consistent.

## B2C catalog and sale creation

`b2cCatalog` is available on record and home pages. On an Account record page, its `recordId` is used as the Account Id for the sale.

1. The LWC loads Product2 record types and active country picklist values for filters.
2. Changing a category or country reactively calls `B2CCatalogController.getProducts`.
3. Apex finds the active pricebook named **B2C Catalog** and returns active Pricebook Entries and Product2 fields as `ProductCard` DTOs.
4. The UI shows five products per page and remembers selected PricebookEntry Ids across pages.
5. The Details action opens a modal. A record type name containing `generator` gets generator-specific fields; all other records are treated as parts.
6. Save sends selected IDs, prices, and quantities to `createWonOpportunity`.
7. Apex inserts a Closed Won Opportunity dated today, assigns the B2C pricebook, and bulk-inserts its `OpportunityLineItem` records.

The named pricebook must exist and be active. Every displayed product must be active and have an active entry in it. Category options currently contain all active Product2 record types, including types with no B2C entries.

## Closed Won Opportunity PDF email

On Opportunity after-update, `OpportunityTriggerHandler` calls `Ap01_Opportunity_EmailLogic`. It compares old and new stage values; only a transition to `Closed Won` qualifies.

The email step is a future callout because Visualforce PDF rendering cannot run inside a trigger transaction. It re-queries the Opportunity, renders `OpportunityClosedWonPDF.page?id=<OpportunityId>`, attaches the PDF, and emails the owner. Tests use a dummy Blob because PDF rendering is unavailable in Apex tests.

`OpportunityClosedWonPDFController` reads the `id` page parameter and queries the Opportunity, Account, and Owner. The Visualforce page contains an Opportunity summary, a single description/amount row, totals, and a signature section. It does **not** render actual OpportunityLineItems; it uses `Opportunity.Description` and `Opportunity.Amount` for its row.

## Quote PDF email action

`QuoteAutoEmailService.quoteCreateAndEmail` is intended for Flow. It processes the first Quote Id supplied, renders Salesforce's standard quote template URL with `Label.Email_Template_ID`, stores a `QuoteDocument`, then emails all Opportunity Contact Roles with email addresses.

Review this class before using it in another org: it runs `without sharing`, processes only the first ID, and contains a hard-coded email template Id, sender name, and reply-to address.

## Tests and known gaps

- `LeadEnrichmentServiceTest` uses `ExternalCompanyApiClientMock` for a deterministic response. Its success assertion expects `Biography__c`, but the mapper writes response description to `Description`; align the intended field before relying on this test.
- `Ap01_Opportunity_EmailLogic_Test` exercises stage changes but has no email assertions.
- Both LWC Jest files are generated placeholders and do not test behavior yet.
- `LeadEnrichmentService.cls.bak` is a backup artifact, not active Salesforce metadata.

## Local checks

After installing Node dependencies, run:

```powershell
npm run lint
npm run test:unit
npm run prettier:verify
sf apex run test --test-level RunLocalTests
```

## Salesforce setup required

- Lead custom fields used by enrichment: `Logo_URL__c`, `Foundation_Date__c`, `Biography__c`, and `Enrichment_Status__c`.
- Product2 custom fields referenced by the catalog.
- An active `B2C Catalog` pricebook with active products and pricebook entries.
- `PowerMotors_Enrichment_API` named credential and `Power_Motors_External_Credential` credential values.
- Email deliverability and permissions for PDF rendering and outbound email.
- A Flow that invokes `Create Quote PDF and Email`, if Quote automation is required.
- `b2cCatalog` placed on an Account record page; `invisibleEnrichment` only after its Lead/Account mismatch is corrected.

## Working-tree note

This repository already contains uncommitted Lead-trigger refactoring (`LeadTriggerHandler`, `LeadTrigger`, and the new `AP01_Lead` class). This guide documents that handler-based design and does not revert or alter its behavior.
