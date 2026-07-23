/** Typed wrapper for the JSON returned by the remote Salesforce REST query. */
public with sharing class ExternalCompanyResponse {
    public Integer totalSize;
    public Boolean done;
    public List<AccountRecord> records;

    // This is the small helper function! 
    // It cleans the JSON and deserializes it in one go.
    public static ExternalCompanyResponse parse(String jsonString) {
        // Strip custom-field suffixes so JSON names match this wrapper's Apex properties.
        return (ExternalCompanyResponse) System.JSON.deserialize(jsonString.replaceAll('__c', ''), ExternalCompanyResponse.class);
    }

    public class AccountRecord {
        
        public String logoUrl; 
        public Integer NumberOfEmployees;
        public Date Foundation_date; 
        public String Description;
        public BillingAddressWrapper BillingAddress;
    }

    public class BillingAddressWrapper {
        public String street;
        public String city;
        public String state;
        public String postalCode;
        public String country;
    }
}
