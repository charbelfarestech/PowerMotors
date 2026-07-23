/** Lead business rules called by LeadTriggerHandler. */
public with sharing class AP01_Lead {

    /**
     * Clears lead enrichment fields when the Website field is wiped out.
     */
    public static void clearLeadFieldsOnWebsiteRemoval(List<Lead> newList, Map<Id, Lead> oldMap) {
        for (Lead ld : newList) {
            Lead oldLd = oldMap.get(ld.Id);

            Boolean websiteChanged = ld.Website != oldLd.Website;
            Boolean websiteNowBlank = String.isBlank(ld.Website);

            if (websiteChanged && websiteNowBlank) {
                // These values are owned by enrichment, so remove stale data with the same update.
                ld.Logo_URL__c = null;
                ld.NumberOfEmployees = null;
                ld.Foundation_Date__c = null;
                ld.Biography__c = null;
                ld.Street = null;
                ld.City = null;
                ld.State = null;
                ld.PostalCode = null;
                ld.Country = null;
                ld.Enrichment_Status__c = null;
                ld.Description = null;
            }
        }
    }

    /**
     * Triggers enrichment service for newly created leads with a website.
     */
    public static void enrichLeadsOnInsert(List<Lead> newList) {
        for (Lead ld : newList) {
            if (String.isNotBlank(ld.Website)) {
                LeadEnrichmentService.enrichLead(ld.Id);
            }
        }
    }

    /**
     * Triggers enrichment service when a website URL is populated or updated.
     */
    public static void enrichLeadsOnUpdate(List<Lead> newList, Map<Id, Lead> oldMap) {
        for (Lead ld : newList) {
            Lead oldLd = oldMap.get(ld.Id);

            Boolean websiteChanged = ld.Website != oldLd.Website;
            Boolean websiteNowHasValue = String.isNotBlank(ld.Website);

            if (websiteChanged && websiteNowHasValue) {
                LeadEnrichmentService.enrichLead(ld.Id);
            }
        }
    }
}
