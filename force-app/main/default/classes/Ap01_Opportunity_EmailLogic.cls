/**
 * @Description: This Apex Class handles the Opportunity Closed Won email logic.
 *               It filters opportunities that just closed won and sends each rep
 *               a PDF summary of their opportunity via email.
 * @Author: Charbel Fares
 * @Company: Power Motors
 * @Last Modified: 17-07-2026
 * @Last Modified By: Charbel Fares
 * @Test Class: Ap01_Opportunity_EmailLogic_Test
 */
/** Detects Closed Won transitions and emails the owner a rendered PDF summary. */
public class Ap01_Opportunity_EmailLogic {

    // called from the handler - filters who just closed won then fires the future method
    public static void handleAfterUpdate(List<Opportunity> newOpps, Map<Id, Opportunity> oldOppMap) {
        List<Id> justClosedWonIds = new List<Id>();

        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldOppMap.get(opp.Id);

            // only grab it if it JUST became closed won this update
            if (opp.StageName == 'Closed Won' && oldOpp.StageName != 'Closed Won') {
                justClosedWonIds.add(opp.Id);
            }
        }

        if (!justClosedWonIds.isEmpty()) {
            sendClosedWonEmail(justClosedWonIds);
        }
    }

    // we can't generate a PDF directly inside a trigger, salesforce just doesn't allow it
    // so we use @future to run this part separately after the trigger is done
    // also @future only accepts simple values like Ids, not full records, so we re-query inside here
    // Visualforce PDF rendering is asynchronous and treated as a callout by Salesforce.
    @future(callout=true)
    public static void sendClosedWonEmail(List<Id> closedOppIds) {

        // a list to collect all emails before sending them all at once
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        // query is directly in the for loop
        for (Opportunity opp : [SELECT Id, Name, OwnerId, Owner.Name FROM Opportunity WHERE Id IN :closedOppIds]) {

            // point to our pdf page and tell it which opportunity to load by passing the id
            // Pass the current record to the page controller through its URL parameter.
            PageReference pdfPage = Page.OpportunityClosedWonPDF;
            pdfPage.getParameters().put('id', opp.Id);

            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF content'); // PDF rendering doesn't work in tests
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            // build the attachment
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(opp.Name + ' - Closed Won.pdf');
            attachment.setBody(pdfBlob);

            // build the email and attach the pdf
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTargetObjectId(opp.OwnerId);
            email.setSubject('Opportunity Closed Won: ' + opp.Name);
            email.setPlainTextBody('Hi ' + opp.Owner.Name + '! Your opportunity "' + opp.Name + '" just closed won. PDF summary attached.');
            email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
            email.setSaveAsActivity(false);

            emails.add(email);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}
