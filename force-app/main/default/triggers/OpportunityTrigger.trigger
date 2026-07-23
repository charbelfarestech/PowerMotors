// Entry point only; OpportunityTriggerHandler contains the actual event behavior.
trigger OpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    new OpportunityTriggerHandler().run();
}
