@IsTest
global class ExternalCompanyApiClientMock implements HttpCalloutMock {
    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');
        res.setBody(
            '{"totalSize":1,"done":true,"records":[{' +
            '"logoUrl__c":"https://logo.example.com/company.png",' +
            '"NumberOfEmployees":250,' +
            '"Foundation_date__c":"2016-01-01",' +
            '"Description":"Technology consulting company",' +
            '"BillingAddress":{' +
                '"street":"Main Street",' +
                '"city":"Dubai",' +
                '"state":"Dubai",' +
                '"postalCode":"00000",' +
                '"country":"UAE"' +
            '}' +
            '}]}'
        );
        return res;
    }
}