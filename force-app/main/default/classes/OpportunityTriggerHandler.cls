public with sharing class OpportunityTriggerHandler extends TriggerHandler implements ITriggerHandler {

    private Map<Id, Opportunity> newMap;
    private Map<Id, Opportunity> oldMap;
    private List<Opportunity> TriggerNew;
    private List<Opportunity> TriggerOld;

    public OpportunityTriggerHandler(){
        this.newMap = (Map<Id, Opportunity>) Trigger.newMap;
        this.oldMap = (Map<Id, Opportunity>) Trigger.oldMap;
        this.TriggerNew = (List<Opportunity>) Trigger.New;
        this.TriggerOld = (List<Opportunity>) Trigger.Old;
    }

    // flip this to true if we ever need to switch this trigger off mid-transaction
    public static Boolean TriggerDisabled = false;

    public Boolean isDisabled(){
        return TriggerDisabled;
    }

    public override void beforeInsert() {}
    public override void afterInsert() {}
    public override void beforeUpdate() {}
    public override void afterUpdate() {
        Ap01_Opportunity_EmailLogic.handleAfterUpdate(TriggerNew, oldMap);
    }
    public override void beforeDelete() {}
    public override void afterDelete() {}
    public override void afterUnDelete() {}
}
