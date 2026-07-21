public with sharing class CompanyEnrichmentController {

    @AuraEnabled
    public static void enrichAndSaveAccount(Id accountId, String websiteDomain) {
        if (String.isBlank(accountId) || String.isBlank(websiteDomain)) {
            return;
        }

        // Call your existing web service
        HttpResponse res = ExternalCompanyApiClient.fetchCompanyByWebsite(websiteDomain);

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) responseMap.get('records');

            if (records != null && !records.isEmpty()) {
                Map<String, Object> remoteAcc = (Map<String, Object>) records[0];
                Account accToUpdate = new Account(Id = accountId);

                // Standard Fields
                if (remoteAcc.containsKey('NumberOfEmployees') && remoteAcc.get('NumberOfEmployees') != null) {
                    accToUpdate.NumberOfEmployees = Integer.valueOf(remoteAcc.get('NumberOfEmployees'));
                }

                if (remoteAcc.containsKey('Description') && remoteAcc.get('Description') != null) {
                    accToUpdate.Description = String.valueOf(remoteAcc.get('Description'));
                }

                // Custom Fields set via .put() to bypass static compile checks
                if (remoteAcc.containsKey('Logo_URL__c') && remoteAcc.get('Logo_URL__c') != null) {
                    accToUpdate.put('Logo_URL__c', String.valueOf(remoteAcc.get('Logo_URL__c')));
                }

                if (remoteAcc.containsKey('Foundation_Date__c') && remoteAcc.get('Foundation_Date__c') != null) {
                    String dateStr = String.valueOf(remoteAcc.get('Foundation_Date__c'));
                    accToUpdate.put('Foundation_Date__c', Date.valueOf(dateStr));
                }

                update accToUpdate;
            }
        }
    }
}