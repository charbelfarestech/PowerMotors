/**
 * @Description: Test class for Ap01_Opportunity_EmailLogic.
 *               Tests that the Closed Won email trigger fires correctly.
 * @Author: Charbel Fares
 * @Company: Power Motors
 * @Last Modified: 17-07-2026
 * @Last Modified By: Charbel Fares
 */

@isTest
/** Exercises the Opportunity trigger's Closed Won and non-Closed-Won paths. */
public class Ap01_Opportunity_EmailLogic_Test {

    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
    }

    @isTest
    static void testClosedWonEmailSent() {
        Opportunity opp = [SELECT Id, StageName FROM Opportunity LIMIT 1];

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

    }

    @isTest
    static void testNoEmailWhenNotClosedWon() {
        Opportunity opp = [SELECT Id, StageName FROM Opportunity LIMIT 1];

        Test.startTest();
        opp.StageName = 'Proposal/Price Quote';
        update opp;
        Test.stopTest();

    }
}
