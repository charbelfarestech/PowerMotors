/** Maps the first matching external Account response to a Salesforce Lead. */
public with sharing class LeadEnrichmentMapper {
    public static void applyToLead(Lead ld, ExternalCompanyResponse.AccountRecord src) {
        // Mapping the exact API variables
        ld.Logo_URL__c = src.logoUrl;
        system.debug(src.logoUrl);
         system.debug(src.Foundation_date);
        ld.NumberOfEmployees = src.NumberOfEmployees;
        ld.Foundation_Date__c = src.Foundation_date;
        ld.Description = src.Description;

        // Address data is optional in the response; do not dereference or overwrite it when absent.
        if (src.BillingAddress != null) {
            ld.Street = src.BillingAddress.street;
            ld.City = src.BillingAddress.city;
            ld.State = src.BillingAddress.state;
            ld.PostalCode = src.BillingAddress.postalCode;
            ld.Country = src.BillingAddress.country;
        }

        ld.Enrichment_Status__c = 'Success';
    }
}
