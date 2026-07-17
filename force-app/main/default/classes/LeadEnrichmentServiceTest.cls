        @IsTest
private class LeadEnrichmentServiceTest {
    @IsTest
    static void testEnrichLeadSuccess() {
        Lead ld = new Lead(
            LastName = 'Test',
            Company = 'Demo Company',
            Website = 'https://eit-mena.com'
        );
        insert ld;

        Test.setMock(HttpCalloutMock.class, new ExternalCompanyApiClientMock());

        Test.startTest();
        LeadEnrichmentService.enrichLead(ld.Id);
        Test.stopTest();

        Lead updatedLead = [
            SELECT Logo_URL__c,
                   NumberOfEmployees,
                   Foundation_Date__c,
                   Address,
                   Biography__c,
                   Enrichment_Status__c
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertEquals('Success', updatedLead.Enrichment_Status__c);
        System.assertEquals(250, updatedLead.NumberOfEmployees);
        System.assertEquals('Technology consulting company', updatedLead.Biography__c);
    }

    @IsTest
    static void testEnrichLeadFailsWhenWebsiteBlank() {
        Lead ld = new Lead(
            LastName = 'Blank',
            Company = 'No Website Co'
        );
        insert ld;

        Test.startTest();
        LeadEnrichmentService.enrichLead(ld.Id);
        Test.stopTest();

        Lead updatedLead = [
            SELECT Enrichment_Status__c
            FROM Lead
            WHERE Id = :ld.Id
        ];

        System.assertEquals('Failed', updatedLead.Enrichment_Status__c);
    }
}
    