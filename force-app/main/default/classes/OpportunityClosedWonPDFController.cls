/**
 * @Description: Controller for the OpportunityClosedWonPDF Visualforce page.
 *               Accepts an Opportunity Id via the page URL and exposes
 *               the record for PDF rendering.
 * @Author: Charbel Fares
 * @Company: Power Motors
 * @Last Modified: 17-07-2026
 * @Last Modified By: Charbel Fares
 */
public with sharing class OpportunityClosedWonPDFController {

    public Opportunity opp { get; private set; }

    public OpportunityClosedWonPDFController() {
        Id oppId = ApexPages.currentPage().getParameters().get('id');
        if (oppId != null) {
            opp = [
                SELECT Id, Name, StageName, CloseDate, Amount, Description,
                       Account.Name, Owner.Name, Owner.Email
                FROM   Opportunity
                WHERE  Id = :oppId
                LIMIT  1
            ];
        }
    }
}
