public with sharing class CheckPaymentBatch implements 
Database.Batchable<SObject>, Database.Stateful {
    public Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator([
            SELECT Id, IsPaid__c, ClosedDate, ReminderSentDate__c
            FROM Opportunity
            WHERE IsPaid__c = false
            SELECT Id, Contact.Email FROM OpportunityContactRole WHERE OpportunityId = Id
        ]);
    }
    public void execute(Database.BatchableContext BC, List<Opportunity> scope){
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Case> cases = new List<Case>();

        for (Opportunity opp : scope){
            if(Date.today()> opp.CloseDate.addDays(30) && opp.ReminderSentDate__c == null){
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

                mail.setToAddress(new String[]{opp.ContactEmail});
                mail.setSubject('Przypomnienie o platnosci');
                mail.setPlainTextBody('Prosze o oplacenie faktury');

                emails.add(mail);

                //aktualizowanie daty wyslania przypomnienia
                opp.ReminderSentDate__c = Date.today();
            }else if(Date.today() > opp.ReminderSentDate__c.addDays(7)){
                Case newCase = new Case();
                newCase.Subject = 'Niezaplacona faktura';
                newCase.Description = 'Faktura dla szansy ' + opp.Id + 'nie zostala oplacona.';
                newCase.Status = 'New';

                newCase.Opportunity__c = opp.Id;
                cases.add(newCase);
            }
        }
        if (!emails.isEmpty()){
            Messaging.sendEmail(emails);
        }

        update scope;
    }
    global void finish(Database.BatchableContext BC){

    }
}