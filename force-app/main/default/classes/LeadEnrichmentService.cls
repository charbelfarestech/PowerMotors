public with sharing class LeadEnrichmentService {
    @future(callout=true)
    public static void enrichLead(Id leadId) {
        Lead ld = [
            SELECT Id, Website, Company,
                   Logo_URL__c,
                   NumberOfEmployees,
                   Foundation_Date__c,
                   Biography__c,
                   Street,
                   City,
                   State,
                   PostalCode,
                   Country,
                   Enrichment_Status__c,
                   Description
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        System.debug('Lead loaded: ' + ld.Id);
        System.debug('Lead website: ' + ld.Website);

        if (String.isBlank(ld.Website)) {
            System.debug('Website is blank');
            ld.Enrichment_Status__c = 'Failed';
            update ld;
            return;
        }

        try {
            String domain = normalizeWebsite(ld.Website);
            System.debug('Normalized domain: ' + domain);

            HttpResponse res = ExternalCompanyApiClient.fetchCompanyByWebsite(domain);
            System.debug('HTTP status code: ' + res.getStatusCode());
            System.debug('HTTP status: ' + res.getStatus());
            System.debug('Response body: ' + res.getBody());

            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                System.debug('Payload '+ res.getBody());
                ExternalCompanyResponse payload = ExternalCompanyResponse.parse(res.getBody());
                System.debug('Payload parsed '+ payload);

                if (payload != null) {
                    System.debug('Payload totalSize: ' + payload.totalSize);
                }

                if (payload != null && payload.records != null && !payload.records.isEmpty()) {
                    System.debug('Found matching record, applying mapper');
                    LeadEnrichmentMapper.applyToLead(ld, payload.records[0]);
                } else {
                    System.debug('No company found in response');
                    ld.Enrichment_Status__c = 'No Match';
                }
            } else {
                System.debug('Callout unsuccessful');
                ld.Enrichment_Status__c = 'Failed';
            }

            update ld;
            System.debug('Lead update finished');
        } catch (Exception e) {
            System.debug('Exception message: ' + e.getMessage());
            System.debug('Exception type: ' + e.getTypeName());
            System.debug('Exception line: ' + e.getLineNumber());

            ld.Enrichment_Status__c = 'Failed';
            ld.Description = 'Enrichment error: ' + e.getMessage();
            update ld;
        }
    }

    private static String normalizeWebsite(String website) {
        String cleaned = website.trim().toLowerCase();
        cleaned = cleaned.replace('https://', '');
        cleaned = cleaned.replace('http://', '');

        Integer slashIndex = cleaned.indexOf('/');
        if (slashIndex > -1) {
            cleaned = cleaned.substring(0, slashIndex);
        }

        return cleaned;
    }
}