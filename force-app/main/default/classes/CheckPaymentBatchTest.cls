@isTest
private class CheckPaymentBatchTest {
    @TestSetup
    static void setup(){
        //tworzenie kontaktu
        Contact testContact = new Contact(
            LastName = 'Test Contact',
            Email = 'testcontact@example.com'
        );
        insert testContact;

        //tworzenie konta account
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        //tworzenie szansy z IsPaid__c = false
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'New',
            IsPaid__c = false,
            CloseDate = Date.today().addDays(-40),
            AccountId = testAccount.Id
        );
        insert testOpp;

        //tworzenie powiazania miedzy szansa a kontaktem
        OpportunityContactRole testOppRole = new OpportunityContactRole(
            OpportunityId = testOpp.Id,
            ContactId = testContact.Id,
            Role = 'Decision Maker'
        );
        insert testOppRole;   
    }

    @isTest
    static void test(){
        System.Test.startTest();
        CheckPaymentBatch cpb = new CheckPaymentBatch();
        Id batchId = Database.executeBatch(cpb);
        System.Test.stopTest();

        //sprawdzanie czy email zostal wyslany
        Integer emailsSent = Limits.getEmailInvocations();
        System.assertEquals(1, emailsSent, 'jeden email zostal wyslany');

    }
}