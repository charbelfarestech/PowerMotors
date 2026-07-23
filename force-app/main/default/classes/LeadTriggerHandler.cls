/** Dispatches Lead events to the appropriate enrichment use case. */
public with sharing class LeadTriggerHandler extends TriggerHandler implements ITriggerHandler {
    
    private Map<Id, Lead> newMap;
    private Map<Id, Lead> oldMap;
    private List<Lead> triggerNew;
    private List<Lead> triggerOld;
    
    public LeadTriggerHandler() {
        this.newMap = (Map<Id, Lead>) Trigger.newMap;
        this.oldMap = (Map<Id, Lead>) Trigger.oldMap;
        this.triggerNew = (List<Lead>) Trigger.new;
        this.triggerOld = (List<Lead>) Trigger.old;
    }
    
    // Disable trigger flag
    public static Boolean triggerDisabled = false;
    
    public Boolean isDisabled() {
        return triggerDisabled;
    }

    public override void beforeInsert() {}
    
    public override void afterInsert() {
        // Avoid starting a future callout from code that is already asynchronous.
        if (!System.isBatch() && !System.isFuture()) {
            AP01_Lead.enrichLeadsOnInsert(this.triggerNew);
        }
    }
    
    public override void beforeUpdate() {
        // Before-update changes are saved without a second DML operation.
        AP01_Lead.clearLeadFieldsOnWebsiteRemoval(this.triggerNew, this.oldMap);
    }
    
    public override void afterUpdate() {
        // The old map is needed to determine whether Website was actually changed.
        if (!System.isBatch() && !System.isFuture()) {
            AP01_Lead.enrichLeadsOnUpdate(this.triggerNew, this.oldMap);
        }
    }
    
    public override void beforeDelete() {}
    
    public override void afterDelete() {}
    
    public override void afterUndelete() {}
}
