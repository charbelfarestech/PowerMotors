trigger LeadTrigger on Lead (before update, after insert, after update) {

    if (Trigger.isBefore && Trigger.isUpdate) {
        for (Lead ld : Trigger.new) {
            Lead oldLd = Trigger.oldMap.get(ld.Id);

            Boolean websiteChanged = ld.Website != oldLd.Website;
            Boolean websiteNowBlank = String.isBlank(ld.Website);

            if (websiteChanged && websiteNowBlank) {
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

    if (Trigger.isAfter && Trigger.isInsert) {
        for (Lead ld : Trigger.new) {
            if (String.isNotBlank(ld.Website)) {
                LeadEnrichmentService.enrichLead(ld.Id);
            }
        }
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        for (Lead ld : Trigger.new) {
            Lead oldLd = Trigger.oldMap.get(ld.Id);

            Boolean websiteChanged = ld.Website != oldLd.Website;
            Boolean websiteNowHasValue = String.isNotBlank(ld.Website);

            if (websiteChanged && websiteNowHasValue) {
                LeadEnrichmentService.enrichLead(ld.Id);
            }
        }
    }
}