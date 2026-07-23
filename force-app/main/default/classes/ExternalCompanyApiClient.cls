public with sharing class ExternalCompanyApiClient {

    public static Map<String, Object> getAccessToken() {
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        // set header as custom label 
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setEndpoint('callout:PowerMotors_Enrichment_API/services/oauth2/token');
        req.setBody(generateAuthenticationBody());

        Http http = new Http();
        HttpResponse res = http.send(req);
// check why 300 
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            System.debug('@@@ Access Token Response: ' + responseMap);
            return responseMap;
        }
        else {
            throw new CalloutException('Failed to obtain access token. Status code: ' + res.getStatusCode());
        }
    }

    public static HttpResponse fetchCompanyByWebsite(String websiteDomain) {
         Map<String, Object> tokenResponse = getAccessToken();
        String accessToken = (String) tokenResponse.get('access_token');
        String instanceUrl = (String) tokenResponse.get('instance_url');

        String soql =
            'SELECT logoUrl__c, NumberOfEmployees, Foundation_date__c, BillingAddress, Description ' +
            'FROM Account ' +
            'WHERE Website LIKE \'%' + String.escapeSingleQuotes(websiteDomain) + '%\' ' +
            'LIMIT 1';

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setEndpoint(
            instanceUrl +
            '/services/data/v54.0/query/?q=' +
            EncodingUtil.urlEncode(soql, 'UTF-8')
        );

        Http http = new Http();
        return http.send(req);
    }

    private static String generateAuthenticationBody(){
        return 'grant_type=password' +
               '&client_id=' + '{!$Credential.Power_Motors_External_Credential.client_id}' +
               '&client_secret=' + '{!$Credential.Power_Motors_External_Credential.client_secret}' +
               '&username=' + '{!$Credential.Power_Motors_External_Credential.username}' +
               '&password=' + '{!$Credential.Power_Motors_External_Credential.password}';
    }
}
