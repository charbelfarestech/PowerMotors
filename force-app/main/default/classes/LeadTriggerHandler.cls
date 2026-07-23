public with sharing class LeadTriggerHandler  extends TriggerHandler implements ITriggerHandler{
    
    private Map<Id, Lead> newMap;
    private Map<Id, Lead> oldMap;
    private List<Lead> TriggerNew;
    private List<Lead> TriggerOld;
    
    public LeadTriggerHandler(){
        this.newMap = (Map<Id, Lead>) Trigger.newMap;
        this.oldMap = (Map<Id, Lead>) Trigger.oldMap;
        this.TriggerNew= (List<Lead>) Trigger.New;
        this.TriggerOld= (List<Lead>) Trigger.Old;
    }
    
    
    //Use this variable to disable this trigger from transaction
    public static Boolean TriggerDisabled = false;
    
    //check if the trigger is disabled from transaction
    public Boolean isDisabled(){
        return TriggerDisabled;
    }
    
    public override void beforeInsert() {
    }
    
    public override void afterInsert() {

        /*
        Ensures that the AP01_Lead.getLeads() method is only called during synchronous context, 
        which means that it is not called when the trigger is executed in a batch or future context. 
        This is to avoid any unexpected behavior that may occur if the method is called during an asynchronous context, 
        as the logic in the method is designed to work in a synchronous manner.
        */
        
        if(System.IsBatch() == false && System.isFuture() == false){ 
            AP01_Lead.getLeads(oldMap, TriggerNew);
        }

    }
    
    public  override void beforeUpdate() {
    }
    
    public override void afterUpdate() {
        
        if(System.IsBatch() == false && System.isFuture() == false){ 
            AP01_Lead.getLeads(oldMap, TriggerNew);
        }
      
    }
    
    public override void beforeDelete() {}
    
    public override void afterDelete() {}
    
    public override void afterUnDelete() {}

}