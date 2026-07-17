public with sharing class B2CCatalogController {
    
    public class ProductCard {
        @AuraEnabled public Id pricebookEntryId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public String serialNumber;
        @AuraEnabled public String countryOfOrigin;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal averageLifeExpectancy;
        @AuraEnabled public String generatorSize;
        @AuraEnabled public Decimal weight;
        @AuraEnabled public String phase;
        @AuraEnabled public Decimal powerGeneratedKva;
        @AuraEnabled public String engineType;
        @AuraEnabled public String productFamily;
    }

    public class SelectedItem {
        @AuraEnabled public Id pricebookEntryId;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Integer quantity;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductCard> getProducts(String searchKey, String categoryFilter, String countryFilter) {
        // 1. Fetch the Target Pricebook
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name = 'B2C Catalog' LIMIT 1];
        Id pbId = pb.Id;
        
        // 2. Base SOQL Query String
        String query = 'SELECT Id, UnitPrice, Product2.Id, Product2.Name, Product2.Serial_Number__c, Product2.Country_of_Origin__c, ' +
                       'Product2.Description, Product2.Average_Life_Expectancy__c, Product2.Generator_Size__c, Product2.Weight__c, ' +
                       'Product2.Phase__c, Product2.Power_Generated_KVA__c, Product2.Engine_Type__c, Product2.Family ' +
                       'FROM PricebookEntry ' +
                       'WHERE Pricebook2Id = :pbId ' +
                       'AND IsActive = true ' +
                       'AND Product2.IsActive = true ';

        // 3. Dynamically Append Filters (Using Bind Variables to Prevent SOQL Injection)
        String keyBind;
        if (String.isNotBlank(searchKey)) {
            keyBind = '%' + searchKey.trim() + '%';
            query += 'AND (Product2.Name LIKE :keyBind OR Product2.Description LIKE :keyBind OR Product2.Serial_Number__c LIKE :keyBind) ';
        }

        String catBind;
        if (String.isNotBlank(categoryFilter)) {
            catBind = categoryFilter.trim();
            query += 'AND Product2.Family = :catBind ';
        }

        String ctryBind;
        if (String.isNotBlank(countryFilter)) {
            ctryBind = countryFilter.trim();
            query += 'AND Product2.Country_of_Origin__c = :ctryBind ';
        }

        query += 'ORDER BY Product2.Name';

        // 4. Safely Execute the Dynamic Query
        List<PricebookEntry> allEntries = Database.query(query);

        // 5. Map Query Results to Wrappers
        List<ProductCard> result = new List<ProductCard>();
        for (PricebookEntry e : allEntries) {
            ProductCard c = new ProductCard();
            c.pricebookEntryId = e.Id;
            c.productId = e.Product2.Id;
            c.name = e.Product2.Name;
            c.unitPrice = e.UnitPrice;
            c.serialNumber = e.Product2.Serial_Number__c;
            c.countryOfOrigin = e.Product2.Country_of_Origin__c;
            c.description = e.Product2.Description;
            c.averageLifeExpectancy = e.Product2.Average_Life_Expectancy__c;
            c.generatorSize = e.Product2.Generator_Size__c;
            c.weight = e.Product2.Weight__c;
            c.phase = e.Product2.Phase__c;
            c.powerGeneratedKva = e.Product2.Power_Generated_KVA__c;
            c.engineType = e.Product2.Engine_Type__c;
            c.productFamily = e.Product2.Family;
            result.add(c);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getCategoryValues() {
        List<String> vals = new List<String>();
        for (Schema.PicklistEntry pe : Product2.Family.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                vals.add(pe.getValue());
            }
        }
        return vals;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getOriginValues() {
        List<String> vals = new List<String>();
        for (Schema.PicklistEntry pe : Product2.Country_of_Origin__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                vals.add(pe.getValue());
            }
        }
        return vals;
    }

    @AuraEnabled
    public static Id createWonOpportunity(Id accountId, String opportunityName, List<SelectedItem> items) {
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name = 'B2C Catalog' LIMIT 1];

        Opportunity opp = new Opportunity();
        opp.Name = String.isBlank(opportunityName) ? 'B2C Sale' : opportunityName;
        opp.AccountId = accountId;
        opp.StageName = 'Closed Won';
        opp.CloseDate = Date.today();
        opp.Pricebook2Id = pb.Id; // Fixes required association constraint
        insert opp;

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        for (SelectedItem item : items) {
            olis.add(new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = item.pricebookEntryId,
                Quantity = item.quantity == null ? 1 : item.quantity,
                UnitPrice = item.unitPrice
            ));
        }
        if (!olis.isEmpty()) {
            insert olis;
        }
        return opp.Id;
    }
}