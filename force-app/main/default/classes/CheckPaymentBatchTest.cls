@isTest
public class CheckPaymentBatchTest {
    @TestSetup
    static void setup(){
        //tworzenie kontaktu
        Contact testContact = new Contact(
            LastName = 'Test Contact',
            Email = 'testcontact@example.com'
        );
        insert testContact;

        //tworzenie szansy z IsPaid__c = false
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'New',
            IsPaid__c = false,
            CloseDate = Date.today().addDays(-40)
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

        Test.startTest();
        CheckPaymentBatch cpb = new CheckPaymentBatch();
        Database.executeBatch(cpb);

        Test.stopTest();

        //pobieranie zaktualizowanej szansy
        Opportunity updatedOpp = [SELECT Id, IsPaid__c, ReminderSentDate__c FROM Opportunity WHERE IsPaid__c = false LIMIT 1];
        //sprawdzanie czy reminderSentDate__c zostalo zaktualizowane
        System.assertNotEquals(null, updatedOpp.ReminderSentDate__c, 'Reminder sent date powinno byc zaktualizowane');

        //sprawdzanie czy email zostal wyslany
        Integer emailsSent = Limits.getEmailInvocations();
        System.assertEquals(1, emailsSent, 'jeden email zostal wyslany');

        //sprawdzanie czy zostala utworzona sprawa - case
        List<Case> cases = [SELECT Id, Status, Subject FROM Case WHERE Id = :updatedOpp.Id];
        System.assertEquals(1, cases.size(), 'jeden case zostal utworzony');
        System.assertEquals('niezaplacona faktura', cases[0].Subject, 'powinien zgadzac sie temat casa');
        SYstem.assertEquals('New', cases[0].Status, 'status case powinien byc new');

        //sprawdzanie czy pole IsPaid__c zostalo ustawione na true
        System.assertEquals(true, updatedOpp.IsPaid__c);
    }
}