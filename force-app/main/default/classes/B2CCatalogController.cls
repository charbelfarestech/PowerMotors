public with sharing class B2CCatalogController {

    public class ProductCard {
        @AuraEnabled public Id     pricebookEntryId;
        @AuraEnabled public Id     productId;
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
        @AuraEnabled public String recordTypeName; 
        @AuraEnabled public String imageUrl;
    }

    public class SelectedItem {
    @AuraEnabled public Id      pricebookEntryId { get; set; }
    @AuraEnabled public Decimal unitPrice        { get; set; }
    @AuraEnabled public Integer quantity         { get; set; }
}

    // ── shared pricebook lookup ────────────────────────────────────────────
    private static Id getPricebookId() {
        List<Pricebook2> pb = [SELECT Id FROM Pricebook2 WHERE Name = 'B2C Catalog' AND IsActive = true LIMIT 1];
        if (pb.isEmpty()) { throw new AuraHandledException('Pricebook "B2C Catalog" not found or inactive.'); }
        return pb[0].Id;
    }

    // ── product catalog ────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<ProductCard> getProducts(String searchKey, String categoryFilter, String countryFilter) {
        Id pbId = getPricebookId();

        String query =
            'SELECT Id, UnitPrice, ' +
            '  Product2.Id, Product2.Name, Product2.Serial_Number__c, ' +
            '  Product2.Country_of_Origin__c, Product2.Description, ' +
            '  Product2.Average_Life_Expectancy__c, Product2.Generator_Size__c, ' +
            '  Product2.Weight__c, Product2.Phase__c, ' +
            '  Product2.Power_Generated_KVA__c, Product2.Engine_Type__c, ' +
            '  Product2.Family, Product2.RecordType.DeveloperName, ' +
            '  Product2.DisplayUrl ' +
            'FROM PricebookEntry ' +
            'WHERE Pricebook2Id = :pbId ' +
            '  AND IsActive = true ' +
            '  AND Product2.IsActive = true ';

        String keyBind;
        if (String.isNotBlank(searchKey)) {
            keyBind = '%' + searchKey.trim() + '%';
            query += 'AND (Product2.Name LIKE :keyBind OR Product2.Description LIKE :keyBind OR Product2.Serial_Number__c LIKE :keyBind) ';
        }

        // filter by RecordType DeveloperName instead of Family
        String catBind;
        if (String.isNotBlank(categoryFilter)) {
            catBind = categoryFilter.trim();
            query += 'AND Product2.RecordType.DeveloperName = :catBind ';
        }

        String ctryBind;
        if (String.isNotBlank(countryFilter)) {
            ctryBind = countryFilter.trim();
            query += 'AND Product2.Country_of_Origin__c = :ctryBind ';
        }

        query += 'ORDER BY Product2.Name';

        List<PricebookEntry> entries = Database.query(query);
        List<ProductCard> result = new List<ProductCard>();

        for (PricebookEntry e : entries) {
            ProductCard c          = new ProductCard();
            c.pricebookEntryId     = e.Id;
            c.productId            = e.Product2.Id;
            c.name                 = e.Product2.Name;
            c.unitPrice            = e.UnitPrice;
            c.serialNumber         = e.Product2.Serial_Number__c;
            c.countryOfOrigin      = e.Product2.Country_of_Origin__c;
            c.description          = e.Product2.Description;
            c.averageLifeExpectancy= e.Product2.Average_Life_Expectancy__c;
            c.generatorSize        = e.Product2.Generator_Size__c;
            c.weight               = e.Product2.Weight__c;
            c.phase                = e.Product2.Phase__c;
            c.powerGeneratedKva    = e.Product2.Power_Generated_KVA__c;
            c.engineType           = e.Product2.Engine_Type__c;
            c.productFamily        = e.Product2.Family;
            // Build full URL: if DisplayUrl is relative (starts with /), prepend org domain
            if (String.isNotBlank(e.Product2.DisplayUrl)) {
                String rawUrl = e.Product2.DisplayUrl;
                if (rawUrl.startsWith('/')) {
                    c.imageUrl = URL.getOrgDomainUrl().toExternalForm() + rawUrl;
                } else {
                    c.imageUrl = rawUrl;
                }
            }
            c.recordTypeName       = e.Product2.RecordType != null
                                     ? e.Product2.RecordType.DeveloperName
                                     : null;
            result.add(c);
        }
        return result;
    }

    // ── picklists for filter dropdowns ─────────────────────────────────────

    // Returns the DeveloperNames of active Product2 record types that exist
    // in the B2C Catalog pricebook — drives the category filter pills in LWC.
    @AuraEnabled(cacheable=true)
    public static List<String> getCategoryValues() {
        List<String> result = new List<String>();
        for (RecordType rt : [
            SELECT DeveloperName
            FROM   RecordType
            WHERE  SObjectType = 'Product2'
              AND  IsActive = true
            ORDER BY DeveloperName
        ]) {
            result.add(rt.DeveloperName);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getOriginValues() {
        List<String> vals = new List<String>();
        for (Schema.PicklistEntry pe : Product2.Country_of_Origin__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) { vals.add(pe.getValue()); }
        }
        return vals;
    }

    // ── create won opportunity ─────────────────────────────────────────────
    @AuraEnabled
    public static Id createWonOpportunity(Id accountId, String opportunityName, List<SelectedItem> items) {
        Id pbId = getPricebookId();

        Opportunity opp   = new Opportunity();
        opp.Name          = String.isBlank(opportunityName) ? 'B2C Sale' : opportunityName;
        opp.AccountId     = accountId;
        opp.StageName     = 'Closed Won';
        opp.CloseDate     = Date.today();
        opp.Pricebook2Id  = pbId;
        insert opp;

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        for (SelectedItem item : items) {
            Decimal qty = item.quantity == null ? 1 : item.quantity;
            System.debug ('Creating OpportunityLineItem1: ' + item);
            System.debug ('Creating OpportunityLineItem: ' + item.pricebookEntryId + ', qty=' + qty + ', unitPrice=' + item.unitPrice);
            olis.add(new OpportunityLineItem(
                OpportunityId    = opp.Id,
                PricebookEntryId = item.pricebookEntryId,
                Quantity         = qty,
                UnitPrice        = item.unitPrice
               
            ));

        }
        if (!olis.isEmpty()) { insert olis; }
        return opp.Id;
    }
}