/** Flow-invocable Quote PDF generation and email service. */
public without sharing class QuoteAutoEmailService {

    @InvocableMethod(label='Create Quote PDF and Email')
    public static void quoteCreateAndEmail(List<Id> quoteIds) {
        if (!quoteIds.isEmpty()) {
            createQuotePDF(quoteIds[0]);
        }
    }

    // PDF rendering is asynchronous because Salesforce treats it as a callout.
    @future(callout=true)
    public static void createQuotePDF(Id quoteId) {

        PageReference pg = new PageReference(
            '/quote/quoteTemplateDataViewer.apexp?id=' + quoteId +
            '&summlid=' + Label.Email_Template_ID
        );

        QuoteDocument quotedoc = new QuoteDocument();
        Blob b = pg.getContentAsPDF();
        quotedoc.Document = b;
        quotedoc.QuoteId = quoteId;
        insert quotedoc;

        Quote qte = [
            SELECT Id, OpportunityId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        sendEmail(qte.Id, quotedoc.Id, qte.OpportunityId);
    }

    public static void sendEmail(Id quoteId, Id quotedocId, Id opportunityId) {

        // Send to every related Opportunity contact that has an email address.
        List<OpportunityContactRole> roles = [
            SELECT ContactId, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId = :opportunityId
            AND Contact.Email != null
        ];

        if (roles.isEmpty()) {
            System.debug('No related contacts with email found for Opportunity: ' + opportunityId);
            return;
        }

        List<String> emailAddresses = new List<String>();
        Id primaryContactId = null;

        for (OpportunityContactRole role : roles) {
            emailAddresses.add(role.Contact.Email);
            if (primaryContactId == null) {
                primaryContactId = role.ContactId;
            }
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setTargetObjectId(primaryContactId);
        message.setSenderDisplayName('Company Support');
        message.setReplyTo('no-reply@company.com');
        message.setUseSignature(false);
        message.setBccSender(false);
        message.setSaveAsActivity(false);
        message.setTemplateID('00XgK00000RUsQ1'); 
        message.setWhatId(quoteId);
        message.toAddresses = emailAddresses;

        List<QuoteDocument> qds = [
            SELECT Name, Document
            FROM QuoteDocument
            WHERE QuoteId = :quoteId
        ];

        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        for (QuoteDocument qd : qds) {
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName(qd.Name != null ? qd.Name : 'Quote.pdf');
            efa.setBody(qd.Document);
            attachments.add(efa);
        }
        message.setFileAttachments(attachments);

        Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage>{ message };
        Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);

        if (results[0].success) {
            System.debug('The email was sent successfully to: ' + emailAddresses);
        } else {
            System.debug('The email failed to send: ' + results[0].errors[0].message);
        }
    }
}
